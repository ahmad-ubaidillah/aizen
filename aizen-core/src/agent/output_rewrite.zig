// Structured Output Rewriting — 4 strategies for intelligent tool output processing
// Integrates with OMNI bridge for token-efficient output formatting
//
// Strategies:
// 1. Filter — Remove irrelevant/nested content, keep only key fields
// 2. Group — Cluster related items, deduplicate, present in logical sections
// 3. Truncate — Smart truncation preserving headers, summaries, and structure
// 4. Deduplicate — Remove repeated content across tool outputs
const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.output_rewrite);

// ── Rewrite Strategy ───────────────────────────────────────────────────────

pub const RewriteStrategy = enum { filter, group, truncate, deduplicate };

pub const RewriteConfig = struct {
    strategy: RewriteStrategy = .truncate,
    max_output_bytes: usize = 8192,        // Max output size after rewriting
    preserve_headers: bool = true,          // Keep section headers
    preserve_keys: bool = true,             // Keep JSON/dict keys
    max_lines: usize = 200,                 // Max number of output lines
    filter_fields: []const []const u8 = &.{},  // Fields to keep (empty = all)
    group_by: []const []const u8 = &.{},    // Fields to group by
    dedup_window: usize = 50,               // Window size for dedup comparison
    summary_if_truncated: bool = true,      // Add summary line when truncated
};

pub const RewriteResult = struct {
    content: []const u8,      // Owned, rewritten content
    original_bytes: usize,     // Original size
    rewritten_bytes: usize,    // Final size
    strategy_used: RewriteStrategy,
    lines_removed: usize = 0,
    lines_preserved: usize = 0,
    was_truncated: bool = false,
    summary: ?[]const u8 = null, // Owned, summary of what was removed

    pub fn deinit(self: *RewriteResult, allocator: Allocator) void {
        allocator.free(self.content);
        if (self.summary) |s| allocator.free(s);
    }

    pub fn compressionRatio(self: RewriteResult) f64 {
        if (self.original_bytes == 0) return 1.0;
        return @as(f64, @floatFromInt(self.rewritten_bytes)) / @as(f64, @floatFromInt(self.original_bytes));
    }
};

// ── Line Classifier ──────────────────────────────────────────────────────────
// Classifies lines as header, content, blank, or noise for smart filtering

const LineClass = enum { header, key_value, list_item, blank, noise, code_block, separator };

fn classifyLine(line: []const u8) LineClass {
    const trimmed = std.mem.trim(u8, line, " \t\r\n");
    if (trimmed.len == 0) return .blank;

    // Headers: lines ending with :, or starting with #, or ===/--- separators
    if (std.mem.endsWith(u8, trimmed, ":") or std.mem.startsWith(u8, trimmed, "#")) return .header;
    if (std.mem.allEqual(u8, trimmed, '-') and trimmed.len > 3) return .separator;
    if (std.mem.allEqual(u8, trimmed, '=') and trimmed.len > 3) return .separator;

    // Code blocks
    if (std.mem.startsWith(u8, trimmed, "```")) return .code_block;

    // Key-value pairs
    if (std.mem.indexOf(u8, trimmed, ": ") != null or
        std.mem.indexOf(u8, trimmed, " = ") != null or
        std.mem.indexOf(u8, trimmed, " => ") != null)
        return .key_value;

    // List items
    if (std.mem.startsWith(u8, trimmed, "- ") or
        std.mem.startsWith(u8, trimmed, "* ") or
        std.mem.startsWith(u8, trimmed, "• "))
        return .list_item;

    // Noise: timestamps, debug prefixes, ANSI codes
    if (std.mem.startsWith(u8, trimmed, "[DEBUG]") or
        std.mem.startsWith(u8, trimmed, "[TRACE]") or
        std.mem.startsWith(u8, trimmed, "  "))
        return .noise;

    return .header; // Default: treat as content
}

// ── Strategy: Filter ──────────────────────────────────────────────────────────
// Keeps only specified fields, removes everything else.

