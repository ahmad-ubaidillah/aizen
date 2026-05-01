const std = @import("std");
const builtin = @import("builtin");
const Sandbox = @import("sandbox.zig").Sandbox;

/// Landlock sandbox backend for Linux kernel 5.13+ LSM.
///
/// **Reserved for future implementation.** This module is a stub that
/// defines the vtable wiring and syscall stubs, but does not yet create
/// Landlock rulesets or call `landlock_restrict_self()`. Until ruleset
/// enforcement is implemented, `isAvailable()` always returns `false`
/// so that the sandbox selector never picks Landlock.
///
/// **Production sandboxes:** Firejail and Bubblewrap are the currently
/// supported sandbox backends for production use. Use them for any
/// real filesystem/process isolation in aizen.
///
/// On non-Linux platforms, returns error.UnsupportedPlatform.
pub const LandlockSandbox = struct {
    workspace_dir: []const u8,

    pub const sandbox_vtable = Sandbox.VTable{
        .wrapCommand = wrapCommand,
        .isAvailable = isAvailable,
        .name = getName,
        .description = getDescription,
    };

    pub fn sandbox(self: *LandlockSandbox) Sandbox {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &sandbox_vtable,
        };
    }

    fn wrapCommand(_: *anyopaque, argv: []const []const u8, _: [][]const u8) anyerror![]const []const u8 {
        if (comptime builtin.os.tag != .linux) {
            return error.UnsupportedPlatform;
        }
        // Landlock applies restrictions via syscalls on the spawning process before exec(),
        // not by prepending a wrapper to the command (unlike firejail/bubblewrap).
        // The caller is responsible for calling landlock_create_ruleset →
        // landlock_add_rule → landlock_restrict_self on the current thread before
        // spawning the child; the child inherits those restrictions automatically.
        // wrapCommand therefore returns argv unchanged — no wrapper is needed.
        return argv;
    }

    /// Returns `false` — Landlock is a **reserved future capability**.
    ///
    /// The vtable and syscall stubs are wired, but aizen does not yet
    /// create Landlock rulesets or call `landlock_restrict_self()`.
    /// Advertising availability would be a false security signal.
    ///
    /// For production sandboxing, use **Firejail** or **Bubblewrap**,
    /// which are the currently supported sandbox backends.
    fn isAvailable(_: *anyopaque) bool {
        return false;
    }

    fn getName(_: *anyopaque) []const u8 {
        return "landlock";
    }

    fn getDescription(_: *anyopaque) []const u8 {
        if (comptime builtin.os.tag == .linux) {
            return "Linux kernel LSM sandboxing (reserved until ruleset enforcement is implemented)";
        } else {
            return "Linux kernel LSM sandboxing (not available on this platform)";
        }
    }
};

pub fn createLandlockSandbox(workspace_dir: []const u8) LandlockSandbox {
    return .{ .workspace_dir = workspace_dir };
}

// ── Tests ──────────────────────────────────────────────────────────────

test "landlock sandbox name" {
    var ll = createLandlockSandbox("/tmp/workspace");
    const sb = ll.sandbox();
    try std.testing.expectEqualStrings("landlock", sb.name());
}

test "landlock sandbox stays unavailable until ruleset enforcement exists" {
    var ll = createLandlockSandbox("/tmp/workspace");
    const sb = ll.sandbox();
    try std.testing.expect(!sb.isAvailable());
}

test "landlock sandbox wrap command on non-linux returns error" {
    if (comptime builtin.os.tag == .linux) return;
    var ll = createLandlockSandbox("/tmp/workspace");
    const sb = ll.sandbox();
    const argv = [_][]const u8{ "echo", "test" };
    var buf: [16][]const u8 = undefined;
    const result = sb.wrapCommand(&argv, &buf);
    try std.testing.expectError(error.UnsupportedPlatform, result);
}

test "landlock sandbox wrap command on linux passes through" {
    if (comptime builtin.os.tag != .linux) return;
    var ll = createLandlockSandbox("/tmp/workspace");
    const sb = ll.sandbox();
    const argv = [_][]const u8{ "echo", "test" };
    var buf: [16][]const u8 = undefined;
    const result = try sb.wrapCommand(&argv, &buf);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("echo", result[0]);
}
