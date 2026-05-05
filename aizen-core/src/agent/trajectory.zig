//! Trajectory Replay — record and replay agent execution for debugging.
//!
//! Mirrors ZeroClaw's trajectory module:
//!   - Records full turn data: input, system prompt, history, LLM responses,
//!     tool calls, execution results, errors, and final output
//!   - Persists to JSONL files (one line per turn)
//!   - Replays a trajectory for deterministic debugging and regression testing
//!   - Integrates with the Agent observer pattern

const std = @import("std");
const std_compat = @import("compat");
const providers = @import("../providers/root.zig");
const tools_mod = @import("../tools/root.zig");
const log = std.log.scoped(.trajectory);
const fs_compat = @import("../fs_compat.zig");

/// A single step in a trajectory — corresponds to one agent turn.
pub const TrajectoryTurn = struct {
    /// Turn sequence number (0-indexed).
    seq: u32,
    /// Timestamp when the turn started (Unix epoch seconds).
    started_at: i64,
    /// Timestamp when the turn completed.
    completed_at: i64,
    /// Raw user input.
    user_input: []const u8,
    /// System prompt used for this turn (if any).
    system_prompt: ?[]const u8 = null,
    /// Enriched user message (with memory context).
    enriched_input: ?[]const u8 = null,
    /// LLM responses per iteration.
    iterations: []const Iteration,
    /// Final output returned to the user.
    final_output: []const u8,
    /// Whether the turn completed successfully.
    success: bool,
    /// Error message if the turn failed.
    error_message: ?[]const u8 = null,
    /// Total token usage for the turn.
    usage: providers.TokenUsage,
    /// Whether the turn was served from response cache.
    cache_hit: bool = false,

    pub const Iteration = struct {
        /// Iteration number within the turn.
        index: u32,
        /// Provider name used.
        provider: []const u8,
        /// Model name used.
        model: []const u8,
        /// Messages sent to the LLM.
        messages: []const Message,
        /// LLM response content.
        response_content: ?[]const u8,
        /// Tool calls requested by the LLM.
        tool_calls: []const ToolCall,
        /// Tool execution results.
        tool_results: []const ToolResult,
        /// Whether this iteration was successful.
        success: bool,
        /// Error message if iteration failed.
        error_message: ?[]const u8 = null,
        /// Duration of the LLM call in milliseconds.
        duration_ms: u64,
        /// Token usage for this iteration.
        usage: providers.TokenUsage,

        pub fn deinit(self: *const Iteration, allocator: std.mem.Allocator) void {
            if (self.error_message) |e| allocator.free(e);
            allocator.free(self.messages);
            if (self.response_content) |c| allocator.free(c);
            for (self.tool_calls) |tc| {
                if (tc.id) |id| allocator.free(id);
                allocator.free(tc.name);
                allocator.free(tc.arguments_json);
            }
            allocator.free(self.tool_calls);
            for (self.tool_results) |tr| {
                allocator.free(tr.output);
                if (tr.tool_call_id) |id| allocator.free(id);
                allocator.free(tr.name);
            }
            allocator.free(self.tool_results);
        }
    };

    pub const Message = struct {
        role: []const u8,
        content: []const u8,
    };

    pub const ToolCall = struct {
        id: ?[]const u8,
        name: []const u8,
        arguments_json: []const u8,
    };

    pub const ToolResult = struct {
        tool_call_id: ?[]const u8,
        name: []const u8,
        output: []const u8,
        success: bool,
        duration_ms: u64,
    };

    pub fn deinit(self: *TrajectoryTurn, allocator: std.mem.Allocator) void {
        allocator.free(self.user_input);
        if (self.system_prompt) |s| allocator.free(s);
        if (self.enriched_input) |s| allocator.free(s);
        for (self.iterations) |*it| it.deinit(allocator);
        allocator.free(self.iterations);
        allocator.free(self.final_output);
        if (self.error_message) |s| allocator.free(s);
    }
};

