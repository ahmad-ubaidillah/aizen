//! Tool Output Pruning — reduce context size by pruning old/large tool outputs.
//!
//! Before compaction runs, the ToolPruner identifies old and oversized tool outputs
//! and summarizes or removes them. This saves 30-50% of tokens that would otherwise
//! be processed by the compaction pipeline.
//!
//! Port of Hermes Agent's tool_pruning.py to Zig.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Configuration for tool output pruning.
pub const PruningConfig = struct {
    /// Maximum number of old (non-recent) tool outputs to keep.
    /// Older outputs beyond this count are candidates for pruning.
    max_old_outputs: usize = 5,

    /// Maximum characters per tool output before it gets truncated.
    /// Outputs exceeding this are truncated with a summary marker.
    max_output_chars: usize = 4000,

    /// Whether to summarize pruned outputs (true) or simply remove them (false).
    /// Summarization preserves key info in fewer tokens.
    summarize: bool = true,

    /// Summarization marker inserted when output is truncated.
    truncation_marker: []const u8 = "\n[...truncated, {d} chars omitted...]",

    /// Whether pruning is enabled.
    enabled: bool = true,
};

/// A single tool output in the conversation history.
pub const ToolOutput = struct {
    /// Tool name that produced this output.
    tool_name: []const u8,

    /// The actual output content.
    content: []const u8,

    /// Turn index (0 = current, higher = older).
    turn_index: usize,

    /// Token count estimate (chars / 4).
    estimated_tokens: usize,

    /// Whether this output has been pruned.
    pruned: bool = false,

    pub fn estimateTokens(content: []const u8) usize {
        // Rough estimate: 1 token ≈ 4 characters
        return @max(1, content.len / 4);
    }
};

/// Result of a pruning operation.
pub const PruningResult = struct {
    /// Total tool outputs in the conversation.
    total_outputs: usize,

    /// Number of outputs that were pruned.
    pruned_count: usize,

    /// Original total character count.
    original_chars: usize,

    /// New total character count after pruning.
    pruned_chars: usize,

    /// Token savings estimate.
    tokens_saved: usize,

    /// The pruned conversation content.
    pruned_outputs: []ToolOutput,

    pub fn reductionPct(self: @This()) f64 {
        if (self.original_chars == 0) return 0.0;
        return @as(f64, @floatFromInt(self.original_chars - self.pruned_chars)) /
            @as(f64, @floatFromInt(self.original_chars)) * 100.0;
    }
};

/// Tool output pruner — reduces context size by pruning old/large outputs.
pub const ToolPruner = struct {
    allocator: Allocator,
    config: PruningConfig,

    pub fn init(allocator: Allocator, config: PruningConfig) @This() {
        return @This(){
            .allocator = allocator,
            .config = config,
        };
    }

    /// Default pruner with sensible defaults.
    pub fn initDefault(allocator: Allocator) @This() {
        return init(allocator, .{});
    }

    /// Prune tool outputs according to configuration.
    /// Returns a PruningResult with the pruned outputs and statistics.
    pub fn prune(self: @This(), outputs: []ToolOutput) Error!PruningResult {
        if (!self.config.enabled or outputs.len == 0) {
            return PruningResult{
                .total_outputs = outputs.len,
                .pruned_count = 0,
                .original_chars = 0,
                .pruned_chars = 0,
                .tokens_saved = 0,
                .pruned_outputs = outputs,
            };
        }

        var original_chars: usize = 0;
        var pruned_chars: usize = 0;
        var pruned_count: usize = 0;
        var tokens_saved: usize = 0;

        // Create mutable copy of outputs
        var pruned = self.allocator.alloc(ToolOutput, outputs.len) catch return Error.OutOfMemory;
        @memcpy(pruned, outputs);

        for (pruned, 0..) |*output, i| {
            original_chars += output.content.len;

            if (i < self.config.max_old_outputs) {
                // Recent outputs — keep but truncate if too large
                if (output.content.len > self.config.max_output_chars) {
                    const truncated = self.allocator.dupe(u8, output.content[0..self.config.max_output_chars]) catch
                        output.content;
                    const marker = std.fmt.allocPrint(self.allocator, self.config.truncation_marker, .{
                        output.content.len - self.config.max_output_chars,
                    }) catch "...";
                    defer self.allocator.free(marker);

                    const combined_len = self.config.max_output_chars + marker.len;
                    const combined = self.allocator.alloc(u8, combined_len) catch break;
                    @memcpy(combined[0..truncated.len], truncated);
                    @memcpy(combined[truncated.len..combined_len], marker);

                    output.content = combined;
                    output.pruned = true;
                    pruned_count += 1;
                }
                pruned_chars += output.content.len;
            } else {
                // Old outputs — summarize or remove
                if (self.config.summarize) {
                    // Replace with a one-line summary
                    const summary = std.fmt.allocPrint(self.allocator,
                        "[{s} output: {d} chars, {d} tokens — pruned]",
                        .{
                            output.tool_name,
                            outputs[i].content.len,
                            ToolOutput.estimateTokens(outputs[i].content),
                        },
                    ) catch "[pruned]";

                    tokens_saved += ToolOutput.estimateTokens(outputs[i].content) -
                        ToolOutput.estimateTokens(summary);
                    output.content = summary;
                    output.pruned = true;
                    pruned_count += 1;
                    pruned_chars += output.content.len;
                } else {
                    // Remove entirely
                    output.content = "";
                    output.pruned = true;
                    pruned_count += 1;
                    tokens_saved += ToolOutput.estimateTokens(outputs[i].content);
                }
            }
        }

        return PruningResult{
            .total_outputs = outputs.len,
            .pruned_count = pruned_count,
            .original_chars = original_chars,
            .pruned_chars = pruned_chars,
            .tokens_saved = tokens_saved,
            .pruned_outputs = pruned,
        };
    }

    /// Quick estimate of how many tokens can be saved by pruning.
    pub fn estimateSavings(self: @This(), outputs: []ToolOutput) usize {
        if (!self.config.enabled) return 0;

        var savings: usize = 0;
        for (outputs, 0..) |output, i| {
            if (i >= self.config.max_old_outputs) {
                // Old output: full savings
                savings += ToolOutput.estimateTokens(output.content);
            } else if (output.content.len > self.config.max_output_chars) {
                // Recent but oversized: partial savings
                const truncated_tokens = ToolOutput.estimateTokens(
                    output.content[0..self.config.max_output_chars],
                );
                savings += ToolOutput.estimateTokens(output.content) - truncated_tokens;
            }
        }
        return savings;
    }
};

