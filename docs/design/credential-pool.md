# Credential Pool & Rate Limiting — Zig Design Document

## 1. Executive Summary

Hermes Agent (Python) implements two complementary systems:

1. **Credential Pool** (`credential_pool.py`) — multi-key per-provider storage with rotation strategies, exhaustion cooldown, OAuth refresh, and persistent JSON state.
2. **Rate Limit Tracker** (`rate_limit_tracker.py`) — parsing of `x-ratelimit-*` response headers into per-provider rate-limit buckets with usage display.

Aizen currently has **neither**. Its `api_key.zig` provides single-key resolution from config/env. Its `ReliableProvider` does simple round-robin key rotation with exponential backoff but has no persistent key pool, no exhaustion tracking, and no per-provider rate-limit state from API responses.

This document designs both subsystems for Aizen in idiomatic Zig, respecting the project's constraints: zero-dependency, <5 MB peak RSS, vtable-based architecture, and explicit allocator discipline.

---

## 2. Hermes Reference Analysis

### 2.1 Credential Pool (Python)

**Core concepts:**

| Concept | Implementation |
|---------|---------------|
| `PooledCredential` | Dataclass with `id`, `provider`, `label`, `auth_type` (api_key/oauth), `priority`, `access_token`, `refresh_token`, `base_url`, plus status fields: `last_status`, `last_status_at`, `last_error_code`, `last_error_reset_at` |
| `CredentialPool` | Per-provider collection sorted by priority; holds entries, strategy, lock, active leases |
| Strategy | `fill_first` (default), `round_robin`, `random`, `least_used` |
| Exhaustion | `STATUS_EXHAUSTED` with cooldown; `_exhausted_until()` computes absolute reset time using `last_error_reset_at` from provider headers or default TTL (1h for 429, 1h default) |
| Cooldown clearing | `_available_entries(clear_expired=True)` clears stale exhausted entries before selection |
| OAuth refresh | `_refresh_entry()` handles anthropic/openai-codex/nous with provider-specific refresh flows; sync-backs to auth.json |
| Concurrency | `threading.Lock` for thread safety; `acquire_lease`/`release_lease` for soft concurrent request limiting |
| Persistence | `write_credential_pool()` persists JSON to `~/.hermes/auth_pool/<provider>.json` |
| Seeding | `_seed_from_singletons()` and `_seed_from_env()` auto-discover credentials from auth store and environment variables |

**Selection flow:**
```
select() → lock → _available_entries(clear_expired=True, refresh=True)
  → for each entry:
      - sync from external sources if exhausted
      - if exhausted and cooldown not elapsed → skip
      - if exhausted and cooldown elapsed → clear to OK
      - if OAuth and expired → try refresh (skip on failure)
  → choose by strategy:
      fill_first: first available
      round_robin: rotate priority order
      random: random.choice
      least_used: min(request_count)
  → set _current_id
```

**Key rotation on error:**
```
mark_exhausted_and_rotate(status_code, error_context)
  → mark current entry as exhausted with timestamp + error details
  → rotate to next available entry via select()
```

### 2.2 Rate Limit Tracker (Python)

**Core concepts:**

| Concept | Implementation |
|---------|---------------|
| `RateLimitBucket` | `limit`, `remaining`, `reset_seconds`, `captured_at` — one window (minute or hour) |
| `RateLimitState` | Four buckets: `requests_min`, `requests_hour`, `tokens_min`, `tokens_hour` + `provider` and `captured_at` |
| Header parsing | `parse_rate_limit_headers()` normalizes headers (case-insensitive) and extracts 12 `x-ratelimit-*` headers |
| Reset tracking | `remaining_seconds_now` adjusts `reset_seconds` by elapsed time since capture |
| Display | `format_rate_limit_display()` and `format_rate_limit_compact()` for terminal output |
| Warnings | Automatic warnings when any bucket reaches ≥80% usage |

---

## 3. Design for Aizen

### 3.1 Module Structure

```
src/providers/
  credential_pool.zig    ← NEW: PooledCredential, CredentialPool, strategies
  rate_limit.zig         ← NEW: RateLimitBucket, RateLimitState, header parsing
  api_key.zig            ← EXISTING: enhanced to consume credential pool
  reliable.zig           ← EXISTING: enhanced to use pool rotation + rate limiter
  root.zig               ← EXISTING: add re-exports
```