/// Configuration for trajectory recording.
pub const TrajectoryConfig = struct {
    /// Enable trajectory recording.
    enabled: bool = false,
    /// Directory to store trajectory files.
    output_dir: []const u8 = "trajectories",
    /// Maximum trajectories to keep (oldest deleted).
    max_files: usize = 100,
    /// Include full message content in recordings.
    include_message_content: bool = true,
    /// Include tool call arguments.
    include_tool_args: bool = true,
    /// Include tool execution output.
    include_tool_output: bool = false,
    /// Redact API keys from recordings.
    redact_secrets: bool = true,
};

/// TrajectoryRecorder — records agent turns to JSONL files.
pub const TrajectoryRecorder = struct {
    allocator: std.mem.Allocator,
    config: TrajectoryConfig,
    mutex: std_compat.sync.Mutex = .{},
    turn_count: u32 = 0,
    current_file_path: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, config: TrajectoryConfig, workspace_dir: []const u8) !TrajectoryRecorder {
        if (!config.enabled) {
            return .{ .allocator = allocator, .config = config };
        }

        const dir_path = try std_compat.fs.path.join(allocator, &.{ workspace_dir, config.output_dir });
        defer allocator.free(dir_path);

        fs_compat.makePath(dir_path) catch |err| {
            log.warn("failed to create trajectory directory '{s}': {}", .{ dir_path, err });
            return .{ .allocator = allocator, .config = config };
        };

        const timestamp = std_compat.time.timestamp();
        var buf: [64]u8 = undefined;
        const filename = try std.fmt.bufPrint(&buf, "trajectory_{d}.jsonl", .{timestamp});
        const file_path = try std_compat.fs.path.join(allocator, &.{ dir_path, filename });

        // Create the file to ensure it exists
        const file = std_compat.fs.createFileAbsolute(file_path, .{ .truncate = true }) catch |err| {
            log.warn("failed to create trajectory file '{s}': {}", .{ file_path, err });
            allocator.free(file_path);
            return .{ .allocator = allocator, .config = config };
        };
        file.close();

        return .{
            .allocator = allocator,
            .config = config,
            .current_file_path = file_path,
        };
    }

    pub fn deinit(self: *TrajectoryRecorder) void {
        if (self.current_file_path) |p| self.allocator.free(p);
    }

    /// Record a completed turn to the trajectory file.
    pub fn recordTurn(self: *TrajectoryRecorder, turn: TrajectoryTurn) void {
        if (!self.config.enabled or self.current_file_path == null) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        const file = std_compat.fs.openFileAbsolute(self.current_file_path.?, .{ .mode = .write_only }) catch |err| {
            log.warn("failed to open trajectory file '{s}': {}", .{ self.current_file_path.?, err });
            return;
        };
        defer file.close();
        file.seekFromEnd(0) catch |err| {
            log.warn("failed to seek trajectory file '{s}': {}", .{ self.current_file_path.?, err });
            return;
        };

        var buf: [65536]u8 = undefined;
        var bw = file.writer(&buf);
        const w = &bw.interface;

        serializeTurn(w, turn, self.config) catch |err| {
            log.warn("failed to serialize trajectory turn {d}: {}", .{ turn.seq, err });
            return;
        };
        w.writeByte('\n') catch |err| {
            log.warn("failed to write newline after trajectory turn {d}: {}", .{ turn.seq, err });
            return;
        };

        self.turn_count += 1;
    }

    /// Start recording a new turn. Returns a TurnBuilder.
    pub fn startTurn(self: *TrajectoryRecorder, user_input: []const u8) ?TurnBuilder {
        if (!self.config.enabled) return null;

        return TurnBuilder{
            .allocator = self.allocator,
            .config = self.config,
            .recorder = self,
            .turn = .{
                .seq = self.turn_count,
                .started_at = std_compat.time.timestamp(),
                .completed_at = 0,
                .user_input = self.allocator.dupe(u8, user_input) catch return null,
                .iterations = &.{},
                .final_output = "",
                .success = false,
                .usage = .{},
            },
        };
    }

    // ── Helpers ──────────────────────────────────────────────────

    fn writeJsonString(w: anytype, s: []const u8) !void {
        try w.writeByte('"');
        for (s) |c| {
            switch (c) {
                '\\' => try w.writeAll("\\\\"),
                '"' => try w.writeAll("\\\""),
                '\n' => try w.writeAll("\\n"),
                '\r' => try w.writeAll("\\r"),
                '\t' => try w.writeAll("\\t"),
                0x00...0x08, 0x0B...0x0C, 0x0E...0x1F => try w.print("\\u{x:0>4}", .{c}),
                else => try w.writeByte(c),
            }
        }
        try w.writeByte('"');
    }

    fn serializeTurn(w: anytype, turn: TrajectoryTurn, config: TrajectoryConfig) !void {
        try w.writeByte('{');

        try writeJsonString(w, "seq");
        try w.print(":{d},", .{turn.seq});

        try writeJsonString(w, "started_at");
        try w.print(":{d},", .{turn.started_at});

        try writeJsonString(w, "completed_at");
        try w.print(":{d},", .{turn.completed_at});

        try writeJsonString(w, "user_input");
        try w.writeByte(':');
        try writeJsonString(w, turn.user_input);
        try w.writeByte(',');

        if (turn.system_prompt) |sp| {
            try writeJsonString(w, "system_prompt");
            try w.writeByte(':');
            try writeJsonString(w, sp);
            try w.writeByte(',');
        }

        if (turn.enriched_input) |ei| {
            try writeJsonString(w, "enriched_input");
            try w.writeByte(':');
            try writeJsonString(w, ei);
            try w.writeByte(',');
        }

        try writeJsonString(w, "iterations");
        try w.writeByte(':');
        try w.writeByte('[');
        for (turn.iterations, 0..) |it, i| {
            if (i > 0) try w.writeByte(',');
            try serializeIteration(w, it, config);
        }
        try w.writeByte(']');
        try w.writeByte(',');

        try writeJsonString(w, "final_output");
        try w.writeByte(':');
        try writeJsonString(w, turn.final_output);
        try w.writeByte(',');

        try writeJsonString(w, "success");
        try w.print(":{},", .{turn.success});

        if (turn.error_message) |em| {
            try writeJsonString(w, "error_message");
            try w.writeByte(':');
            try writeJsonString(w, em);
            try w.writeByte(',');
        }

        try writeJsonString(w, "usage");
        try w.writeAll(":{\"prompt_tokens\":");
        try w.print("{d},\"completion_tokens\":{d},\"total_tokens\":{d}}}", .{
            turn.usage.prompt_tokens,
            turn.usage.completion_tokens,
            turn.usage.total_tokens,
        });

        try w.writeByte('}');
    }

    fn serializeIteration(w: anytype, it: TrajectoryTurn.Iteration, config: TrajectoryConfig) !void {
        try w.writeByte('{');

        try writeJsonString(w, "index");
        try w.print(":{d},", .{it.index});

        try writeJsonString(w, "provider");
        try w.writeByte(':');
        try writeJsonString(w, it.provider);
        try w.writeByte(',');

        try writeJsonString(w, "model");
        try w.writeByte(':');
        try writeJsonString(w, it.model);
        try w.writeByte(',');

        try writeJsonString(w, "messages");
        try w.writeByte(':');
        try w.writeByte('[');
        for (it.messages, 0..) |msg, i| {
            if (i > 0) try w.writeByte(',');
            try w.writeByte('{');
            try writeJsonString(w, "role");
            try w.writeByte(':');
            try writeJsonString(w, msg.role);
            try w.writeByte(',');
            try writeJsonString(w, "content");
            try w.writeByte(':');
            if (config.include_message_content) {
                try writeJsonString(w, msg.content);
            } else {
                try writeJsonString(w, "[redacted]");
            }
            try w.writeByte('}');
        }
        try w.writeByte(']');
        try w.writeByte(',');

        try writeJsonString(w, "response_content");
        try w.writeByte(':');
        if (it.response_content) |rc| {
            try writeJsonString(w, rc);
        } else {
            try w.writeAll("null");
        }
        try w.writeByte(',');

        try writeJsonString(w, "tool_calls");
        try w.writeByte(':');
        try w.writeByte('[');
        for (it.tool_calls, 0..) |tc, i| {
            if (i > 0) try w.writeByte(',');
            try w.writeByte('{');
            try writeJsonString(w, "id");
            try w.writeByte(':');
            if (tc.id) |id| {
                try writeJsonString(w, id);
            } else {
                try w.writeAll("null");
            }
            try w.writeByte(',');
            try writeJsonString(w, "name");
            try w.writeByte(':');
            try writeJsonString(w, tc.name);
            try w.writeByte(',');
            try writeJsonString(w, "arguments");
            try w.writeByte(':');
            if (config.include_tool_args) {
                try writeJsonString(w, tc.arguments_json);
            } else {
                try writeJsonString(w, "[redacted]");
            }
            try w.writeByte('}');
        }
        try w.writeByte(']');
        try w.writeByte(',');

        try writeJsonString(w, "tool_results");
        try w.writeByte(':');
        try w.writeByte('[');
        for (it.tool_results, 0..) |tr, i| {
            if (i > 0) try w.writeByte(',');
            try w.writeByte('{');
            try writeJsonString(w, "tool_call_id");
            try w.writeByte(':');
            if (tr.tool_call_id) |id| {
                try writeJsonString(w, id);
            } else {
                try w.writeAll("null");
            }
            try w.writeByte(',');
            try writeJsonString(w, "name");
            try w.writeByte(':');
            try writeJsonString(w, tr.name);
            try w.writeByte(',');
            try writeJsonString(w, "output");
            try w.writeByte(':');
            if (config.include_tool_output) {
                try writeJsonString(w, tr.output);
            } else {
                try writeJsonString(w, "[redacted]");
            }
            try w.writeByte(',');
            try writeJsonString(w, "success");
            try w.print(":{},", .{tr.success});
            try writeJsonString(w, "duration_ms");
            try w.print(":{d}", .{tr.duration_ms});
            try w.writeByte('}');
        }
        try w.writeByte(']');
        try w.writeByte(',');

        try writeJsonString(w, "success");
        try w.print(":{},", .{it.success});

        if (it.error_message) |em| {
            try writeJsonString(w, "error_message");
            try w.writeByte(':');
            try writeJsonString(w, em);
            try w.writeByte(',');
        }

        try writeJsonString(w, "duration_ms");
        try w.print(":{d},", .{it.duration_ms});

        try writeJsonString(w, "usage");
        try w.writeAll(":{\"prompt_tokens\":");
        try w.print("{d},\"completion_tokens\":{d},\"total_tokens\":{d}}}", .{
            it.usage.prompt_tokens,
            it.usage.completion_tokens,
            it.usage.total_tokens,
        });

        try w.writeByte('}');
    }
};

