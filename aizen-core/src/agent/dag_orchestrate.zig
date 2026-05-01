// DAG Task Orchestration — Directed Acyclic Graph schema and executor
// Enables multi-step workflows with parallel/sequential steps, conditionals, and fan-out/fan-in
//
// Schema: JSON/YAML workflow definitions with steps, dependencies, and execution modes
// Executor: Topological sort + async parallel execution with result aggregation
const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.dag);

// ── Step Types ────────────────────────────────────────────────────────────────

pub const StepStatus = enum { pending, running, done, failed, skipped };
pub const StepMode = enum { sequential, parallel, fan_out, fan_in };

pub const StepCondition = struct {
    field: []const u8,       // e.g., "status", "output.length", "error"
    op: []const u8,          // e.g., "==", "!=", ">", "<", "contains", "exists"
    value: []const u8,       // Expected value
};

pub const Step = struct {
    id: []const u8,          // Unique step identifier
    name: []const u8,        // Human-readable name
    description: []const u8 = "",
    tool: []const u8,         // Tool name to invoke
    args: []const u8 = "",    // JSON arguments for the tool
    mode: StepMode = .sequential,
    depends_on: [][]const u8 = &.{}, // Step IDs this step depends on
    condition: ?StepCondition = null,
    timeout_ms: u32 = 60000, // Default 60s timeout
    retry_count: u8 = 0,     // Number of retries on failure
    env: []struct { k: []const u8, v: []const u8 } = &.{}, // Local env vars for this step

    pub fn deinit(self: *Step, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        if (self.description.len > 0) allocator.free(self.description);
        allocator.free(self.tool);
        if (self.args.len > 0) allocator.free(self.args);
        for (self.depends_on) |dep| allocator.free(dep);
        if (self.condition) |*c| {
            allocator.free(c.field);
            allocator.free(c.op);
            allocator.free(c.value);
        }
    }
};

pub const StepResult = struct {
    step_id: []const u8,
    status: StepStatus,
    output: []const u8 = "",
    error: ?[]const u8 = null,
    started_at_ms: i64 = 0,
    completed_at_ms: i64 = 0,
    retry_count: u8 = 0,

    pub fn durationMs(self: StepResult) i64 {
        return self.completed_at_ms - self.started_at_ms;
    }

    pub fn deinit(self: *StepResult, allocator: Allocator) void {
        allocator.free(self.step_id);
        if (self.output.len > 0) allocator.free(self.output);
        if (self.error) |e| allocator.free(e);
    }
};

// ── DAG Workflow ────────────────────────────────────────────────────────────────

pub const Workflow = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8 = "",
    steps: []Step,
    global_env: []struct { k: []const u8, v: []const u8 } = &.{},

    pub fn deinit(self: *Workflow, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        if (self.description.len > 0) allocator.free(self.description);
        for (self.steps) |*s| s.deinit(allocator);
        allocator.free(self.steps);
    }
};

// ── Execution Engine ──────────────────────────────────────────────────────────

pub const ExecutionState = struct {
    workflow_name: []const u8,
    step_results: std.HashMapUnmanaged([]const u8, StepResult, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),
    started_at_ms: i64 = 0,
    completed_at_ms: i64 = 0,
    total_steps: usize = 0,
    completed_steps: usize = 0,
    failed_steps: usize = 0,

    pub fn deinit(self: *ExecutionState, allocator: Allocator) void {
        var iter = self.step_results.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key);
            entry.value_ptr.deinit(allocator);
        }
        self.step_results.deinit(allocator);
    }
};