### 3.2 Credential Pool

#### 3.2.1 PooledCredential

```zig
pub const CredentialStatus = enum {
    ok,
    exhausted,
};

pub const AuthType = enum {
    api_key,
    oauth,
};

pub const PoolStrategy = enum {
    fill_first,
    round_robin,
    least_used,
    random,
};

pub const PooledCredential = struct {
    id: []const u8,             // Short hex ID (6 chars), owned
    provider: []const u8,       // Provider name, owned
    label: []const u8,          // Human-readable label, owned
    auth_type: AuthType,
    priority: u16,
    source: []const u8,         // e.g. "env:OPENROUTER_API_KEY", "manual", owned
    access_token: []const u8,   // The actual key/token, owned
    refresh_token: ?[]const u8 = null,  // For OAuth flows, owned
    base_url: ?[]const u8 = null,       // Override base URL, owned
    // Status tracking
    status: CredentialStatus = .ok,
    status_at_ms: ?i64 = null,           // epoch ms when status was set
    error_code: ?u16 = null,            // HTTP status code that caused exhaustion
    error_reason: ?[]const u8 = null,    // Short reason string, owned
    error_reset_at_ms: ?i64 = null,      // Absolute epoch ms when cooldown lifts
    // Usage tracking
    request_count: u32 = 0,

    pub fn deinit(self: *PooledCredential, allocator: std.mem.Allocator) void { ... }
};
```

**Memory model:** All string fields are owned by the credential and freed in `deinit()`. The pool's arena allocator can amortize this, but each credential individually owns its strings for safe replacement during update.

#### 3.2.2 Exhaustion Cooldown Constants

```zig
pub const EXHAUSTED_TTL_429_MS: u64 = 60 * 60 * 1000;  // 1 hour for rate-limit (429)
pub const EXHAUSTED_TTL_DEFAULT_MS: u64 = 60 * 60 * 1000; // 1 hour default
pub const MAX_CREDENTIALS_PER_PROVIDER: usize = 32;
```

#### 3.2.3 CredentialPool

```zig
pub const CredentialPool = struct {
    provider: []const u8,                // Owned, lowercase
    entries: std.ArrayListUnmanaged(*PooledCredential),  // Owned pointers
    strategy: PoolStrategy,
    current_index: ?usize,               // Index of current entry, null if none
    mutex: std.Thread.Mutex,            // Protects all mutable state

    /// Opaque struct for soft concurrent-lease tracking
    leases: std.HashMapUnmanaged(usize, u32, struct {
        pub fn hash(self: @This(), key: usize) u64 { return std.hash.int(key); }
        pub fn eql(self: @This(), a: usize, b: usize) bool { return a == b; }
    }, 80),  // entry index → lease count

    pub fn init(allocator: std.mem.Allocator, provider: []const u8, strategy: PoolStrategy) !CredentialPool { ... }
    pub fn deinit(self: *CredentialPool, allocator: std.mem.Allocator) void { ... }

    /// Select an available credential using the configured strategy.
    /// Clears exhausted entries whose cooldown has elapsed.
    /// Returns null if no credentials are available.
    pub fn select(self: *CredentialPool, allocator: std.mem.Allocator) ?*PooledCredential { ... }

    /// Mark current credential exhausted and rotate to next available.
    /// Returns the next available credential, or null if all exhausted.
    pub fn markExhaustedAndRotate(
        self: *CredentialPool,
        allocator: std.mem.Allocator,
        error_code: ?u16,
        error_reason: ?[]const u8,
        error_reset_at_ms: ?i64,
    ) ?*PooledCredential { ... }

    /// Peek at current/first available without state change.
    pub fn peek(self: *CredentialPool) ?*PooledCredential { ... }

    /// Acquire a soft lease on a credential for concurrent use.
    /// Returns the entry index (for release_lease).
    pub fn acquireLease(self: *CredentialPool, allocator: std.mem.Allocator) ?usize { ... }

    /// Release a previously acquired lease.
    pub fn releaseLease(self: *CredentialPool, allocator: std.mem.Allocator, entry_index: usize) void { ... }

    /// Add a new credential to the pool.
    pub fn addEntry(self: *CredentialPool, allocator: std.mem.Allocator, entry: PooledCredential) !void { ... }

    /// Reset all exhausted statuses to OK.
    pub fn resetStatuses(self: *CredentialPool) void { ... }

    /// Persist pool to JSON file.
    pub fn persist(self: *CredentialPool, allocator: std.mem.Allocator) !void { ... }

    /// Load pool from JSON file + environment seeding.
    pub fn load(allocator: std.mem.Allocator, provider: []const u8, config_entries: []const config_types.ProviderEntry) !CredentialPool { ... }
};
```

