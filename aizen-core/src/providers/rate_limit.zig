// Rate Limit Tracker — Per-provider rate limit state from x-ratelimit-* headers
// Ported from Hermes rate_limit_tracker.py, adapted for Zig
const std = @import("std");
const std_compat = @import("../compat/shared.zig");

pub const RateLimitBucket = struct {
    limit: u64 = 0,
    remaining: u64 = 0,
    reset_seconds: f64 = 0.0,
    captured_at_ms: i64 = 0,

    pub fn used(self: RateLimitBucket) u64 {
        return if (self.limit > self.remaining) self.limit - self.remaining else 0;
    }

    pub fn usagePercent(self: RateLimitBucket) f64 {
        if (self.limit == 0) return 0.0;
        return @as(f64, @floatFromInt(self.used())) / @as(f64, @floatFromInt(self.limit)) * 100.0;
    }

    pub fn remainingSecondsNow(self: RateLimitBucket) f64 {
        if (self.captured_at_ms == 0) return 0.0;
        const now_ms = std_compat.time.milliTimestamp();
        const elapsed_s = @as(f64, @floatFromInt(@max(0, now_ms - self.captured_at_ms))) / 1000.0;
        return @max(0.0, self.reset_seconds - elapsed_s);
    }

    pub fn hasData(self: RateLimitBucket) bool {
        return self.captured_at_ms > 0;
    }
};

pub const RateLimitState = struct {
    requests_min: RateLimitBucket = .{},
    requests_hour: RateLimitBucket = .{},
    tokens_min: RateLimitBucket = .{},
    tokens_hour: RateLimitBucket = .{},
    captured_at_ms: i64 = 0,
    provider: []const u8 = "",

    pub fn hasData(self: RateLimitState) bool {
        return self.captured_at_ms > 0;
    }

    pub fn highestUsagePercent(self: RateLimitState) f64 {
        var max_pct: f64 = 0.0;
        max_pct = @max(max_pct, self.requests_min.usagePercent());
        max_pct = @max(max_pct, self.requests_hour.usagePercent());
        max_pct = @max(max_pct, self.tokens_min.usagePercent());
        max_pct = @max(max_pct, self.tokens_hour.usagePercent());
        return max_pct;
    }

    pub fn isNearLimit(self: RateLimitState, threshold: f64) bool {
        return self.highestUsagePercent() >= threshold;
    }
};

/// Per-provider rate limit registry.
/// Thread-safe via mutex. Stores the most recent rate-limit state per provider.
pub const ProviderRateLimitRegistry = struct {
    states: std.HashMapUnmanaged([]const u8, RateLimitState, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ProviderRateLimitRegistry {
        return .{
            .states = .empty,
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ProviderRateLimitRegistry) void {
        var iter = self.states.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key);
        }
        self.states.deinit(self.allocator);
    }

    /// Update rate-limit state for a provider from response headers.
    /// Headers should be pre-lowercased keys. Parses x-ratelimit-* headers.
    pub fn updateFromHeaders(
        self: *ProviderRateLimitRegistry,
        provider: []const u8,
        headers: anytype,
    ) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now_ms = std_compat.time.milliTimestamp();
        var state = RateLimitState{
            .captured_at_ms = now_ms,
            .provider = provider,
        };

        var has_any = false;

        // Parse rate limit headers
        // Format: x-ratelimit-limit-requests, x-ratelimit-remaining-requests, etc.
        // Also supports: x-ratelimit-limit-requests-1h, x-ratelimit-limit-tokens, etc.
        inline for (.{
            .{ "x-ratelimit-limit-requests", &state.requests_min, .limit },
            .{ "x-ratelimit-remaining-requests", &state.requests_min, .remaining },
            .{ "x-ratelimit-reset-requests", &state.requests_min, .reset },
            .{ "x-ratelimit-limit-requests-1h", &state.requests_hour, .limit },
            .{ "x-ratelimit-remaining-requests-1h", &state.requests_hour, .remaining },
            .{ "x-ratelimit-reset-requests-1h", &state.requests_hour, .reset },
            .{ "x-ratelimit-limit-tokens", &state.tokens_min, .limit },
            .{ "x-ratelimit-remaining-tokens", &state.tokens_min, .remaining },
            .{ "x-ratelimit-reset-tokens", &state.tokens_min, .reset },
            .{ "x-ratelimit-limit-tokens-1h", &state.tokens_hour, .limit },
            .{ "x-ratelimit-remaining-tokens-1h", &state.tokens_hour, .remaining },
            .{ "x-ratelimit-reset-tokens-1h", &state.tokens_hour, .reset },
        }) |tuple| {
            const header_name = tuple.@"0";
            const bucket = tuple.@"1";
            const field = tuple.@"2";

            if (headers.get(header_name)) |value| {
                has_any = true;
                switch (field) {
                    .limit => bucket.limit = std.fmt.parseInt(u64, value, 10) catch bucket.limit,
                    .remaining => bucket.remaining = std.fmt.parseInt(u64, value, 10) catch bucket.remaining,
                    .reset => bucket.reset_seconds = std.fmt.parseFloat(f64, value) catch bucket.reset_seconds,
                }
                bucket.captured_at_ms = now_ms;
            }
        }

        // Also try Anthropic-style headers
        if (headers.get("x-ratelimit-limit")) |value| {
            has_any = true;
            state.requests_min.limit = std.fmt.parseInt(u64, value, 10) catch state.requests_min.limit;
            state.requests_min.captured_at_ms = now_ms;
        }
        if (headers.get("x-ratelimit-remaining")) |value| {
            has_any = true;
            state.requests_min.remaining = std.fmt.parseInt(u64, value, 10) catch state.requests_min.remaining;
            state.requests_min.captured_at_ms = now_ms;
        }

        if (!has_any) return;

        // Store or update state
        const owned_provider = self.allocator.dupe(u8, provider) catch return;
        const gop = self.states.getOrPut(self.allocator, owned_provider) catch return;
        if (gop.found_existing) {
            self.allocator.free(owned_provider);
            gop.value_ptr.* = state;
        } else {
            gop.value_ptr.* = state;
        }
    }

    /// Get rate limit state for a provider. Returns null if no data.
    pub fn getState(self: *ProviderRateLimitRegistry, provider: []const u8) ?RateLimitState {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.states.get(provider);
    }

    /// Check if a provider is near its rate limit (default threshold 80%).
    pub fn isNearLimit(self: *ProviderRateLimitRegistry, provider: []const u8, threshold: f64) bool {
        const state = self.getState(provider) orelse return false;
        return state.isNearLimit(threshold);
    }

    /// Format a one-line summary of rate limit status for a provider.
    pub fn formatSummary(
        self: *ProviderRateLimitRegistry,
        allocator: std.mem.Allocator,
        provider: []const u8,
    ) ?[]const u8 {
        const state = self.getState(provider) orelse return null;

        const pct = state.highestUsagePercent();
        const bar_len: usize = 20;
        const filled: usize = @intFromFloat(@min(pct / 100.0 * @as(f64, @floatFromInt(bar_len)), @as(f64, @floatFromInt(bar_len))));

        var buf = std.ArrayList(u8).init(allocator);
        const writer = buf.writer();

        writer.writeAll(provider) catch return null;
        writer.writeAll(" [") catch return null;
        var i: usize = 0;
        while (i < bar_len) : (i += 1) {
            writer.writeByte(if (i < filled) '#' else '-') catch return null;
        }
        writer.writeAll("] ") catch return null;
        std.fmt.format(writer, "{d:.1}%", .{pct}) catch return null;

        if (state.requests_min.hasData()) {
            std.fmt.format(writer, " req/min:{d}/{d}", .{ state.requests_min.remaining, state.requests_min.limit }) catch {};
        }
        if (state.tokens_min.hasData()) {
            std.fmt.format(writer, " tok/min:{d}/{d}", .{ state.tokens_min.remaining, state.tokens_min.limit }) catch {};
        }

        return buf.toOwnedSlice() catch null;
    }
};

