// Credential Pool — Multi-API-key rotation with per-provider tracking and auto-failover
// Ported from Hermes credential_pool.py, adapted for Zig idioms and Aizen architecture
const std = @import("std");
const compat = @import("../compat.zig");
const std_compat = @import("../compat/shared.zig");
const config_types = @import("../config_types.zig");
const api_key = @import("api_key.zig");
const secrets = @import("../security/secrets.zig");

pub const CredentialStatus = enum { ok, exhausted };
pub const AuthType = enum { api_key, oauth };
pub const PoolStrategy = enum { fill_first, round_robin, least_used, random };

pub const EXHAUSTED_TTL_429_MS: u64 = 60 * 60 * 1000; // 1 hour for rate-limit (429)
pub const EXHAUSTED_TTL_DEFAULT_MS: u64 = 60 * 60 * 1000; // 1 hour default
pub const MAX_CREDENTIALS_PER_PROVIDER: usize = 32;

pub const PooledCredential = struct {
    id: []const u8,
    provider: []const u8,
    label: []const u8,
    auth_type: AuthType,
    priority: u16,
    source: []const u8,
    access_token: []const u8,
    refresh_token: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
    // Status tracking
    status: CredentialStatus = .ok,
    status_at_ms: ?i64 = null,
    error_code: ?u16 = null,
    error_reason: ?[]const u8 = null,
    error_reset_at_ms: ?i64 = null,
    // Usage tracking
    request_count: u32 = 0,

    pub fn deinit(self: *PooledCredential, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.provider);
        allocator.free(self.label);
        allocator.free(self.source);
        allocator.free(self.access_token);
        if (self.refresh_token) |rt| allocator.free(rt);
        if (self.base_url) |bu| allocator.free(bu);
        if (self.error_reason) |er| allocator.free(er);
    }
};

fn exhaustedUntil(entry: *const PooledCredential) ?i64 {
    if (entry.status != .exhausted) return null;
    if (entry.error_reset_at_ms) |reset_at| {
        if (reset_at > 0) return reset_at;
    }
    if (entry.status_at_ms) |at| {
        const ttl: u64 = if (entry.error_code == 429) EXHAUSTED_TTL_429_MS else EXHAUSTED_TTL_DEFAULT_MS;
        return at + @as(i64, @intCast(ttl));
    }
    return null;
}

fn isAvailable(entry: *const PooledCredential, now_ms: i64) bool {
    if (entry.status != .exhausted) return true;
    const until = exhaustedUntil(entry) orelse return false;
    return now_ms >= until;
}

fn generateShortId(allocator: std.mem.Allocator) ![]const u8 {
    var buf: [6]u8 = undefined;
    std.crypto.random.bytes(&buf);
    const hex = try allocator.alloc(u8, 12);
    _ = std.fmt.bufPrint(hex, "{x:0=12}", .{std.mem.readInt(u48, &buf, .little)}) catch "000000000000";
    // Simpler: just hex-encode the random bytes
    for (buf, 0..) |byte, i| {
        const hi = std.fmt.digitToChar(@intCast(byte >> 4), .lower) catch '0';
        const lo = std.fmt.digitToChar(@intCast(byte & 0xf), .lower) catch '0';
        hex[i * 2] = hi;
        hex[i * 2 + 1] = lo;
    }
    return hex[0..12];
}

