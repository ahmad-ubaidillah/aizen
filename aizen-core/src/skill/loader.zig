//! Skill Loader — SKILL.md parser for Aizen Agent.
//!
//! Parses skill files in the Hermes-compatible SKILL.md format:
//!   - YAML frontmatter between --- delimiters
//!   - Markdown body with instructions
//!   - Supports triggers, toolsets, version, category metadata
//!
//! Phase 0 of Python→Zig conversion: the hot-path (parsing) moves to Zig.
//! The cold-path (curation, self-learning) stays in Python.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Parsed skill metadata from YAML frontmatter.
pub const SkillConfig = struct {
    name: []const u8 = "",
    version: []const u8 = "0.1.0",
    category: []const u8 = "general",
    description: []const u8 = "",
    triggers: [][]const u8 = &[_][]const u8{},
    toolsets: [][]const u8 = &[_][]const u8{},

    /// Free parsed memory.
    pub fn deinit(self: @This(), allocator: Allocator) void {
        for (self.triggers) |t| allocator.free(t);
        for (self.toolsets) |t| allocator.free(t);
        allocator.free(self.triggers);
        allocator.free(self.toolsets);
    }
};

/// A fully parsed SKILL.md file.
pub const Skill = struct {
    config: SkillConfig,
    body: []const u8 = "",
    path: []const u8 = "",
    raw_frontmatter: []const u8 = "",

    /// Check if this skill matches a trigger query.
    pub fn matchesTrigger(self: @This(), query: []const u8) bool {
        for (self.config.triggers) |trigger| {
            if (std.mem.indexOf(u8, query, trigger) != null) return true;
        }
        return false;
    }

    /// Check if this skill belongs to a category.
    pub fn matchesCategory(self: @This(), category: []const u8) bool {
        return std.mem.eql(u8, self.config.category, category);
    }
};

/// Parse a SKILL.md file and return a Skill object.
/// The caller owns the returned memory and must call skill.config.deinit().
pub fn parseSkillFile(allocator: Allocator, path: []const u8) Error!?Skill {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.log.warn("Failed to open skill file {s}: {}", .{ path, err });
        return null;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch return Error.OutOfMemory;
    defer allocator.free(content);

    return parseSkillContent(allocator, content, path);
}

/// Parse SKILL.md content from a string.
pub fn parseSkillContent(allocator: Allocator, content: []const u8, path: []const u8) Error!?Skill {
    // Extract YAML frontmatter between --- delimiters
    if (!std.mem.startsWith(u8, content, "---")) {
        // No frontmatter — return basic skill with name from path
        const name = extractNameFromPath(path);
        return Skill{
            .config = SkillConfig{ .name = try allocator.dupe(u8, name) },
            .body = try allocator.dupe(u8, content),
            .path = try allocator.dupe(u8, path),
        };
    }

    // Find closing ---
    const open_end = std.mem.indexOf(u8, content[3..], "---") orelse {
        // No closing delimiter — treat as plain content
        const name = extractNameFromPath(path);
        return Skill{
            .config = SkillConfig{ .name = try allocator.dupe(u8, name) },
            .body = try allocator.dupe(u8, content),
            .path = try allocator.dupe(u8, path),
        };
    };

    const frontmatter = content[3 .. open_end + 3];
    const body_start = open_end + 6; // Skip ---
    const body = if (body_start < content.len) std.mem.trim(u8, content[body_start..], " \n\r\t") else "";

    const config = parseYamlFrontmatter(allocator, frontmatter) catch {
        // Fall back to basic skill if YAML parsing fails
        const name = extractNameFromPath(path);
        return Skill{
            .config = SkillConfig{ .name = try allocator.dupe(u8, name) },
            .body = try allocator.dupe(u8, body),
            .path = try allocator.dupe(u8, path),
        };
    };

    return Skill{
        .config = config,
        .body = try allocator.dupe(u8, body),
        .path = try allocator.dupe(u8, path),
        .raw_frontmatter = try allocator.dupe(u8, frontmatter),
    };
}

/// Extract skill name from a file path.
/// e.g., "/home/user/skills/deploy/SKILL.md" -> "deploy"
fn extractNameFromPath(path: []const u8) []const u8 {
    // Find last / before SKILL.md
    var last_sep: usize = 0;
    for (path, 0..) |ch, i| {
        if (ch == '/') last_sep = i;
    }

    if (last_sep > 0) {
        const parent = path[0..last_sep];
        // Find second-to-last /
        var second_sep: usize = 0;
        for (parent, 0..) |ch, i| {
            if (ch == '/') second_sep = i;
        }
        if (second_sep > 0) {
            return parent[second_sep + 1 ..];
        }
        return parent;
    }
    return "unknown";
}

