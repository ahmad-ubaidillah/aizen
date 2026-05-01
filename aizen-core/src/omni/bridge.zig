//! OMNI Bridge — MCP client integration for semantic signal distillation.
//!
//! Connects to the OMNI binary (~/.local/bin/omni) via subprocess calls
//! to filter tool output before injecting into conversation context.
//! Achieves 80-90% token reduction with zero information loss via RewindStore.
//!
//! Phase 1: Subprocess bridge (this file)
//! Phase 2: MCP stdio JSON-RPC (future)
//! Phase 3: Native Zig port (future)

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const OmniBridge = struct {
    allocator: Allocator,
    omni_path: []const u8,
    enabled: bool,

    pub const Error = error{
        OmniNotFound,
        OmniFailed,
        DistillationFailed,
        RetrievalFailed,
        CompressionFailed,
        InvalidInput,
        OutOfMemory,
    };

    pub const DistillResult = struct {
        output: []const u8,
        original_len: usize,
        distilled_len: usize,
        reduction_pct: f64,

        pub fn reduction(self: @This()) f64 {
            if (self.original_len == 0) return 0.0;
            return @as(f64, @floatFromInt(self.original_len - self.distilled_len)) /
                @as(f64, @floatFromInt(self.original_len)) * 100.0;
        }
    };

    pub const RetrieveResult = struct {
        output: []const u8,
        found: bool,
    };

    pub const CompressEntry = struct {
        role: []const u8,
        content: []const u8,
        token_count: usize,
    };

    /// Initialize OMNI bridge. Checks if omni binary exists.
    pub fn init(allocator: Allocator, omni_path: []const u8) Error!@This() {
        // Check if OMNI binary exists
        const file = std.fs.cwd().openFile(omni_path, .{}) catch {
            return Error.OmniNotFound;
        };
        file.close();

        return @This(){
            .allocator = allocator,
            .omni_path = omni_path,
            .enabled = true,
        };
    }

    /// Initialize with default path (~/.local/bin/omni)
    pub fn initDefault(allocator: Allocator) Error!@This() {
        const default_path = "/home/ahmad/.local/bin/omni";
        return init(allocator, default_path) catch {
            // Try PATH lookup
            return @This(){
                .allocator = allocator,
                .omni_path = "omni",
                .enabled = true,
            };
        };
    }

    /// Create a disabled bridge (no-op for all operations)
    pub fn disabled(allocator: Allocator) @This() {
        return @This(){
            .allocator = allocator,
            .omni_path = "",
            .enabled = false,
        };
    }

    /// Distill tool output through OMNI pipeline.
    /// Filters noise, collapses repetitive lines, archives dropped content to RewindStore.
    pub fn distill(
        self: @This(),
        command: []const u8,
        input: []const u8,
    ) Error!DistillResult {
        if (!self.enabled) {
            return DistillResult{
                .output = input,
                .original_len = input.len,
                .distilled_len = input.len,
                .reduction_pct = 0.0,
            };
        }

        // Execute: omni distill --command <cmd> --input <input>
        const result = self.execOmni(&.{
            "distill",
            "--command",
            command,
            "--input",
            input,
        }) catch |err| {
            // If OMNI fails, return original input (graceful degradation)
            std.log.warn("OMNI distillation failed: {} — passing through original output", .{err});
            return DistillResult{
                .output = input,
                .original_len = input.len,
                .distilled_len = input.len,
                .reduction_pct = 0.0,
            };
        };

        const original_len = input.len;
        const distilled_len = result.len;

        return DistillResult{
            .output = result,
            .original_len = original_len,
            .distilled_len = distilled_len,
            .reduction_pct = if (original_len == 0) 0.0 else
                @as(f64, @floatFromInt(original_len - distilled_len)) /
                @as(f64, @floatFromInt(original_len)) * 100.0,
        };
    }

    /// Retrieve archived content from OMNI's RewindStore.
    /// Zero information loss — dropped lines can be retrieved later.
    pub fn retrieve(
        self: @This(),
        query: []const u8,
        limit: usize,
    ) Error!RetrieveResult {
        if (!self.enabled) {
            return RetrieveResult{ .output = "", .found = false };
        }

        const limit_str = std.fmt.allocPrint(self.allocator, "{d}", .{limit}) catch "10";
        defer self.allocator.free(limit_str);

        const result = self.execOmni(&.{
            "retrieve",
            "--query",
            query,
            "--limit",
            limit_str,
        }) catch |err| {
            std.log.warn("OMNI retrieval failed: {}", .{err});
            return RetrieveResult{ .output = "", .found = false };
        };

        return RetrieveResult{
            .output = result,
            .found = result.len > 0,
        };
    }

    /// Compress conversation history through OMNI.
    /// Preserves critical content while reducing token count.
    pub fn compress(
        self: @This(),
        entries: []const CompressEntry,
    ) Error![]const u8 {
        if (!self.enabled) {
            // Return concatenated entries as-is
            var total_len: usize = 0;
            for (entries) |e| total_len += e.content.len;
            const buf = self.allocator.alloc(u8, total_len) catch return Error.OutOfMemory;
            var offset: usize = 0;
            for (entries) |e| {
                @memcpy(buf[offset .. offset + e.content.len], e.content);
                offset += e.content.len;
            }
            return buf;
        }

        // Build JSON input for compression
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();
        const writer = json_buf.writer();

        writer.writeAll("[") catch return Error.CompressionFailed;
        for (entries, 0..) |e, i| {
            if (i > 0) writer.writeAll(",") catch {};
            writer.print(
                \\{{"role":"{s}","content":"{s}","token_count":{d}}}
            , .{ e.role, e.content, e.token_count }) catch return Error.CompressionFailed;
        }
        writer.writeAll("]") catch return Error.CompressionFailed;

        const result = self.execOmni(&.{
            "compress",
            "--input",
            json_buf.items,
        }) catch |err| {
            std.log.warn("OMNI compression failed: {} — using original", .{err});
            // Fallback: concatenate entries
            var total_len: usize = 0;
            for (entries) |e| total_len += e.content.len;
            const buf = self.allocator.alloc(u8, total_len) catch return Error.OutOfMemory;
            var offset: usize = 0;
            for (entries) |e| {
                @memcpy(buf[offset .. offset + e.content.len], e.content);
                offset += e.content.len;
            }
            return buf;
        };

        return result;
    }

    /// Execute OMNI binary with given arguments, capture stdout.
    fn execOmni(self: @This(), args: []const []const u8) Error![]const u8 {
        var argv = std.ArrayList([]const u8).init(self.allocator);
        defer argv.deinit();

        argv.append(self.omni_path) catch return Error.OutOfMemory;
        for (args) |arg| {
            argv.append(arg) catch return Error.OutOfMemory;
        }

        var child = std.process.Child.init(argv.items, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| {
            std.log.err("Failed to spawn OMNI: {}", .{err});
            return Error.OmniFailed;
        };

        // Read stdout
        const max_output = 1024 * 1024; // 1MB max
        const stdout = child.stdout.?.readToEndAlloc(self.allocator, max_output) catch "";
        defer if (child.stdout) |out| {
            _ = out;
        };

        // Wait for exit
        const exit_code = child.wait() catch return Error.OmniFailed;

        if (exit_code != .Exited or exit_code.Exited != 0) {
            self.allocator.free(stdout);
            return Error.OmniFailed;
        }

        return stdout;
    }
};

// === Tests ===

test "OmniBridge disabled returns original input" {
    const allocator = std.testing.allocator;
    const bridge = OmniBridge.disabled(allocator);

    const input = "Building project...\nCompiling module A\nCompiling module B\nCompiling module C\nDone!";
    const result = try bridge.distill("cargo build", input);
    try std.testing.expectEqualStrings(input, result.output);
    try std.testing.expect(result.reduction_pct == 0.0);
}

test "OmniBridge retrieve when disabled returns empty" {
    const allocator = std.testing.allocator;
    const bridge = OmniBridge.disabled(allocator);

    const result = try bridge.retrieve("error message", 10);
    try std.testing.expect(!result.found);
}

test "DistillResult reduction calculation" {
    const result = OmniBridge.DistillResult{
        .output = "short",
        .original_len = 100,
        .distilled_len = 20,
        .reduction_pct = 80.0,
    };
    try std.testing.expect(result.reduction() == 80.0);
}

test "OmniBridge init with non-existent binary returns error" {
    const allocator = std.testing.allocator;
    const result = OmniBridge.init(allocator, "/nonexistent/omni");
    try std.testing.expectError(Error.OmniNotFound, result);
}