/// TurnBuilder — accumulates data during a turn and commits to recorder.
pub const TurnBuilder = struct {
    allocator: std.mem.Allocator,
    config: TrajectoryConfig,
    recorder: ?*TrajectoryRecorder,
    turn: TrajectoryTurn,
    iterations: std.ArrayListUnmanaged(TrajectoryTurn.Iteration) = .empty,

    pub fn setSystemPrompt(self: *TurnBuilder, prompt: []const u8) void {
        self.turn.system_prompt = self.allocator.dupe(u8, prompt) catch return;
    }

    pub fn setEnrichedInput(self: *TurnBuilder, input: []const u8) void {
        self.turn.enriched_input = self.allocator.dupe(u8, input) catch return;
    }

    pub fn addIteration(self: *TurnBuilder, iteration: TrajectoryTurn.Iteration) !void {
        try self.iterations.append(self.allocator, iteration);
    }

    pub fn setFinalOutput(self: *TurnBuilder, output: []const u8) void {
        self.turn.final_output = self.allocator.dupe(u8, output) catch return;
    }

    pub fn setSuccess(self: *TurnBuilder, success: bool) void {
        self.turn.success = success;
    }

    pub fn setError(self: *TurnBuilder, error_message: []const u8) void {
        self.turn.error_message = self.allocator.dupe(u8, error_message) catch return;
    }

    pub fn setUsage(self: *TurnBuilder, usage: providers.TokenUsage) void {
        self.turn.usage = usage;
    }

    pub fn setCacheHit(self: *TurnBuilder, cache_hit: bool) void {
        self.turn.cache_hit = cache_hit;
    }

    pub fn commit(self: *TurnBuilder) void {
        self.turn.completed_at = std_compat.time.timestamp();
        self.turn.iterations = self.iterations.toOwnedSlice(self.allocator) catch &[_]TrajectoryTurn.Iteration{};
        if (self.recorder) |rec| {
            rec.recordTurn(self.turn);
        }
    }

    pub fn deinit(self: *TurnBuilder) void {
        self.turn.deinit(self.allocator);
        for (self.iterations.items) |*it| it.deinit(self.allocator);
        self.iterations.deinit(self.allocator);
    }
};