pub const dag_executor = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) @This() {
        return .{ .allocator = allocator };
    }

    pub fn execute(self: *@This(), workflow: *Workflow) !ExecutionState {
        var state = ExecutionState{
            .workflow_name = workflow.name,
            .step_results = .empty,
            .started_at_ms = std.time.milliTimestamp(),
            .total_steps = workflow.steps.len,
        };
        errdefer state.deinit(self.allocator);

        // Topological sort to determine execution order
        const execution_order = try self.topologicalSort(workflow);
        defer self.allocator.free(execution_order);

        // Group by mode for parallel execution
        const groups = try self.groupByMode(execution_order, workflow);
        defer {
            for (groups) |g| self.allocator.free(g);
            self.allocator.free(groups);
        }

        for (groups) |group| {
            // Execute group
            for (group) |step_id| {
                const step = self.findStep(workflow, step_id) orelse continue;

                // Check condition
                if (step.condition) |cond| {
                    if (!self.evaluateCondition(&state, cond)) {
                        try state.skipStep(step_id, self.allocator);
                        continue;
                    }
                }

                // Execute step (placeholder — real impl calls tool via agent)
                const result = try self.executeStep(step_id, step, &state);
                try state.step_results.put(self.allocator, try self.allocator.dupe(u8, step_id), result);
            }

            // Check for failures that should stop execution
            if (state.failed_steps > 0) {
                log.warn("Workflow '{s}' stopping due to {d} failed steps", .{
                    workflow.name, state.failed_steps,
                });
                break;
            }
        }

        state.completed_at_ms = std.time.milliTimestamp();
        return state;
    }

    fn topologicalSort(self: *@This(), workflow: *Workflow) ![][]const u8 {
        // Kahn's algorithm for topological sort
        var in_degree = std.AutoHashMap([]const u8, usize).init(self.allocator);
        defer in_degree.deinit();

        var step_ids = std.ArrayList([]const u8).init(self.allocator);
        for (workflow.steps) |step| {
            try step_ids.append(try self.allocator.dupe(u8, step.id));
            try in_degree.put(try self.allocator.dupe(u8, step.id), step.depends_on.len);
        }

        // Reduce in-degree for each dependency
        for (workflow.steps) |step| {
            for (step.depends_on) |dep| {
                if (in_degree.getPtr(dep)) |cnt| {
                    if (cnt.* > 0) cnt.* -= 1;
                }
            }
        }

        // Start with nodes with no dependencies
        var queue = std.ArrayList([]const u8).init(self.allocator);
        var sorted = std.ArrayList([]const u8).init(self.allocator);

        var iter = in_degree.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* == 0) {
                try queue.append(entry.key_ptr.*);
            }
        }

        while (queue.items.len > 0) {
            const node = queue.pop();
            try sorted.append(node);

            // Find steps that depend on this node
            for (workflow.steps) |step| {
                for (step.depends_on) |dep| {
                    if (std.mem.eql(u8, dep, node)) {
                        if (in_degree.getPtr(step.id)) |cnt| {
                            if (cnt.* > 0) {
                                cnt.* -= 1;
                                if (cnt.* == 0) {
                                    try queue.append(step.id);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Check for cycles
        if (sorted.items.len != workflow.steps.len) {
            return error.CyclicDependency;
        }

        return sorted.toOwnedSlice();
    }

    fn groupByMode(self: *@This(), sorted_ids: [][]const u8, workflow: *Workflow) ![][]const u8 {
        // Group consecutive steps with same mode for parallel execution
        var groups = std.ArrayList(std.ArrayList([]const u8)).init(self.allocator);

        var current_group = std.ArrayList([]const u8).init(self.allocator);

        for (sorted_ids) |step_id| {
            const step = self.findStep(workflow, step_id) orelse continue;

            if (step.mode == .parallel) {
                try current_group.append(step_id);
            } else {
                // Sequential, fan_out, fan_in — these break parallel groups
                if (current_group.items.len > 0) {
                    try groups.append(current_group);
                    current_group = std.ArrayList([]const u8).init(self.allocator);
                }
                try current_group.append(step_id);
            }
        }

        if (current_group.items.len > 0) {
            try groups.append(current_group);
        }

        var result = std.ArrayList([]const u8).init(self.allocator);
        for (groups.items) |g| {
            try result.append(g.items);
        }
        groups.deinit();
        return result.toOwnedSlice();
    }

    fn findStep(self: *@This(), workflow: *Workflow, id: []const u8) ?*Step {
        for (workflow.steps) |*step| {
            if (std.mem.eql(u8, step.id, id)) return step;
        }
        return null;
    }

    fn evaluateCondition(self: *@This(), state: *ExecutionState, cond: *const StepCondition) bool {
        _ = self;
        // Placeholder: evaluate condition against step_results
        // Real impl would check result[cond.field] against cond.value using cond.op
        _ = cond;
        _ = state;
        return true;
    }

    fn executeStep(self: *@This(), step_id: []const u8, step: *const Step, state: *ExecutionState) !StepResult {
        _ = self;
        _ = step;
        return StepResult{
            .step_id = step_id,
            .status = .done,
            .output = "",
            .started_at_ms = std.time.milliTimestamp(),
            .completed_at_ms = std.time.milliTimestamp(),
        };
    }
};

// ── ExecutionState helpers ─────────────────────────────────────────────────

fn skipStep(state: *ExecutionState, allocator: Allocator) !void {
    try state.step_results.put(allocator, "skipped", StepResult{
        .step_id = try allocator.dupe(u8, "skipped"),
        .status = .skipped,
    });
}

pub const WorkflowExecutor = dag_executor;

// ── Tests ──────────────────────────────────────────────────────────────────

test "topological sort single step" {
    const allocator = std.testing.allocator;
    var executor = WorkflowExecutor.init(allocator);
    defer executor.deinit();

    const workflow = Workflow{
        .name = "single",
        .version = "1.0",
        .steps = &.{
            .{ .id = "step1", .name = "Test Step", .tool = "shell", .args = "{}" },
        },
    };

    const sorted = try executor.topologicalSort(&workflow);
    defer allocator.free(sorted);

    try std.testing.expect(sorted.len == 1);
    try std.testing.expectEqualStrings("step1", sorted[0]);
}

test "topological sort with dependencies" {
    const allocator = std.testing.allocator;
    var executor = WorkflowExecutor.init(allocator);
    defer executor.deinit();

    const workflow = Workflow{
        .name = "chain",
        .version = "1.0",
        .steps = &.{
            .{ .id = "step1", .name = "First", .tool = "shell", .depends_on = &.{} },
            .{ .id = "step2", .name = "Second", .tool = "shell", .depends_on = &.{"step1"} },
            .{ .id = "step3", .name = "Third", .tool = "shell", .depends_on = &.{"step2"} },
        },
    };

    const sorted = try executor.topologicalSort(&workflow);
    defer allocator.free(sorted);

    try std.testing.expect(sorted.len == 3);
    // step1 must come before step2
    try std.testing.expect(std.mem.indexOfScalar([]const u8, sorted, "step1") < std.mem.indexOfScalar([]const u8, sorted, "step2"));
    try std.testing.expect(std.mem.indexOfScalar([]const u8, sorted, "step2") < std.mem.indexOfScalar([]const u8, sorted, "step3"));
}

test "topological sort detects cycle" {
    const allocator = std.testing.allocator;
    var executor = WorkflowExecutor.init(allocator);
    defer executor.deinit();

    const workflow = Workflow{
        .name = "cycle",
        .version = "1.0",
        .steps = &.{
            .{ .id = "step1", .name = "A", .tool = "shell", .depends_on = &.{"step2"} },
            .{ .id = "step2", .name = "B", .tool = "shell", .depends_on = &.{"step1"} },
        },
    };

    const sorted = try executor.topologicalSort(&workflow);
    defer allocator.free(sorted);

    try std.testing.expectError(error.CyclicDependency, Error);
}

test "step mode grouping" {
    const allocator = std.testing.allocator;
    var executor = WorkflowExecutor.init(allocator);
    defer executor.deinit();

    const workflow = Workflow{
        .name = "modes",
        .version = "1.0",
        .steps = &.{
            .{ .id = "seq1", .name = "Seq 1", .tool = "shell", .mode = .sequential },
            .{ .id = "par1", .name = "Par 1", .tool = "shell", .mode = .parallel },
            .{ .id = "par2", .name = "Par 2", .tool = "shell", .mode = .parallel },
            .{ .id = "seq2", .name = "Seq 2", .tool = "shell", .mode = .sequential },
        },
    };

    const sorted = try executor.topologicalSort(&workflow);
    defer allocator.free(sorted);
    const groups = try executor.groupByMode(sorted, &workflow);
    defer {
        for (groups) |g| allocator.free(g);
        allocator.free(groups);
    }

    try std.testing.expect(groups.len == 3); // [seq1], [par1,par2], [seq2]
    try std.testing.expect(groups[1].len == 2); // Parallel steps grouped
}

test "StepResult duration calculation" {
    const result = StepResult{
        .step_id = "test",
        .status = .done,
        .started_at_ms = 1000,
        .completed_at_ms = 2500,
    };

    try std.testing.expect(result.durationMs() == 1500);
}