**Thread safety:** `std.Thread.Mutex` guards all mutable state. Every public method acquires the lock. This matches Hermes's `threading.Lock` pattern. Aizen uses async + thread pools, so the mutex must be held only briefly (no blocking I/O under lock).

**Strategy implementations:**

```zig
fn selectFillFirst(self: *CredentialPool, available: []usize) ?usize {
    return if (available.len > 0) available[0] else null;
}

fn selectRoundRobin(self: *CredentialPool, available: []usize) ?usize {
    // Rotate entries: move first to last priority, return the first available
    ...
}

fn selectLeastUsed(self: *CredentialPool, available: []usize) ?usize {
    var best: usize = available[0];
    var best_count: u32 = self.entries.items[available[0]].request_count;
    for (available[1..]) |idx| {
        if (self.entries.items[idx].request_count < best_count) {
            best = idx;
            best_count = self.entries.items[idx].request_count;
        }
    }
    self.entries.items[best].request_count += 1;
    return best;
}

fn selectRandom(self: *CredentialPool, available: []usize) ?usize {
    const i = std.crypto.random.intRangeAtMost(usize, 0, available.len - 1);
    return available[i];
}
```

#### 3.2.4 Exhaustion Logic

```zig
fn exhaustedUntil(entry: *const PooledCredential) ?i64 {
    if (entry.status != .exhausted) return null;
    // Prefer provider-supplied absolute timestamp
    if (entry.error_reset_at_ms) |reset_at| {
        if (reset_at > 0) return reset_at;
    }
    // Default TTL based on error code
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
```

#### 3.2.5 Persistence Format

State is persisted to `~/.aizen/credential_pool/<provider>.json`:

```json
{
  "provider": "openrouter",
  "strategy": "fill_first",
  "entries": [
    {
      "id": "a3f2c1",
      "label": "OPENROUTER_API_KEY",
      "auth_type": "api_key",
      "priority": 0,
      "source": "env:OPENROUTER_API_KEY",
      "access_token": "***",
      "base_url": null,
      "status": "ok",
      "status_at_ms": null,
      "error_code": null,
      "error_reset_at_ms": null,
      "request_count": 42
    }
  ]
}
```

Tokens are stored encrypted at rest using Aizen's existing `src/security/secrets.zig` AEAD encryption (already used for channel tokens). On disk, `access_token` is encrypted; in memory, it's plaintext.

#### 3.2.6 Seeding from Config & Environment

The `load()` method seeds the pool from:

1. **Config `providers[]`** — each `ProviderEntry` with an `api_key` becomes a `source: "config:<name>"` entry
2. **Environment variables** — the same env var resolution as `api_key.zig`'s `providerEnvCandidates()` produces `source: "env:<VAR>"` entries
3. **Persisted state** — loaded from JSON, merged (upsert by source)

This mirrors Hermes's `_seed_from_env()` but is simpler since Aizen doesn't have Hermes's OAuth device-code flows yet. OAuth extension points are reserved in `AuthType`.