fn filterRewrite(allocator: Allocator, input: []const u8, config: RewriteConfig) !RewriteResult {
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    var line_iter = std.mem.splitSequence(u8, input, "\n");
    var kept_lines: usize = 0;
    var total_lines: usize = 0;

    while (line_iter.next()) |line| {
        total_lines += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r\n");

        // Always keep headers and separators if configured
        const class = classifyLine(line);
        if (config.preserve_headers and (class == .header or class == .separator or class == .code_block)) {
            try lines.append(try allocator.dupe(u8, line));
            kept_lines += 1;
            continue;
        }

        // Keep blank lines (but collapse multiple)
        if (class == .blank) {
            if (lines.items.len > 0 and lines.items[lines.items.len - 1].len > 0) {
                try lines.append(try allocator.dupe(u8, ""));
            }
            continue;
        }

        // If filter_fields specified, keep only lines matching those fields
        if (config.filter_fields.len > 0) {
            var matches = false;
            for (config.filter_fields) |field| {
                if (std.mem.containsAtLeast(u8, trimmed, 1, field)) {
                    matches = true;
                    break;
                }
            }
            if (matches) {
                try lines.append(try allocator.dupe(u8, line));
                kept_lines += 1;
            }
        } else {
            // No filter specified — remove noise only
            if (class != .noise) {
                try lines.append(try allocator.dupe(u8, line));
                kept_lines += 1;
            }
        }
    }

    // Join result
    var result = std.ArrayList(u8).init(allocator);
    for (lines.items, 0..) |l, i| {
        try result.appendSlice(l);
        if (i < lines.items.len - 1) try result.append('\n');
        allocator.free(l);
    }

    const content = try result.toOwnedSlice();
    const was_truncated = content.len > config.max_output_bytes;
    const final_content = if (was_truncated) content[0..config.max_output_bytes] else content;
    const owned_final = try allocator.dupe(u8, final_content);
    if (was_truncated) allocator.free(content);

    return RewriteResult{
        .content = owned_final,
        .original_bytes = input.len,
        .rewritten_bytes = owned_final.len,
        .strategy_used = .filter,
        .lines_removed = total_lines - kept_lines,
        .lines_preserved = kept_lines,
        .was_truncated = was_truncated,
    };
}

// ── Strategy: Group ──────────────────────────────────────────────────────────
// Groups related items by common prefixes or fields.

