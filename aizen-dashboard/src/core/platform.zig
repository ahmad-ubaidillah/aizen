const std = @import("std");
const builtin = @import("builtin");

pub const PlatformKey = enum {
    @"x86_64-linux",
    @"aarch64-linux",
    @"riscv64-linux",
    @"aarch64-macos",
    @"x86_64-macos",
    @"x86_64-windows",
    @"aarch64-windows",
    unknown,

    pub fn toString(self: PlatformKey) []const u8 {
        return @tagName(self);
    }
};

pub fn detect() PlatformKey {
    const arch = builtin.cpu.arch;
    const os = builtin.os.tag;

    return switch (os) {
        .linux => switch (arch) {
            .x86_64 => .@"x86_64-linux",
            .aarch64 => .@"aarch64-linux",
            .riscv64 => .@"riscv64-linux",
            else => .unknown,
        },
        .macos => switch (arch) {
            .aarch64 => .@"aarch64-macos",
            .x86_64 => .@"x86_64-macos",
            else => .unknown,
        },
        .windows => switch (arch) {
            .x86_64 => .@"x86_64-windows",
            .aarch64 => .@"aarch64-windows",
            else => .unknown,
        },
        else => .unknown,
    };
}

test "detect returns a known platform on test host" {
    const key = detect();
    try std.testing.expect(key != .unknown);
}

test "toString returns expected format" {
    const key = PlatformKey.@"aarch64-macos";
    try std.testing.expectEqualStrings("aarch64-macos", key.toString());
}