```zig
fn seedFromConfig(
    allocator: std.mem.Allocator,
    pool: *CredentialPool,
    entries: []const config_types.ProviderEntry,
) !void {
    for (entries) |entry| {
        if (!provider_names.providerNamesMatch(entry.name, pool.provider)) continue;
        if (entry.api_key) |key| {
            if (key.len == 0) continue;
            const source = try std.fmt.allocPrint(allocator, "config:{s}", .{entry.name});
            const owned_key = try allocator.dupe(u8, key);
            const owned_base = if (entry.base_url) |url| try allocator.dupe(u8, url) else null;
            try pool.addEntry(allocator, .{
                .id = try generateShortId(allocator),
                .provider = try allocator.dupe(u8, pool.provider),
                .label = try allocator.dupe(u8, entry.name),
                .auth_type = .api_key,
                .priority = @intCast(pool.entries.items.len),
                .source = source,
                .access_token = owned_key,
                .base_url = owned_base,
            });
        }
    }
}

fn seedFromEnv(
    allocator: std.mem.Allocator,
    pool: *CredentialPool,
) !void {
    const candidates = api_key.providerEnvCandidates(pool.provider);
    for (candidates) |env_var| {
        if (env_var.len == 0) break;
        const value = std_compat.process.getEnvVarOwned(allocator, env_var) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => continue,
            else => return err,
        };
        defer allocator.free(value);
        const trimmed = std.mem.trim(u8, value, " \t\r\n");
        if (trimmed.len == 0) continue;
        const source = try std.fmt.allocPrint(allocator, "env:{s}", .{env_var});
        const owned_key = try allocator.dupe(u8, trimmed);
        try pool.addEntry(allocator, .{
            .id = try generateShortId(allocator),
            .provider = try allocator.dupe(u8, pool.provider),
            .label = try allocator.dupe(u8, env_var),
            .auth_type = .api_key,
            .priority = @intCast(pool.entries.items.len),
            .source = source,
            .access_token = owned_key,
        });
    }
    // Generic fallbacks
    for (&[_][]const u8{ "AIZEN_API_KEY", "API_KEY" }) |env_var| {
        // ... same pattern
    }
}
```

### 3.3 Rate Limit Tracker

#### 3.3.1 Data Structures

```zig
pub const RateLimitBucket = struct {
    limit: u64 = 0,
    remaining: u64 = 0,
    reset_seconds: f64 = 0.0,
    captured_at_ms: i64 = 0,  // epoch ms when this was captured

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
};
```

#### 3.3.2 Header Parsing

```zig
/// Parse x-ratelimit-* headers from an HTTP response into a RateLimitState.
/// Returns null if no rate-limit headers are present.
/// All string keys in `headers` must be lowercased before calling.
pub fn parseRateLimitHeaders(
    allocator: std.mem.Allocator,
    headers: anytype, // Duck-typed: headers.get("x-ratelimit-...") -> ?[]const u8
    provider: []const u8,
) ?RateLimitState {
    // Check if ANY x-ratelimit-* header exists
    // Parse the 12 standard headers into 4 buckets
    // Return populated RateLimitState
    ...
}
```

Since Aizen uses `std.http.Client` for HTTP, headers come as `std.http.Headers`. The parsing function will accept a generic approach:

```zig
pub fn parseRateLimitHeadersFromMap(
    allocator: std.mem.Allocator,
    headers: *const std.http.Headers,
    provider: []const u8,
) ?RateLimitState {
    const now_ms = std_compat.time.milliTimestamp();

    var state = RateLimitState{
        .captured_at_ms = now_ms,
        .provider = provider,
    };

    var has_any = false;

    // Helper to parse a bucket from headers
    inline fn bucket(resource: []const u8, suffix: []const u8) RateLimitBucket {
        // Build key like "x-ratelimit-limit-requests" or "x-ratelimit-limit-tokens-1h"
        // Look up in headers, parse values
        ...
    }

    state.requests_min = bucket("requests", "");
    state.requests_hour = bucket("requests", "-1h");
    state.tokens_min = bucket("tokens", "");
    state.tokens_hour = bucket("tokens", "-1h");

    if (!has_any) return null;
    return state;
}
```

#### 3.3.3 Per-Provider Rate Limit Registry