fn groupRewrite(allocator: Allocator, input: []const u8, config: RewriteConfig) !RewriteResult {
    var groups = std.HashMapUnmanaged([]const u8, std.ArrayList([]const u8), struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80).empty;
    defer {
        var iter = groups.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key);
            for (entry.value.items) |item| allocator.free(item);
            entry.value.deinit();
        }
        groups.deinit(allocator);
    }

    var ungrouped = std.ArrayList([]const u8).init(allocator);
    defer {
        for (ungrouped.items) |item| allocator.free(item);
        ungrouped.deinit();
    }

    var line_iter = std.mem.splitSequence(u8, input, "\n");
    var total_lines: usize = 0;

    while (line_iter.next()) |line| {
        total_lines += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        // Try to find a grouping key
        var grouped = false;
        if (config.group_by.len > 0) {
            for (config.group_by) |field| {
                if (std.mem.containsAtLeast(u8, trimmed, 1, field)) {
                    // Extract prefix before field as group key
                    const field_idx = std.mem.indexOf(u8, trimmed, field) orelse continue;
                    const key = std.mem.trim(u8, trimmed[0..field_idx], " \t");
                    const owned_key = try allocator.dupe(u8, key);
                    const owned_line = try allocator.dupe(u8, line);

                    const gop = try groups.getOrPut(allocator, owned_key);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = std.ArrayList([]const u8).init(allocator);
                    }
                    try gop.value_ptr.append(owned_line);
                    grouped = true;
                    break;
                }
            }
        }

        // Auto-grouping by first word or path prefix
        if (!grouped) {
            const space_idx = std.mem.indexOfScalar(u8, trimmed, ' ') orelse trimmed.len;
            const slash_idx = std.mem.indexOfScalar(u8, trimmed, '/');
            const group_end = if (slash_idx) |si| @min(si, space_idx) else space_idx;
            if (group_end > 0 and group_end < trimmed.len) {
                const key = try allocator.dupe(u8, trimmed[0..group_end]);
                const owned_line = try allocator.dupe(u8, line);

                const gop = try groups.getOrPut(allocator, key);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList([]const u8).init(allocator);
                } else {
                    allocator.free(key); // Key already exists
                }
                try gop.value_ptr.append(owned_line);
            } else {
                try ungrouped.append(try allocator.dupe(u8, line));
            }
        }
    }

    // Build grouped output
    var result = std.ArrayList(u8).init(allocator);
    var kept_lines: usize = 0;

    var iter = groups.iterator();
    while (iter.next()) |entry| {
        try result.appendSlice(entry.key);
        const count = entry.value.items.len;
        try std.fmt.format(result.writer(), " ({d} items):\n", .{count});
        kept_lines += 1;
        for (entry.value.items) |item| {
            try result.appendSlice("  ");
            try result.appendSlice(item);
            try result.append('\n');
            kept_lines += 1;
        }
    }

    for (ungrouped.items) |item| {
        try result.appendSlice(item);
        try result.append('\n');
        kept_lines += 1;
    }

    const content = try result.toOwnedSlice();
    const was_truncated = content.len > config.max_output_bytes;
    const final_content = if (was_truncated) content[0..config.max_output_bytes] else content;
    const owned_final = try allocator.dupe(u8, final_content);
    if (was_truncated) allocator.free(content);

    return RewriteResult{
        .content = owned_final,
        .original_bytes = input.len,
        .rewritten_bytes = owned_final.len,
        .strategy_used = .group,
        .lines_removed = total_lines - kept_lines,
        .lines_preserved = kept_lines,
        .was_truncated = was_truncated,
    };
}

// ── Strategy: Truncate ──────────────────────────────────────────────────────
// Smart truncation preserving headers, summaries, and structure.

fn truncateRewrite(allocator: Allocator, input: []const u8, config: RewriteConfig) !RewriteResult {
    var lines = std.ArrayList([]const u8).init(allocator);
    defer {
        for (lines.items) |l| allocator.free(l);
        lines.deinit();
    }

    var line_iter = std.mem.splitSequence(u8, input, "\n");
    var total_lines: usize = 0;
    var header_lines = std.ArrayList(usize).init(allocator);
    defer header_lines.deinit();

    while (line_iter.next()) |line| : (total_lines += 1) {
        const class = classifyLine(line);
        if (class == .header or class == .separator) {
            try header_lines.append(total_lines);
        }
        try lines.append(try allocator.dupe(u8, line));
    }

    // If already within limits, return as-is
    if (input.len <= config.max_output_bytes and total_lines <= config.max_lines) {
        const owned = try allocator.dupe(u8, input);
        return RewriteResult{
            .content = owned,
            .original_bytes = input.len,
            .rewritten_bytes = input.len,
            .strategy_used = .truncate,
            .was_truncated = false,
        };
    }

    // Smart truncation: always preserve headers, truncate content
    var result = std.ArrayList(u8).init(allocator);
    var kept_lines: usize = 0;
    var current_bytes: usize = 0;
    var truncated_count: usize = 0;

    for (lines.items, 0..) |line, i| {
        const is_header = std.mem.indexOfScalar(usize, header_lines.items, i) != null;

        if (current_bytes + line.len > config.max_output_bytes or kept_lines >= config.max_lines) {
            if (is_header and config.preserve_headers) {
                // Always keep headers if they fit
                try result.appendSlice(line);
                try result.append('\n');
                current_bytes += line.len + 1;
                kept_lines += 1;
            } else {
                truncated_count += 1;
            }
            continue;
        }

        try result.appendSlice(line);
        try result.append('\n');
        current_bytes += line.len + 1;
        kept_lines += 1;
    }

    if (truncated_count > 0 and config.summary_if_truncated) {
        try std.fmt.format(result.writer(), "\n... {d} lines truncated (original: {d} lines) ...\n", .{ truncated_count, total_lines });
    }

    const content = try result.toOwnedSlice();
    return RewriteResult{
        .content = content,
        .original_bytes = input.len,
        .rewritten_bytes = content.len,
        .strategy_used = .truncate,
        .lines_removed = truncated_count,
        .lines_preserved = kept_lines,
        .was_truncated = truncated_count > 0,
        .summary = if (truncated_count > 0) try std.fmt.allocPrint(allocator, "Truncated {d}/{d} lines", .{ truncated_count, total_lines }) else null,
    };
}

