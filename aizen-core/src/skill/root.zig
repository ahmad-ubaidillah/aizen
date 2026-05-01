//! Skill module — SKILL.md parsing and management for Aizen Agent.
//!
//! Phase 0 of Python→Zig conversion: parsing is native Zig.
//! Phase 1: Skill execution sandbox (future)
//! Phase 2: Hot-reload watching (future)

pub const loader = @import("loader.zig");
pub const Skill = loader.Skill;
pub const SkillConfig = loader.SkillConfig;

test {
    _ = loader;
}