```zig
pub const ProviderRateLimitRegistry = struct {
    // HashMap: provider name → RateLimitState
    // Not thread-safe; callers must hold a lock if sharing across threads.
    states: std.HashMapUnmanaged([]const u8, RateLimitState, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),

    mutex: std.Thread.Mutex,

    pub fn init() ProviderRateLimitRegistry { ... }
    pub fn deinit(self: *ProviderRateLimitRegistry, allocator: std.mem.Allocator) void { ... }

    /// Update the rate-limit state for a provider from response headers.
    pub fn updateFromHeaders(
        self: *ProviderRateLimitRegistry,
        allocator: std.mem.Allocator,
        provider: []const u8,
        headers: *const std.http.Headers,
    ) void { ... }

    /// Get the current rate-limit state for a provider (copy, not reference).
    pub fn getState(self: *ProviderRateLimitRegistry, provider: []const u8) ?RateLimitState { ... }

    /// Check if a provider is likely rate-limited right now.
    /// Returns true if the most restrictive bucket is at ≥90% usage
    /// AND the reset window hasn't elapsed.
    pub fn isLikelyLimited(self: *ProviderRateLimitRegistry, provider: []const u8) bool { ... }
};
```

#### 3.3.4 Formatting (for `/status` command output)

```zig
pub fn formatRateLimitDisplay(
    allocator: std.mem.Allocator,
    state: RateLimitState,
) ![]const u8 {
    // Produces formatted multi-line display matching Hermes's format_rate_limit_display
    ...
}

pub fn formatRateLimitCompact(state: RateLimitState) RateLimitCompactResult {
    // Produces one-line summary like "RPM: 42/60 | TPH: 8.2K/100K"
    ...
}
```

### 3.4 Integration with ReliableProvider

The existing `ReliableProvider` already has:
- `api_keys: []const []const u8` — simple key list for round-robin
- `rotateKey()` — advances `key_index`
- Retry with exponential backoff
- Rate-limit detection (429 → rotate key)

**Enhancement plan — phased approach:**

#### Phase 1 (MVP): CredentialPool replaces simple key list

```zig
pub const ReliableProvider = struct {
    inner: Provider,
    extras: []const ProviderEntry,
    model_fallbacks: []const ModelFallbackEntry,
    provider_names: []const []const u8,
    max_retries: u32,
    base_backoff_ms: u64,
    // OLD: api_keys + key_index
    // NEW: credential pool reference (optional)
    pool: ?*CredentialPool,
    rate_limits: ?*ProviderRateLimitRegistry,
    ...
};
```

When `pool` is set, it supersedes `api_keys`:
- `selectKey()` calls `pool.select()` instead of `api_keys[key_index]`
- On 429 → `pool.markExhaustedAndRotate(429, ...)` instead of `rotateKey()`
- Rate-limit headers from responses → `rate_limits.updateFromHeaders()`
- Before each request, `rate_limits.isLikelyLimited(provider)` can skip preemptively

#### Phase 2: Pool-aware backoff

When `rate_limits.isLikelyLimited()` returns true, `ReliableProvider` should:
1. Check `remainingSecondsNow()` for the relevant bucket
2. If cooldown > 0, sleep until reset (with a cap, e.g. 30s) or rotate to next pool entry
3. This avoids hammering a rate-limited provider

### 3.5 Configuration

Add to `config_types.zig`:

```zig
/// Credential pool strategy per provider.
/// "fill_first" (default), "round_robin", "least_used", "random"
pub const CredentialPoolConfig = struct {
    strategy: []const u8 = "fill_first",
    /// Default cooldown in ms when a provider returns 429
    exhausted_ttl_ms: u64 = 3_600_000, // 1 hour
    /// Maximum credentials per provider pool
    max_entries: u32 = 32,
    /// Enable persistent storage of pool state to disk
    persist: bool = true,
};
```

Add to `Config` struct:

```zig
pub const Config = struct {
    // ... existing fields ...
    /// Per-provider credential pool strategies.
    /// Keys are provider names, values are strategy strings.
    credential_pool_strategies: ?std.json.Value = null,
    /// Default credential pool configuration.
    credential_pool: CredentialPoolConfig = .{},
    // ...
};
```

In config JSON (`~/.aizen/config.json`):

```json
{
  "credential_pool": {
    "strategy": "fill_first",
    "exhausted_ttl_ms": 3600000,
    "persist": true
  },
  "credential_pool_strategies": {
    "openrouter": "round_robin",
    "groq": "least_used"
  },
  "reliability": {
    "provider_retries": 2,
    "provider_backoff_ms": 500,
    "fallback_providers": ["anthropic"],
    "api_keys": ["sk-key1", "sk-key2"]
  }
}
```

