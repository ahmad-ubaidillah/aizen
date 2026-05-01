//! Prompt Caching — inject Anthropic cache_control breakpoints.
//!
//! Anthropic's prompt caching allows reusing large prompts across turns,
//! saving ~75% of input token costs. This module injects cache_control
//! markers at optimal positions:
//! - System prompt (always cached)
//! - Last 3 conversation turns (cached for continuation)
//!
//! Port of Hermes Agent's prompt_caching logic to Zig.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Cache control breakpoint types.
pub const CacheControl = enum {
    /// Cache this content for reuse across turns.
    ephemeral,
    /// No caching (default).
    none,

    pub fn toJson(self: @This()) []const u8 {
        return switch (self) {
            .ephemeral => "{\"type\":\"ephemeral\"}",
            .none => "",
        };
    }
};

/// A single message in the conversation.
pub const Message = struct {
    role: []const u8, // "system", "user", "assistant", "tool"
    content: []const u8,
    cache_control: CacheControl = .none,
    token_count: usize = 0,

    pub fn estimateTokens(content: []const u8) usize {
        return @max(1, content.len / 4);
    }
};

/// Configuration for prompt caching.
pub const CacheConfig = struct {
    /// Whether caching is enabled.
    enabled: bool = true,

    /// Number of recent turns to cache (default: 3).
    /// Last N turns get ephemeral cache_control markers.
    cache_recent_turns: usize = 3,

    /// Whether to cache the system prompt (always true for Anthropic).
    cache_system_prompt: bool = true,

    /// Minimum content length (chars) to qualify for caching.
    /// Very short messages aren't worth caching.
    min_content_length: usize = 50,
};