pub const Error = error{
    OutOfMemory,
    PruningFailed,
};

// === Tests ===

test "ToolPruner disabled returns original" {
    const allocator = std.testing.allocator;
    const pruner = ToolPruner.init(allocator, .{ .enabled = false });

    const outputs = [_]ToolOutput{
        .{ .tool_name = "shell", .content = "output1", .turn_index = 0, .estimated_tokens = 1 },
        .{ .tool_name = "shell", .content = "output2", .turn_index = 1, .estimated_tokens = 1 },
    };

    const result = try pruner.prune(&outputs);
    try std.testing.expect(result.pruned_count == 0);
    try std.testing.expect(result.tokens_saved == 0);
}

test "ToolPruner prunes old outputs beyond max_old_outputs" {
    const allocator = std.testing.allocator;
    const pruner = ToolPruner.init(allocator, .{
        .max_old_outputs = 2,
        .summarize = true,
    });

    const outputs = [_]ToolOutput{
        .{ .tool_name = "shell", .content = "recent output 1", .turn_index = 0, .estimated_tokens = 10 },
        .{ .tool_name = "shell", .content = "recent output 2", .turn_index = 1, .estimated_tokens = 10 },
        .{ .tool_name = "shell", .content = "old output that is quite long and should be pruned", .turn_index = 2, .estimated_tokens = 50 },
    };

    const result = try pruner.prune(&outputs);
    try std.testing.expect(result.pruned_count == 1);
    try std.testing.expect(result.tokens_saved > 0);
}

test "ToolPruner truncates large recent outputs" {
    const allocator = std.testing.allocator;
    const pruner = ToolPruner.init(allocator, .{
        .max_output_chars = 10,
        .max_old_outputs = 5,
        .summarize = false,
    });

    const long_content = "This is a very long output that exceeds the 10 character limit for recent outputs";
    const outputs = [_]ToolOutput{
        .{ .tool_name = "shell", .content = long_content, .turn_index = 0, .estimated_tokens = 50 },
    };

    const result = try pruner.prune(&outputs);
    try std.testing.expect(result.pruned_count == 1);
}

test "estimateSavings returns correct count" {
    const allocator = std.testing.allocator;
    const pruner = ToolPruner.init(allocator, .{
        .max_old_outputs = 1,
    });

    const outputs = [_]ToolOutput{
        .{ .tool_name = "shell", .content = "short", .turn_index = 0, .estimated_tokens = 5 },
        .{ .tool_name = "shell", .content = "old long output that should be pruned for savings", .turn_index = 1, .estimated_tokens = 40 },
    };

    const savings = pruner.estimateSavings(&outputs);
    try std.testing.expect(savings > 0);
}

test "PruningResult reduction calculation" {
    const result = PruningResult{
        .total_outputs = 10,
        .pruned_count = 3,
        .original_chars = 10000,
        .pruned_chars = 4000,
        .tokens_saved = 1500,
        .pruned_outputs = &.{},
    };
    try std.testing.expect(result.reductionPct() == 60.0);
}