### 3.6 Thread Safety & Async Considerations

Aizen uses `libxev`-based async I/O with thread pools. Key considerations:

1. **`CredentialPool.mutex`** — `std.Thread.Mutex` (OS mutex). Must be held only for brief operations (pointer swaps, counter increments). Never under blocking I/O.

2. **Rate-limit state updates** happen on the HTTP response path (async I/O thread). The registry's `std.Thread.Mutex` is held during hashmap insertion of parsed headers — a microseconds operation.

3. **Pool persistence** (`persist()`) writes JSON to disk. This must NOT happen under the pool mutex. Algorithm:
   ```zig
   // Under lock:
   var snapshot = try pool.snapshot(allocator);  // deep-copy entries
   pool.mutex.unlock();
   // Outside lock:
   try writePoolToFile(allocator, pool.provider, &snapshot);
   // Lock reacquired if needed
   ```

4. **Lease tracking** uses `HashMap(usize, u32)` with index keys (not string keys), making acquire/release O(1) under lock.

### 3.7 Memory Budget

Target: <5 MB peak RSS for the entire agent. Credential pool budget:

| Component | Estimated Size |
|-----------|----------------|
| 32 credentials × ~512 bytes each (strings + struct fields) | ~16 KB |
| Pool overhead (ArrayList, HashMap) | ~2 KB |
| Rate-limit registry (10 providers × state) | ~2 KB |
| JSON file I/O buffers (transient) | ~32 KB (arena-allocated, freed) |
| **Total** | **~50 KB** |

Well within budget. Arena allocation is recommended for the JSON persist/load cycle.

### 3.8 Testing Strategy

Tests follow the project's `std.testing.allocator` (leak-detecting GPA) convention:

```zig
test "credential pool: fill_first selects first available" {
    const allocator = std.testing.allocator;
    var pool = try CredentialPool.init(allocator, "openrouter", .fill_first);
    defer pool.deinit(allocator);
    try pool.addEntry(allocator, makeTestCred(allocator, "key1", 0));
    try pool.addEntry(allocator, makeTestCred(allocator, "key2", 1));

    const selected = pool.select(allocator).?;
    try std.testing.expectEqualStrings("key1", selected.access_token);
}

test "credential pool: exhausted entry is skipped until cooldown expires" {
    // Mark entry 0 as exhausted with a future reset_at
    // Verify select() returns entry 1
    // Advance time (mock) past reset_at
    // Verify select() returns entry 0 again
}

test "credential pool: round_robin rotates through entries" { ... }
test "credential pool: least_used distributes across entries" { ... }
test "credential pool: markExhaustedAndRotate cycles to next entry" { ... }
test "credential pool: all exhausted returns null" { ... }
test "credential pool: persist and load round-trips data" { ... }
test "credential pool: seeding from config entries" { ... }
test "credential pool: seeding from environment variables" { ... }

test "rate limit: parse x-ratelimit headers" { ... }
test "rate limit: remaining_seconds_now accounts for elapsed time" { ... }
test "rate limit: isLikelyLimited returns true at 90% usage" { ... }
test "rate limit: registry updates per-provider state" { ... }
```

### 3.9 Migration Path

**No breaking changes.** The design is additive:

1. **Phase 1:** `CredentialPool` is optional. `ReliableProvider` falls back to `api_keys` list when `pool` is null. Existing behavior preserved exactly.

2. **Phase 2:** Agent loop creates a `CredentialPool` per provider when config has multiple keys or explicit pool config. Single-key setups continue using the fast path.

3. **Phase 3:** Rate-limit registry is populated from HTTP response headers. It's used by `ReliableProvider` for smarter retry decisions but doesn't change external behavior.

```zig
// In agent.zig (or wherever ReliableProvider is constructed):
fn createProvider(
    allocator: std.mem.Allocator,
    config: *const Config,
    provider_name: []const u8,
) !Provider {
    // ... existing provider construction ...

    var pool: ?*CredentialPool = null;
    if (hasMultipleKeysOrPoolConfig(config, provider_name)) {
        pool = try allocator.create(CredentialPool);
        pool.?? = try CredentialPool.load(allocator, provider_name, config.providers);
    }

    var reliable = ReliableProvider.initWithProvider(provider, config.reliability.provider_retries, config.reliability.provider_backoff_ms);
    if (pool) |p| {
        reliable.pool = p;
    }
    return reliable.provider();
}
```