/// Minimal YAML frontmatter parser.
/// Handles: name, version, category, description, triggers (list), toolsets (list).
fn parseYamlFrontmatter(allocator: Allocator, yaml: []const u8) Error!SkillConfig {
    var config = SkillConfig{};
    var lines = std.mem.splitSequence(u8, yaml, "\n");

    var current_list: enum { none, triggers, toolsets } = .none;
    var triggers = std.ArrayList([]const u8).init(allocator);
    var toolsets = std.ArrayList([]const u8).init(allocator);

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) continue;

        // List items (e.g., "  - deploy")
        if (std.mem.startsWith(u8, trimmed, "- ")) {
            const value = std.mem.trim(u8, trimmed[2..], " \t\"'");
            switch (current_list) {
                .triggers => {
                    triggers.append(try allocator.dupe(u8, value)) catch {};
                },
                .toolsets => {
                    toolsets.append(try allocator.dupe(u8, value)) catch {};
                },
                .none => {},
            }
            continue;
        }

        // Key-value pairs (e.g., "name: deploy")
        if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
            const key = std.mem.trim(u8, trimmed[0..colon_pos], " \t");
            const val = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t\"'");

            if (std.mem.eql(u8, key, "name")) {
                config.name = try allocator.dupe(u8, val);
            } else if (std.mem.eql(u8, key, "version")) {
                config.version = try allocator.dupe(u8, val);
            } else if (std.mem.eql(u8, key, "category")) {
                config.category = try allocator.dupe(u8, val);
            } else if (std.mem.eql(u8, key, "description")) {
                config.description = try allocator.dupe(u8, val);
            } else if (std.mem.eql(u8, key, "triggers")) {
                current_list = .triggers;
            } else if (std.mem.eql(u8, key, "toolsets")) {
                current_list = .toolsets;
            } else {
                current_list = .none;
            }
        }
    }

    config.triggers = triggers.items;
    config.toolsets = toolsets.items;
    return config;
}

pub const Error = error{
    OutOfMemory,
    FileNotFound,
    ParseFailed,
};

// === Tests ===

test "parseSkillFile with frontmatter" {
    const allocator = std.testing.allocator;
    const content =
        \\---
        \\name: deploy
        \\version: 1.0.0
        \\category: devops
        \\description: "Deploy to production"
        \\triggers:
        \\  - deploy
        \\  - release
        \\toolsets:
        \\  - terminal
        \\  - web
        \\---
        \\# Deploy Skill
        \\
        \\Steps:
        \\1. Run tests
        \\2. Build and deploy
    ;

    const skill = (try parseSkillContent(allocator, content, "/skills/deploy/SKILL.md")) orelse
        unreachable;

    try std.testing.expectEqualStrings("deploy", skill.config.name);
    try std.testing.expectEqualStrings("1.0.0", skill.config.version);
    try std.testing.expectEqualStrings("devops", skill.config.category);
    try std.testing.expectEqualStrings("Deploy to production", skill.config.description);
    try std.testing.expect(skill.config.triggers.len == 2);
    try std.testing.expect(skill.config.toolsets.len == 2);
    try std.testing.expect(skill.matchesTrigger("deploy to prod"));
    try std.testing.expect(!skill.matchesTrigger("hello world"));

    // Cleanup
    for (skill.config.triggers) |t| allocator.free(t);
    for (skill.config.toolsets) |t| allocator.free(t);
    allocator.free(skill.config.triggers);
    allocator.free(skill.config.toolsets);
    allocator.free(skill.config.name);
    allocator.free(skill.config.body);
    allocator.free(skill.config.path);
}

test "parseSkillFile without frontmatter" {
    const allocator = std.testing.allocator;
    const content = "# Simple Skill\n\nJust instructions here.";

    const skill = (try parseSkillContent(allocator, content, "/skills/simple/SKILL.md")) orelse
        unreachable;

    try std.testing.expectEqualStrings("simple", skill.config.name);
    try std.testing.expect(skill.config.triggers.len == 0);

    allocator.free(skill.config.name);
    allocator.free(skill.config.body);
    allocator.free(skill.config.path);
}

test "extractNameFromPath" {
    try std.testing.expectEqualStrings("deploy", extractNameFromPath("/home/user/skills/deploy/SKILL.md"));
    try std.testing.expectEqualStrings("my-skill", extractNameFromPath("/skills/my-skill/SKILL.md"));
}

test "matchesTrigger" {
    const skill = Skill{
        .config = SkillConfig{
            .triggers = &.{ "deploy", "release" },
        },
    };
    try std.testing.expect(skill.matchesTrigger("deploy to prod"));
    try std.testing.expect(skill.matchesTrigger("release v1"));
    try std.testing.expect(!skill.matchesTrigger("hello world"));
}