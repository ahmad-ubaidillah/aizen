//! OMNI module — semantic signal engine for token optimization.
//! Provides distillation of tool output before LLM context injection.

pub const bridge = @import("bridge.zig");
pub const OmniBridge = bridge.OmniBridge;

pub const DistillResult = bridge.DistillResult;
pub const RetrieveResult = bridge.RetrieveResult;
pub const CompressEntry = bridge.CompressEntry;

test {
    _ = bridge;
}