### 3.10 Differences from Hermes

| Aspect | Hermes (Python) | Aizen (Zig) |
|--------|-----------------|--------------|
| OAuth refresh | Full Anthropic/Codex/Nous OAuth device-code flows | Not in v1; `AuthType.oauth` enum reserved for future |
| Auth store sync | Reads/writes `~/.hermes/auth.json` for OAuth tokens | No auth store in v1; API keys only |
| JSON persistence | `write_credential_pool()` → `~/.hermes/auth_pool/<provider>.json` | `persist()` → `~/.aizen/credential_pool/<provider>.json` |
| Thread safety | `threading.Lock` | `std.Thread.Mutex` |
| Token storage | Plaintext in JSON | Encrypted at rest (AEAD via existing `security/secrets.zig`) |
| Seeding sources | env vars + auth store + custom provider config | env vars + config providers only (no OAuth yet) |
| Lease tracking | `Dict[str, int]` counting | `HashMapUnmanaged(usize, u32)` index-based |
| Rate limit headers | `parse_rate_limit_headers()` standalone function | `ProviderRateLimitRegistry` with per-provider state |
| Random strategy | `random.choice()` | `std.crypto.random.intRangeAtMost()` |
| Strategy config | `credential_pool_strategies` dict in config.yaml | `credential_pool_strategies` in config.json |

---

## 4. Implementation Checklist

- [ ] Create `src/providers/credential_pool.zig`
  - [ ] `PooledCredential` struct with `deinit()`
  - [ ] `CredentialPool` struct with `init`, `deinit`, `select`, `markExhaustedAndRotate`, `addEntry`, `resetStatuses`, `peek`, `acquireLease`, `releaseLease`
  - [ ] Strategy implementations: `fill_first`, `round_robin`, `least_used`, `random`
  - [ ] Exhaustion cooldown: `exhaustedUntil()`, `isAvailable()`
  - [ ] Persistence: `persist()` → encrypted JSON, `load()` → seed from config + env + file
  - [ ] Short ID generation (`std.crypto.random` → hex)
- [ ] Create `src/providers/rate_limit.zig`
  - [ ] `RateLimitBucket`, `RateLimitState`
  - [ ] `parseRateLimitHeadersFromMap()` from `std.http.Headers`
  - [ ] `ProviderRateLimitRegistry` with `updateFromHeaders()`, `getState()`, `isLikelyLimited()`
  - [ ] Formatting: `formatRateLimitDisplay()`, `formatRateLimitCompact()`
- [ ] Add `CredentialPoolConfig` to `config_types.zig`
- [ ] Add config parsing for pool strategies in `config_parse.zig`
- [ ] Enhance `ReliableProvider` in `reliable.zig`
  - [ ] Optional `pool: ?*CredentialPool` field
  - [ ] On 429: `pool.markExhaustedAndRotate()` instead of `rotateKey()`
  - [ ] On success: update rate-limit registry from response headers
  - [ ] Before request: check `rate_limits.isLikelyLimited()`
- [ ] Enhance `api_key.zig`
  - [ ] `resolveApiKeyFromPool()` that delegates to `CredentialPool.select()`
- [ ] Add re-exports in `root.zig`
- [ ] Full test suite with `std.testing.allocator`
- [ ] Update `reliable.zig` tests to cover pool-based key rotation

---

## 5. File Paths (New and Modified)

| File | Action |
|------|--------|
| `src/providers/credential_pool.zig` | **NEW** |
| `src/providers/rate_limit.zig` | **NEW** |
| `src/providers/root.zig` | **MODIFY** — add re-exports |
| `src/providers/api_key.zig` | **MODIFY** — add `resolveApiKeyFromPool()` |
| `src/providers/reliable.zig` | **MODIFY** — add pool + registry integration |
| `src/config_types.zig` | **MODIFY** — add `CredentialPoolConfig` |
| `src/config_parse.zig` | **MODIFY** — parse pool config |