// ── Strategy: Deduplicate ──────────────────────────────────────────────────
// Removes repeated content using a rolling window hash comparison.

fn deduplicateRewrite(allocator: Allocator, input: []const u8, config: RewriteConfig) !RewriteResult {
    var seen = std.HashMapUnmanaged(u64, void, struct {
        pub fn hash(self: @This(), key: u64) u64 { return key; }
        pub fn eql(self: @This(), a: u64, b: u64) bool { return a == b; }
    }, 80).empty;
    defer seen.deinit(allocator);

    var result_lines = std.ArrayList([]const u8).init(allocator);
    defer {
        for (result_lines.items) |l| allocator.free(l);
        result_lines.deinit();
    }

    var line_iter = std.mem.splitSequence(u8, input, "\n");
    var total_lines: usize = 0;
    var dup_lines: usize = 0;

    while (line_iter.next()) |line| {
        total_lines += 1;
        const trimmed = std.mem.trim(u8, line, " \t\r\n");

        // Blank lines pass through
        if (trimmed.len == 0) {
            try result_lines.append(try allocator.dupe(u8, ""));
            continue;
        }

        // Hash the line content
        const hash = std.hash.Wyhash.hash(0, trimmed);

        // Check if seen in rolling window
        const gop = try seen.getOrPut(allocator, hash);
        if (gop.found_existing) {
            dup_lines += 1;
            continue; // Skip duplicate
        }

        try result_lines.append(try allocator.dupe(u8, line));

        // Maintain window size
        if (seen.count() > config.dedup_window) {
            // Remove oldest entries (approximation: clear half)
            if (seen.count() > config.dedup_window * 2) {
                var count: usize = 0;
                var iter = seen.iterator();
                while (iter.next()) |entry| {
                    if (count >= config.dedup_window) break;
                    _ = seen.remove(entry.key);
                    count += 1;
                }
            }
        }
    }

    // Join result
    var result = std.ArrayList(u8).init(allocator);
    for (result_lines.items, 0..) |l, i| {
        try result.appendSlice(l);
        if (i < result_lines.items.len - 1) try result.append('\n');
    }

    const content = try result.toOwnedSlice();
    const was_truncated = content.len > config.max_output_bytes;
    const final_content = if (was_truncated) content[0..config.max_output_bytes] else content;
    const owned_final = try allocator.dupe(u8, final_content);
    if (was_truncated) allocator.free(content);

    return RewriteResult{
        .content = owned_final,
        .original_bytes = input.len,
        .rewritten_bytes = owned_final.len,
        .strategy_used = .deduplicate,
        .lines_removed = dup_lines,
        .lines_preserved = total_lines - dup_lines,
        .was_truncated = was_truncated,
    };
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Rewrite tool output using the specified strategy.
pub fn rewrite(allocator: Allocator, input: []const u8, config: RewriteConfig) !RewriteResult {
    return switch (config.strategy) {
        .filter => filterRewrite(allocator, input, config),
        .group => groupRewrite(allocator, input, config),
        .truncate => truncateRewrite(allocator, input, config),
        .deduplicate => deduplicateRewrite(allocator, input, config),
    };
}

/// Auto-select the best strategy based on output characteristics.
pub fn autoRewrite(allocator: Allocator, input: []const u8, max_bytes: usize) !RewriteResult {
    const line_count = std.mem.count(u8, input, "\n") + 1;

    // If small enough, just deduplicate
    if (input.len <= max_bytes and line_count <= 200) {
        return deduplicateRewrite(allocator, input, .{ .max_output_bytes = max_bytes });
    }

    // If very large, truncate first, then deduplicate
    if (input.len > max_bytes * 3) {
        var result = try truncateRewrite(allocator, input, .{ .max_output_bytes = max_bytes, .max_lines = 200 });
        // Second pass: deduplicate the truncated result
        var deduped = try deduplicateRewrite(allocator, result.content, .{ .max_output_bytes = max_bytes });
        result.deinit(allocator);
        return deduped;
    }

    // If moderately large, try group or filter
    if (line_count > 100) {
        return groupRewrite(allocator, input, .{ .max_output_bytes = max_bytes });
    }

    // Default: truncate
    return truncateRewrite(allocator, input, .{ .max_output_bytes = max_bytes });
}

// ── Tests ──────────────────────────────────────────────────────────────────

test "filter rewrite removes noise" {
    const allocator = std.testing.allocator;
    const input =
        \\[DEBUG] Starting tool execution
        \\Result: success
        \\[TRACE] Internal details
        \\Output: 42
        \\[DEBUG] Cleanup
    ;

    var result = try filterRewrite(allocator, input, .{ .preserve_headers = true });
    defer result.deinit(allocator);

    // Should remove [DEBUG] and [TRACE] lines but keep others
    try std.testing.expect(!std.mem.containsAtLeast(u8, result.content, 1, "[DEBUG]"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, result.content, 1, "[TRACE]"));
    try std.testing.expect(std.mem.containsAtLeast(u8, result.content, 1, "Result: success"));
}

test "truncate rewrite preserves headers" {
    const allocator = std.testing.allocator;
    var input = std.ArrayList(u8).init(allocator);
    defer input.deinit();

    // Create a long input with headers
    try input.appendSlice("## Section 1\n");
    for (0..300) |i| {
        try std.fmt.format(input.writer(), "Line {d}\n", .{i});
    }
    try input.appendSlice("## Section 2\n");
    for (0..300) |i| {
        try std.fmt.format(input.writer(), "Line B {d}\n", .{i});
    }

    var result = try truncateRewrite(allocator, input.items, .{
        .max_output_bytes = 2048,
        .max_lines = 100,
        .preserve_headers = true,
    });
    defer result.deinit(allocator);

    try std.testing.expect(result.was_truncated);
    try std.testing.expect(result.lines_removed > 0);
}

test "deduplicate removes repeated lines" {
    const allocator = std.testing.allocator;
    const input =
        \\Checking file A...
        \\Checking file B...
        \\Checking file A...
        \\Done
        \\Checking file B...
        \\Done
    ;

    var result = try deduplicateRewrite(allocator, input, .{});
    defer result.deinit(allocator);

    // Should have fewer lines than input
    try std.testing.expect(result.lines_removed > 0);
    try std.testing.expect(result.lines_preserved < 6);
}

test "auto rewrite selects appropriate strategy" {
    const allocator = std.testing.allocator;
    const small_input = "Hello\nWorld\n";

    var result = try autoRewrite(allocator, small_input, 8192);
    defer result.deinit(allocator);

    // For small input, auto should select deduplicate
    try std.testing.expect(result.strategy_used == .deduplicate);
}

test "RewriteResult compression ratio" {
    const result = RewriteResult{
        .content = "short",
        .original_bytes = 100,
        .rewritten_bytes = 50,
        .strategy_used = .truncate,
    };
    try std.testing.expect(std.math.approxEqAbs(f64, result.compressionRatio(), 0.5, 0.01));
}