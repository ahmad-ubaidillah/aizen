//! OMNI hook dispatch — routes agent loop events to OMNI pipeline hooks.
//!
//! Hook types mapped to agent loop stages:
//!   session_start  → Before first LLM call
//!   post_tool_use   → After tool execution (distill tool output)
//!   pre_compact     → Before context compaction
//!   session_end     → On session close
//!
//! Architecture: architecture-omni-hermes-zig.md §1.2

const std = @import("std");
const log = std.log.scoped(.omni);
const root = @import("root.zig");
const bridge = @import("bridge.zig");
const OmniBridge = bridge.OmniBridge;
const OmniHook = root.OmniHook;
const DistillResult = root.DistillResult;

const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════
// Hook dispatch functions
// ═══════════════════════════════════════════════════════════════════════════

/// Distill tool output after tool execution.
/// Called from the agent loop after a tool call completes.
/// Returns the distilled output, or the original output if OMNI is disabled
/// or the distillation fails (graceful fallback).
pub fn postToolDistill(
    omni: *OmniBridge,
    command: []const u8,
    output: []const u8,
) []const u8 {
    if (!omni.config.enabled) return output;

    const result = omni.distill(command, output, .post_tool_use) catch {
        log.debug("OMNI post-tool distill failed; using original output", .{});
        return output;
    };

    if (result.skipped) return output;

    if (result.lines_removed > 0 or result.tokens_saved > 0) {
        log.info("OMNI: distilled '{s}' — removed {d} lines, saved ~{d} tokens", .{
            if (command.len > 40) command[0..40] else command,
            result.lines_removed,
            result.tokens_saved,
        });
    }

    return result.distilled_output;
}

/// Distill context before compaction.
/// Called from compaction.zig before sending history to the summarizer.
/// Returns the distilled context, or the original if OMNI is disabled.
pub fn preCompactDistill(
    omni: *OmniBridge,
    context_text: []const u8,
) []const u8 {
    if (!omni.config.enabled) return context_text;

    const compressed = omni.compress(context_text) catch {
        log.debug("OMNI pre-compact distill failed; using original context", .{});
        return context_text;
    };

    if (compressed.len < context_text.len) {
        log.info("OMNI: pre-compact compressed {d} → {d} chars", .{
            context_text.len,
            compressed.len,
        });
    }

    return compressed;
}

// ═══════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════

test "postToolDistill returns original when disabled" {
    const root_config = root.OmniConfig{ .enabled = false };
    var br = OmniBridge.init(std.testing.allocator, root_config);
    defer br.deinit();

    const result = postToolDistill(&br, "git status", "output");
    try std.testing.expectEqualStrings("output", result);
}