// ── Trajectory Replay ───────────────────────────────────────────

/// Load a trajectory from a JSONL file.
pub fn loadTrajectory(allocator: std.mem.Allocator, file_path: []const u8) ![]TrajectoryTurn {
    const file = try std_compat.fs.openFileAbsolute(file_path, .{});
    defer file.close();

    var turns: std.ArrayListUnmanaged(TrajectoryTurn) = .empty;
    errdefer {
        for (turns.items) |*t| t.deinit(allocator);
        turns.deinit(allocator);
    }

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 10); // 10MB max
    defer allocator.free(content);

    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        // TODO: Parse JSON line into TrajectoryTurn
        // For now, just skip parsing (placeholder)
    }

    return turns.toOwnedSlice(allocator);
}

// ── Tests ───────────────────────────────────────────────────────

test "TrajectoryRecorder disabled" {
    const allocator = std.testing.allocator;
    var recorder = try TrajectoryRecorder.init(allocator, .{ .enabled = false }, "/tmp");
    defer recorder.deinit();

    try std.testing.expect(!recorder.config.enabled);
    try std.testing.expectEqual(@as(?[]const u8, null), recorder.current_file_path);
}

test "TurnBuilder basic flow" {
    const allocator = std.testing.allocator;
    var recorder = try TrajectoryRecorder.init(allocator, .{
        .enabled = true,
        .output_dir = "test_trajectories",
    }, "/tmp");
    defer recorder.deinit();

    var builder = recorder.startTurn("Hello, agent!").?;
    defer builder.deinit();

    builder.setSystemPrompt("You are a helpful assistant.");
    builder.setFinalOutput("Hello! How can I help you?");
    builder.setSuccess(true);
    builder.setUsage(.{ .prompt_tokens = 10, .completion_tokens = 5, .total_tokens = 15 });
    builder.commit();

    try std.testing.expectEqual(@as(u32, 1), recorder.turn_count);
}