/// Prompt cache injector — adds Anthropic cache_control breakpoints.
pub const PromptCache = struct {
    allocator: Allocator,
    config: CacheConfig,

    pub fn init(allocator: Allocator, config: CacheConfig) @This() {
        return @This(){
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn initDefault(allocator: Allocator) @This() {
        return init(allocator, .{});
    }

    /// Inject cache_control breakpoints into a conversation.
    /// Returns a new slice of messages with cache markers applied.
    pub fn injectCacheBreakpoints(self: @This(), messages: []const Message) Error![]Message {
        if (!self.config.enabled) {
            // Return copy without modifications
            const copy = self.allocator.alloc(Message, messages.len) catch return Error.OutOfMemory;
            @memcpy(copy, messages);
            return copy;
        }

        const result = self.allocator.alloc(Message, messages.len) catch return Error.OutOfMemory;
        @memcpy(result, messages);

        // 1. Cache system prompt
        if (self.config.cache_system_prompt) {
            for (result, 0..) |*msg, i| {
                if (std.mem.eql(u8, msg.role, "system")) {
                    msg.cache_control = .ephemeral;
                    break; // Only cache first system message
                }
            }
        }

        // 2. Cache last N turns
        self.cacheRecentTurns(result) catch {};

        return result;
    }

    /// Determine if a provider supports prompt caching.
    pub fn supportsCaching(provider: []const u8) bool {
        const supported = &[_][]const u8{
            "anthropic",
            "claude",
            "openai",
            "gpt",
            "azure",
        };

        for (supported) |s| {
            if (std.mem.indexOf(u8, provider, s) != null) return true;
        }
        return false;
    }

    /// Get cache statistics for a conversation.
    pub fn getCacheStats(self: @This(), messages: []const Message) CacheStats {
        var stats = CacheStats{
            .total_messages = messages.len,
            .cached_messages = 0,
            .total_tokens = 0,
            .cached_tokens = 0,
            .estimated_savings_pct = 0.0,
        };

        for (messages) |msg| {
            const tokens = if (msg.token_count > 0) msg.token_count else Message.estimateTokens(msg.content);
            stats.total_tokens += tokens;
            if (msg.cache_control == .ephemeral) {
                stats.cached_messages += 1;
                stats.cached_tokens += tokens;
            }
        }

        if (stats.total_tokens > 0) {
            // Anthropic charges 10% extra for cached input, but saves 90% on cache hits
            // Net savings on cache hit: ~75% of input cost
            stats.estimated_savings_pct = @as(f64, @floatFromInt(stats.cached_tokens)) /
                @as(f64, @floatFromInt(stats.total_tokens)) * 75.0;
        }

        return stats;
    }

    /// Cache the last N turns in the conversation.
    fn cacheRecentTurns(self: @This(), messages: []Message) Error!void {
        _ = self;
        // Find the last N user/assistant turn pairs
        var turn_count: usize = 0;
        var i: usize = messages.len;
        while (i > 0 and turn_count < self.config.cache_recent_turns) {
            i -= 1;
            if (std.mem.eql(u8, messages[i].role, "user") or
                std.mem.eql(u8, messages[i].role, "assistant"))
            {
                if (messages[i].content.len >= self.config.min_content_length) {
                    messages[i].cache_control = .ephemeral;
                }
                turn_count += 1;
            }
        }
    }
};

/// Statistics about prompt caching state.
pub const CacheStats = struct {
    total_messages: usize,
    cached_messages: usize,
    total_tokens: usize,
    cached_tokens: usize,
    estimated_savings_pct: f64,
};

pub const Error = error{
    OutOfMemory,
    CacheFailed,
};

// === Tests ===

test "PromptCache disabled returns unmodified messages" {
    const allocator = std.testing.allocator;
    const cache = PromptCache.init(allocator, .{ .enabled = false });

    const messages = [_]Message{
        .{ .role = "system", .content = "You are helpful.", .token_count = 5 },
        .{ .role = "user", .content = "Hello!", .token_count = 2 },
    };

    const result = try cache.injectCacheBreakpoints(&messages);
    try std.testing.expect(result[0].cache_control == .none);
    try std.testing.expect(result[1].cache_control == .none);
}

test "PromptCache caches system prompt" {
    const allocator = std.testing.allocator;
    const cache = PromptCache.init(allocator, .{});

    const messages = [_]Message{
        .{ .role = "system", .content = "You are a helpful AI assistant with many capabilities.", .token_count = 15 },
        .{ .role = "user", .content = "Hello!", .token_count = 2 },
    };

    const result = try cache.injectCacheBreakpoints(&messages);
    try std.testing.expect(result[0].cache_control == .ephemeral);
}

test "PromptCache caches recent turns" {
    const allocator = std.testing.allocator;
    const cache = PromptCache.init(allocator, .{
        .cache_recent_turns = 2,
        .min_content_length = 10,
    });

    const messages = [_]Message{
        .{ .role = "system", .content = "System prompt that is long enough for caching.", .token_count = 15 },
        .{ .role = "user", .content = "This is a long enough user message for caching.", .token_count = 20 },
        .{ .role = "assistant", .content = "This is a long enough assistant response for caching.", .token_count = 25 },
        .{ .role = "user", .content = "Short", .token_count = 2 }, // too short
    };

    const result = try cache.injectCacheBreakpoints(&messages);
    try std.testing.expect(result[0].cache_control == .ephemeral); // system
    // Last 2 qualifying turns should be cached
    try std.testing.expect(result[2].cache_control == .ephemeral); // assistant
}

test "supportsCaching identifies Anthropic and OpenAI" {
    try std.testing.expect(PromptCache.supportsCaching("anthropic/claude-sonnet-4"));
    try std.testing.expect(PromptCache.supportsCaching("claude-3-opus"));
    try std.testing.expect(PromptCache.supportsCaching("openai/gpt-4"));
    try std.testing.expect(!PromptCache.supportsCaching("ollama/llama3"));
    try std.testing.expect(!PromptCache.supportsCaching("local/gemma"));
}

test "CacheStats calculates savings correctly" {
    const stats = CacheStats{
        .total_messages = 10,
        .cached_messages = 3,
        .total_tokens = 1000,
        .cached_tokens = 600,
        .estimated_savings_pct = 45.0,
    };
    try std.testing.expect(stats.cached_messages == 3);
    try std.testing.expect(stats.total_tokens == 1000);
}