pub const CredentialPool = struct {
    provider: []const u8,
    entries: std.ArrayListUnmanaged(*PooledCredential),
    strategy: PoolStrategy,
    current_index: ?usize,
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, provider: []const u8, strategy: PoolStrategy) !CredentialPool {
        const owned_provider = try allocator.dupe(u8, provider);
        return CredentialPool{
            .provider = owned_provider,
            .entries = .empty,
            .strategy = strategy,
            .current_index = null,
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CredentialPool) void {
        for (self.entries.items) |entry| {
            entry.deinit(self.allocator);
            self.allocator.destroy(entry);
        }
        self.entries.deinit(self.allocator);
        self.allocator.free(self.provider);
    }

    pub fn select(self: *CredentialPool) ?*PooledCredential {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.selectUnlocked();
    }

    fn selectUnlocked(self: *CredentialPool) ?*PooledCredential {
        const now_ms = std_compat.time.milliTimestamp();
        // Clear stale exhausted entries first
        self.clearExpiredUnlocked(now_ms);
        // Build available list
        var available = std.ArrayList(usize).initCapacity(self.allocator, self.entries.items.len) catch return null;
        defer available.deinit();
        for (self.entries.items, 0..) |entry, i| {
            if (isAvailable(entry, now_ms)) {
                available.append(i) catch return null;
            }
        }
        if (available.items.len == 0) return null;

        const idx = switch (self.strategy) {
            .fill_first => available.items[0],
            .round_robin => blk: {
                const current = self.current_index orelse available.items[0];
                var best: usize = available.items[0];
                for (available.items) |a| {
                    if (a > current) {
                        best = a;
                        break;
                    }
                }
                break :blk best;
            },
            .least_used => blk: {
                var best_idx: usize = available.items[0];
                var best_count: u32 = self.entries.items[best_idx].request_count;
                for (available.items[1..]) |a| {
                    if (self.entries.items[a].request_count < best_count) {
                        best_idx = a;
                        best_count = self.entries.items[a].request_count;
                    }
                }
                break :blk best_idx;
            },
            .random => available.items[std.crypto.random.intRangeLessThan(usize, 0, available.items.len)],
        };
        self.current_index = idx;
        self.entries.items[idx].request_count += 1;
        return self.entries.items[idx];
    }

    pub fn markExhaustedAndRotate(
        self: *CredentialPool,
        error_code: ?u16,
        error_reason: ?[]const u8,
        error_reset_at_ms: ?i64,
    ) ?*PooledCredential {
        self.mutex.lock();
        defer self.mutex.unlock();
        const current = self.current_index orelse return self.selectUnlocked();
        const entry = self.entries.items[current];
        const now_ms = std_compat.time.milliTimestamp();
        entry.status = .exhausted;
        entry.status_at_ms = now_ms;
        entry.error_code = error_code;
        if (error_reason) |reason| {
            if (entry.error_reason) |old| self.allocator.free(old);
            entry.error_reason = self.allocator.dupe(u8, reason) catch null;
        }
        entry.error_reset_at_ms = error_reset_at_ms;
        return self.selectUnlocked();
    }

    pub fn peek(self: *CredentialPool) ?*PooledCredential {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.current_index) |idx| {
            if (idx < self.entries.items.len) return self.entries.items[idx];
        }
        if (self.entries.items.len > 0) return self.entries.items[0];
        return null;
    }

    pub fn addEntry(self: *CredentialPool, entry: PooledCredential) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.entries.items.len >= MAX_CREDENTIALS_PER_PROVIDER) return error.PoolFull;
        const ptr = try self.allocator.create(PooledCredential);
        ptr.* = entry;
        try self.entries.append(self.allocator, ptr);
    }

    pub fn resetStatuses(self: *CredentialPool) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.entries.items) |entry| {
            entry.status = .ok;
            entry.status_at_ms = null;
            entry.error_code = null;
            entry.error_reset_at_ms = null;
        }
    }

    fn clearExpiredUnlocked(self: *CredentialPool, now_ms: i64) void {
        for (self.entries.items) |entry| {
            if (entry.status == .exhausted and isAvailable(entry, now_ms)) {
                entry.status = .ok;
                entry.status_at_ms = null;
                entry.error_code = null;
                entry.error_reset_at_ms = null;
            }
        }
    }

    pub fn persist(self: *CredentialPool) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        // Build path: ~/.aizen/credential_pool/<provider>.json
        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const home = std.posix.getenv("HOME") orelse std.posix.getenv("USERPROFILE") orelse return error.HomeNotFound;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/.aizen/credential_pool/{s}.json", .{ home, self.provider });

        // Ensure directory exists
        const dir_end = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidPath;
        const dir_path = path[0..dir_end];
        std.fs.cwd().makePath(dir_path) catch {};

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();
        try writer.writeAll("{\n  \"provider\": \"");
        try writer.writeAll(self.provider);
        try writer.writeAll("\",\n  \"strategy\": \"");
        try writer.writeAll(@tagName(self.strategy));
        try writer.writeAll("\",\n  \"entries\": [");
        for (self.entries.items, 0..) |entry, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("\n    {\n");
            try std.fmt.format(writer, "      \"id\": \"{s}\",\n", .{entry.id});
            try std.fmt.format(writer, "      \"label\": \"{s}\",\n", .{entry.label});
            try std.fmt.format(writer, "      \"auth_type\": \"{s}\",\n", .{@tagName(entry.auth_type)});
            try std.fmt.format(writer, "      \"priority\": {d},\n", .{entry.priority});
            try std.fmt.format(writer, "      \"source\": \"{s}\",\n", .{entry.source});
            try writer.writeAll("      \"access_token\": \"***\",\n"); // Never persist real keys
            try writer.writeAll("      \"status\": \"");
            try writer.writeAll(@tagName(entry.status));
            try writer.writeAll("\"");
            if (entry.status_at_ms) |t| try std.fmt.format(writer, ",\n      \"status_at_ms\": {d}", .{t});
            if (entry.error_code) |c| try std.fmt.format(writer, ",\n      \"error_code\": {d}", .{c});
            if (entry.error_reset_at_ms) |r| try std.fmt.format(writer, ",\n      \"error_reset_at_ms\": {d}", .{r});
            try std.fmt.format(writer, ",\n      \"request_count\": {d}\n", .{entry.request_count});
            try writer.writeAll("    }");
        }
        try writer.writeAll("\n  ]\n}\n");
    }

    /// Load or create a credential pool for the given provider.
    /// Seeds from config entries and environment variables.
    pub fn load(
        allocator: std.mem.Allocator,
        provider: []const u8,
        config_entries: []const config_types.ProviderEntry,
    ) !CredentialPool {
        var pool = try CredentialPool.init(allocator, provider, .fill_first);
        errdefer pool.deinit();

        // Seed from config
        seedFromConfig(allocator, &pool, config_entries) catch {};
        // Seed from environment
        seedFromEnv(allocator, &pool) catch {};

        return pool;
    }
};