// ── Tests ──────────────────────────────────────────────────────────────────

test "RateLimitBucket usage calculations" {
    const bucket = RateLimitBucket{
        .limit = 100,
        .remaining = 20,
        .reset_seconds = 60.0,
        .captured_at_ms = 1000000,
    };

    try std.testing.expectEqual(@as(u64, 80), bucket.used());
    try std.testing.expectEqual(@as(f64, 80.0), bucket.usagePercent());
    try std.testing.expect(bucket.hasData());
}

test "RateLimitState highest usage" {
    const state = RateLimitState{
        .requests_min = .{ .limit = 100, .remaining = 10, .captured_at_ms = 1000 },
        .requests_hour = .{ .limit = 1000, .remaining = 800, .captured_at_ms = 1000 },
        .tokens_min = .{ .limit = 100000, .remaining = 30000, .captured_at_ms = 1000 },
        .tokens_hour = .{ .limit = 500000, .remaining = 400000, .captured_at_ms = 1000 },
        .captured_at_ms = 1000,
        .provider = "openrouter",
    };

    // 90% requests/min, 20% requests/hour, 70% tokens/min, 20% tokens/hour
    // Highest = 90%
    try std.testing.expect(std.math.approxEqAbs(f64, state.highestUsagePercent(), 90.0, 0.01));
    try std.testing.expect(state.isNearLimit(80.0));
    try std.testing.expect(!state.isNearLimit(95.0));
}

test "ProviderRateLimitRegistry basic operations" {
    const allocator = std.testing.allocator;
    var registry = ProviderRateLimitRegistry.init(allocator);
    defer registry.deinit();

    // Simulate headers from a response
    const TestHeaders = struct {
        data: std.HashMapUnmanaged([]const u8, []const u8, struct {
            pub fn hash(self: @This(), key: []const u8) u64 {
                return std.hash.Wyhash.hash(0, key);
            }
            pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
                return std.mem.eql(u8, a, b);
            }
        }, 80),

        pub fn get(self: @This(), key: []const u8) ?[]const u8 {
            return self.data.get(key);
        }
    };

    var hmap = std.HashMapUnmanaged([]const u8, []const u8, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80).empty;
    defer hmap.deinit(allocator);

    hmap.put(allocator, "x-ratelimit-limit-requests", "60") catch {};
    hmap.put(allocator, "x-ratelimit-remaining-requests", "45") catch {};
    hmap.put(allocator, "x-ratelimit-reset-requests", "60") catch {};
    hmap.put(allocator, "x-ratelimit-limit-tokens", "150000") catch {};
    hmap.put(allocator, "x-ratelimit-remaining-tokens", "75000") catch {};

    const headers = TestHeaders{ .data = hmap };
    registry.updateFromHeaders("openrouter", headers);

    const state = registry.getState("openrouter");
    try std.testing.expect(state != null);
    if (state) |s| {
        try std.testing.expectEqual(@as(u64, 60), s.requests_min.limit);
        try std.testing.expectEqual(@as(u64, 45), s.requests_min.remaining);
        try std.testing.expect(state.?.isNearLimit(20.0)); // 25% used for req/min, 50% for tokens
    }
}