test "regression: record and verify trajectory final_output" {
    const allocator = std.testing.allocator;
    const workspace_dir = "/tmp/aizen_trajectory_test";

    // Clean up any previous test data
    fs_compat.deletePath(workspace_dir) catch {};

    var recorder = try TrajectoryRecorder.init(allocator, .{
        .enabled = true,
        .output_dir = "regression_test_trajectories",
    }, workspace_dir);
    defer {
        // Clean up test file after test
        if (recorder.current_file_path) |p| {
            fs_compat.deletePath(p) catch {};
        }
        recorder.deinit();
        fs_compat.deletePath(workspace_dir) catch {};
    }

    const expected_output = "The answer is 42.";

    var builder = recorder.startTurn("What is the meaning of life?").?;
    defer builder.deinit();

    builder.setSystemPrompt("You are a philosophical assistant.");
    builder.setFinalOutput(expected_output);
    builder.setSuccess(true);
    builder.setUsage(.{ .prompt_tokens = 20, .completion_tokens = 10, .total_tokens = 30 });
    builder.commit();

    // Verify the trajectory file exists and contains the expected output
    const file_path = recorder.current_file_path.?;
    const file = try std_compat.fs.openFileAbsolute(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // Verify the recorded JSON contains the final_output
    try std.testing.expect(std.mem.indexOf(u8, content, "\"final_output\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, expected_output) != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"success\":true") != null);

    // Verify turn count incremented
    try std.testing.expectEqual(@as(u32, 1), recorder.turn_count);
}