fn seedFromConfig(
    allocator: std.mem.Allocator,
    pool: *CredentialPool,
    entries: []const config_types.ProviderEntry,
) !void {
    for (entries) |entry| {
        if (!std.mem.eql(u8, std.ascii.lowerStringAlloc(allocator, entry.name) catch &.{}, pool.provider)) continue;
        if (entry.api_key) |key| {
            if (key.len == 0) continue;
            const id = try generateShortId(allocator);
            const owned_key = try allocator.dupe(u8, key);
            const source = try std.fmt.allocPrint(allocator, "config:{s}", .{entry.name});
            const owned_label = try allocator.dupe(u8, entry.name);
            const owned_provider = try allocator.dupe(u8, pool.provider);
            const cred = PooledCredential{
                .id = id,
                .provider = owned_provider,
                .label = owned_label,
                .auth_type = .api_key,
                .priority = @intCast(pool.entries.items.len),
                .source = source,
                .access_token = owned_key,
                .base_url = if (entry.base_url) |url| try allocator.dupe(u8, url) else null,
            };
            try pool.addEntry(cred);
        }
    }
}

fn seedFromEnv(allocator: std.mem.Allocator, pool: *CredentialPool) void {
    // Provider-specific env vars
    const provider_upper = std.ascii.allocUpperString(allocator, pool.provider) catch return;
    defer allocator.free(provider_upper);

    const env_patterns = [_][]const u8{
        // Will be composed: AIZEN_{PROVIDER}_API_KEY, {PROVIDER}_API_KEY
    };
    _ = env_patterns;

    // Try AIZEN_{PROVIDER}_API_KEY
    const aizen_key = std.fmt.allocPrint(allocator, "AIZEN_{s}_API_KEY", .{provider_upper}) catch return;
    defer allocator.free(aizen_key);
    if (std.posix.getenv(aizen_key)) |val| {
        if (val.len > 0) {
            const id = generateShortId(allocator) catch return;
            const source = std.fmt.allocPrint(allocator, "env:{s}", .{aizen_key}) catch return;
            const owned_key = allocator.dupe(u8, val) catch return;
            const owned_provider = allocator.dupe(u8, pool.provider) catch return;
            const cred = PooledCredential{
                .id = id,
                .provider = owned_provider,
                .label = allocator.dupe(u8, aizen_key) catch return,
                .auth_type = .api_key,
                .priority = @intCast(pool.entries.items.len),
                .source = source,
                .access_token = owned_key,
            };
            pool.addEntry(cred) catch return;
            return; // Found key, don't try more
        }
    }

    // Try {PROVIDER}_API_KEY
    const plain_key = std.fmt.allocPrint(allocator, "{s}_API_KEY", .{provider_upper}) catch return;
    defer allocator.free(plain_key);
    if (std.posix.getenv(plain_key)) |val| {
        if (val.len > 0) {
            const id = generateShortId(allocator) catch return;
            const source = std.fmt.allocPrint(allocator, "env:{s}", .{plain_key}) catch return;
            const owned_key = allocator.dupe(u8, val) catch return;
            const owned_provider = allocator.dupe(u8, pool.provider) catch return;
            const cred = PooledCredential{
                .id = id,
                .provider = owned_provider,
                .label = allocator.dupe(u8, plain_key) catch return,
                .auth_type = .api_key,
                .priority = @intCast(pool.entries.items.len),
                .source = source,
                .access_token = owned_key,
            };
            pool.addEntry(cred) catch return;
        }
    }

    // Generic fallbacks
    for (&[_][]const u8{ "AIZEN_API_KEY", "API_KEY" }) |env_var| {
        if (std.posix.getenv(env_var)) |val| {
            if (val.len > 0) {
                const id = generateShortId(allocator) catch return;
                const source = std.fmt.allocPrint(allocator, "env:{s}", .{env_var}) catch return;
                const owned_key = allocator.dupe(u8, val) catch return;
                const owned_provider = allocator.dupe(u8, pool.provider) catch return;
                const cred = PooledCredential{
                    .id = id,
                    .provider = owned_provider,
                    .label = allocator.dupe(u8, env_var) catch return,
                    .auth_type = .api_key,
                    .priority = @intCast(pool.entries.items.len),
                    .source = source,
                    .access_token = owned_key,
                };
                pool.addEntry(cred) catch return;
                return;
            }
        }
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

test "PooledCredential init/deinit" {
    const allocator = std.testing.allocator;
    const cred = PooledCredential{
        .id = try allocator.dupe(u8, "abc123"),
        .provider = try allocator.dupe(u8, "openrouter"),
        .label = try allocator.dupe(u8, "test-key"),
        .auth_type = .api_key,
        .priority = 0,
        .source = try allocator.dupe(u8, "env:OPENROUTER_API_KEY"),
        .access_token = try allocator.dupe(u8, "sk-test-key-123"),
    };
    var c = cred;
    c.deinit(allocator);
}

test "CredentialPool select with fill_first" {
    const allocator = std.testing.allocator;
    var pool = try CredentialPool.init(allocator, "openrouter", .fill_first);
    defer pool.deinit();

    try pool.addEntry(.{
        .id = try allocator.dupe(u8, "key1"),
        .provider = try allocator.dupe(u8, "openrouter"),
        .label = try allocator.dupe(u8, "PRIMARY"),
        .auth_type = .api_key,
        .priority = 0,
        .source = try allocator.dupe(u8, "env:OPENROUTER_API_KEY"),
        .access_token = try allocator.dupe(u8, "sk-key-1"),
    });
    try pool.addEntry(.{
        .id = try allocator.dupe(u8, "key2"),
        .provider = try allocator.dupe(u8, "openrouter"),
        .label = try allocator.dupe(u8, "SECONDARY"),
        .auth_type = .api_key,
        .priority = 1,
        .source = try allocator.dupe(u8, "config:openrouter"),
        .access_token = try allocator.dupe(u8, "sk-key-2"),
    });

    const selected = pool.select() orelse unreachable;
    try std.testing.expectEqualStrings("sk-key-1", selected.access_token);
}

test "CredentialPool exhaustion and rotation" {
    const allocator = std.testing.allocator;
    var pool = try CredentialPool.init(allocator, "openrouter", .fill_first);
    defer pool.deinit();

    try pool.addEntry(.{
        .id = try allocator.dupe(u8, "key1"),
        .provider = try allocator.dupe(u8, "openrouter"),
        .label = try allocator.dupe(u8, "PRIMARY"),
        .auth_type = .api_key,
        .priority = 0,
        .source = try allocator.dupe(u8, "env:OPENROUTER_API_KEY"),
        .access_token = try allocator.dupe(u8, "sk-key-1"),
    });
    try pool.addEntry(.{
        .id = try allocator.dupe(u8, "key2"),
        .provider = try allocator.dupe(u8, "openrouter"),
        .label = try allocator.dupe(u8, "SECONDARY"),
        .auth_type = .api_key,
        .priority = 1,
        .source = try allocator.dupe(u8, "config:openrouter"),
        .access_token = try allocator.dupe(u8, "sk-key-2"),
    });

    _ = pool.select(); // Select first
    const next = pool.markExhaustedAndRotate(429, "rate limited", null);
    try std.testing.expect(next != null);
    if (next) |n| {
        try std.testing.expectEqualStrings("sk-key-2", n.access_token);
    }
}