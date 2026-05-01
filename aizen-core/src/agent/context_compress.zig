// Context Compression — Intelligent context compression beyond auto-compaction
// Uses LLM-based summarization with manual feedback loop and multi-strategy compression
//
// Strategies:
// 1. Auto-compaction: Hermes-style automatic context window management (existing)
// 2. LLM summarization: Use a small/fast model to compress conversation history
// 3. Incremental compression: Only compress older messages, keep recent ones intact
// 4. Semantic deduplication: Remove semantically similar messages
// 5. Feedback loop: Manual user feedback on compression quality
const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.ctx_compress);

// ── Compression Strategy ──────────────────────────────────────────────────

pub const CompressionStrategy = enum {
    auto_compact,      // Hermes-style: truncate oldest messages
    llm_summarize,     // LLM-based: ask model to summarize
    incremental,       // Keep last N messages intact, compress older ones
    semantic_dedup,     // Remove semantically similar messages
    hybrid,            // Combine incremental + LLM summarization
};

pub const CompressionConfig = struct {
    strategy: CompressionStrategy = .hybrid,
    max_context_tokens: usize = 128000,    // Max context window size
    target_compression_ratio: f64 = 0.3,   // Target: 30% of original
    keep_recent_messages: usize = 6,        // Always keep last N messages intact
    min_messages_to_compress: usize = 10,   // Don't compress below this
    llm_model: []const u8 = "minimax-m2.7", // Small fast model for compression
    llm_max_tokens: usize = 2048,           // Max tokens for LLM summary
    feedback_enabled: bool = true,          // Enable manual feedback loop
    preserve_system_prompt: bool = true,     // Always keep system prompt
    preserve_tool_outputs: bool = false,     // Compress tool outputs aggressively
};

pub const CompressionResult = struct {
    original_messages: usize,
    compressed_messages: usize,
    original_tokens: usize,
    compressed_tokens: usize,
    strategy_used: CompressionStrategy,
    summary: ?[]const u8 = null,    // Owned, LLM-generated summary
    compressed_content: []const u8, // Owned, the compressed context
    feedback_ratings: std.ArrayList(FeedbackRating),

    pub fn deinit(self: *CompressionResult, allocator: Allocator) void {
        if (self.summary) |s| allocator.free(s);
        allocator.free(self.compressed_content);
        for (self.feedback_ratings.items) |r| {
            allocator.free(r.feedback_text);
        }
        self.feedback_ratings.deinit();
    }

    pub fn compressionRatio(self: CompressionResult) f64 {
        if (self.original_tokens == 0) return 1.0;
        return @as(f64, @floatFromInt(self.compressed_tokens)) / @as(f64, @floatFromInt(self.original_tokens));
    }

    pub fn tokensSaved(self: CompressionResult) usize {
        return self.original_tokens -| self.compressed_tokens;
    }
};

pub const FeedbackRating = struct {
    rating: u8,           // 1-5 stars
    feedback_text: []const u8, // Owned
    timestamp_ms: i64,
    strategy: CompressionStrategy,
};

// ── Message Types ──────────────────────────────────────────────────────────

pub const CompressionMessage = struct {
    role: enum { system, user, assistant, tool },
    content: []const u8,  // Owned
    token_count: usize,
    timestamp_ms: i64,
    is_important: bool = false, // Marked by user/system as important to preserve

    pub fn deinit(self: *CompressionMessage, allocator: Allocator) void {
        allocator.free(self.content);
    }
};

// ── Context Compressor ────────────────────────────────────────────────────

pub const ContextCompressor = struct {
    allocator: Allocator,
    config: CompressionConfig,
    compression_history: std.ArrayList(CompressionResult),
    feedback_history: std.ArrayList(FeedbackRating),

    pub fn init(allocator: Allocator, config: CompressionConfig) ContextCompressor {
        return .{
            .allocator = allocator,
            .config = config,
            .compression_history = std.ArrayList(CompressionResult).init(allocator),
            .feedback_history = std.ArrayList(FeedbackRating).init(allocator),
        };
    }

    pub fn deinit(self: *ContextCompressor) void {
        for (self.compression_history.items) |*r| r.deinit(self.allocator);
        self.compression_history.deinit();
        for (self.feedback_history.items) |*r| self.allocator.free(r.feedback_text);
        self.feedback_history.deinit();
    }

    /// Compress a slice of messages using the configured strategy.
    pub fn compress(self: *ContextCompressor, messages: []CompressionMessage) !CompressionResult {
        if (messages.len < self.config.min_messages_to_compress) {
            // Not enough messages to compress — return as-is
            var total_tokens: usize = 0;
            var content = std.ArrayList(u8).init(self.allocator);
            for (messages) |msg| {
                total_tokens += msg.token_count;
                try content.appendSlice(msg.content);
                try content.append('\n');
            }
            return CompressionResult{
                .original_messages = messages.len,
                .compressed_messages = messages.len,
                .original_tokens = total_tokens,
                .compressed_tokens = total_tokens,
                .strategy_used = .auto_compact,
                .compressed_content = try content.toOwnedSlice(),
                .feedback_ratings = std.ArrayList(FeedbackRating).init(self.allocator),
            };
        }

        return switch (self.config.strategy) {
            .auto_compact => try self.autoCompact(messages),
            .llm_summarize => try self.llmSummarize(messages),
            .incremental => try self.incrementalCompress(messages),
            .semantic_dedup => try self.semanticDedup(messages),
            .hybrid => try self.hybridCompress(messages),
        };
    }

    /// Strategy 1: Auto-compaction — truncate oldest messages, keep recent ones.
    fn autoCompact(self: *ContextCompressor, messages: []CompressionMessage) !CompressionResult {
        var total_tokens: usize = 0;
        for (messages) |msg| total_tokens += msg.token_count;

        const keep = self.config.keep_recent_messages;
        var start_idx: usize = 0;

        // Always preserve system prompt
        if (self.config.preserve_system_prompt) {
            for (messages, 0..) |msg, i| {
                if (msg.role == .system) {
                    start_idx = @max(start_idx, i + 1); // Keep system prompt(s)
                    break;
                }
            }
        }

        // Keep last N messages
        const cutoff = if (messages.len > keep) messages.len - keep else 0;
        start_idx = @max(start_idx, cutoff);

        var content = std.ArrayList(u8).init(self.allocator);
        var kept_tokens: usize = 0;
        var kept_messages: usize = 0;

        // Add truncated notice
        if (start_idx > 0) {
            try std.fmt.format(content.writer(),
                \\[Context auto-compacted: {d} earlier messages removed, saving ~{d} tokens]
                \\
            , .{ start_idx, total_tokens - kept_tokens });
        }

        for (messages[start_idx..]) |msg| {
            kept_tokens += msg.token_count;
            kept_messages += 1;
            try content.appendSlice(msg.content);
            try content.append('\n');
        }

        const compressed_tokens = kept_tokens + 30; // Account for truncation notice
        return CompressionResult{
            .original_messages = messages.len,
            .compressed_messages = kept_messages,
            .original_tokens = total_tokens,
            .compressed_tokens = compressed_tokens,
            .strategy_used = .auto_compact,
            .compressed_content = try content.toOwnedSlice(),
            .feedback_ratings = std.ArrayList(FeedbackRating).init(self.allocator),
        };
    }

    /// Strategy 2: LLM summarization — use a small model to compress older messages.
    fn llmSummarize(self: *ContextCompressor, messages: []CompressionMessage) !CompressionResult {
        var total_tokens: usize = 0;
        for (messages) |msg| total_tokens += msg.token_count;

        const keep = self.config.keep_recent_messages;
        const cutoff = if (messages.len > keep) messages.len - keep else 0;

        if (cutoff == 0) {
            // Nothing to compress — return as-is
            return self.autoCompact(messages);
        }

        // Build summary prompt from older messages
        var old_content = std.ArrayList(u8).init(self.allocator);
        defer old_content.deinit();
        var old_tokens: usize = 0;

        for (messages[0..cutoff]) |msg| {
            try old_content.appendSlice(msg.content);
            try old_content.append('\n');
            old_tokens += msg.token_count;
        }

        // Generate LLM summary (placeholder — real impl would call LLM API)
        const summary = try self.generateSummary(old_content.items);
        errdefer self.allocator.free(summary);

        // Build compressed context
        var content = std.ArrayList(u8).init(self.allocator);
        try std.fmt.format(content.writer(),
            \\[Summary of {d} earlier messages (~{d} tokens):]
            \\{s}
            \\
        , .{ cutoff, old_tokens, summary });

        var kept_tokens: usize = 0;
        for (messages[cutoff..]) |msg| {
            try content.appendSlice(msg.content);
            try content.append('\n');
            kept_tokens += msg.token_count;
        }

        const compressed_tokens = kept_tokens + summary.len / 4 + 50; // Estimate
        return CompressionResult{
            .original_messages = messages.len,
            .compressed_messages = messages.len - cutoff + 1, // Summary replaces N messages
            .original_tokens = total_tokens,
            .compressed_tokens = compressed_tokens,
            .strategy_used = .llm_summarize,
            .summary = summary,
            .compressed_content = try content.toOwnedSlice(),
            .feedback_ratings = std.ArrayList(FeedbackRating).init(self.allocator),
        };
    }

    /// Strategy 3: Incremental — compress older messages, keep recent ones intact.
    fn incrementalCompress(self: *ContextCompressor, messages: []CompressionMessage) !CompressionResult {
        var total_tokens: usize = 0;
        for (messages) |msg| total_tokens += msg.token_count;

        const keep = self.config.keep_recent_messages;
        const cutoff = if (messages.len > keep) messages.len - keep else 0;

        var content = std.ArrayList(u8).init(self.allocator);
        var compressed_tokens: usize = 0;

        // Compress older messages with key-point extraction
        if (cutoff > 0) {
            try content.appendSlice("[Earlier context:\n");
            for (messages[0..cutoff]) |msg| {
                // Extract first line (key point) of each message
                const first_line_end = std.mem.indexOfScalar(u8, msg.content, '\n') orelse msg.content.len;
                const first_line = msg.content[0..@min(first_line_end, 200)]; // Max 200 chars
                try content.appendSlice("  • ");
                try content.appendSlice(first_line);
                try content.append('\n');
                compressed_tokens += 30; // Approximate token count per key point
            }
            try content.appendSlice("]\n\n");
        }

        // Keep recent messages intact
        for (messages[cutoff..]) |msg| {
            try content.appendSlice(msg.content);
            try content.append('\n');
            compressed_tokens += msg.token_count;
        }

        return CompressionResult{
            .original_messages = messages.len,
            .compressed_messages = if (cutoff > 0) messages.len - cutoff + 1 else messages.len,
            .original_tokens = total_tokens,
            .compressed_tokens = compressed_tokens,
            .strategy_used = .incremental,
            .compressed_content = try content.toOwnedSlice(),
            .feedback_ratings = std.ArrayList(FeedbackRating).init(self.allocator),
        };
    }

    /// Strategy 4: Semantic deduplication — remove semantically similar messages.
    fn semanticDedup(self: *ContextCompressor, messages: []CompressionMessage) !CompressionResult {
        var total_tokens: usize = 0;
        for (messages) |msg| total_tokens += msg.token_count;

        var seen_hashes = std.HashMapUnmanaged(u64, void, struct {
            pub fn hash(self: @This(), key: u64) u64 { return key; }
            pub fn eql(self: @This(), a: u64, b: u64) bool { return a == b; }
        }, 80).empty;
        defer seen_hashes.deinit(self.allocator);

        var content = std.ArrayList(u8).init(self.allocator);
        var kept_messages: usize = 0;
        var kept_tokens: usize = 0;
        var removed: usize = 0;

        for (messages) |msg| {
            // Hash the first 200 chars (content fingerprint)
            const fingerprint = msg.content[0..@min(msg.content.len, 200)];
            const hash = std.hash.Wyhash.hash(0, fingerprint);

            const gop = try seen_hashes.getOrPut(self.allocator, hash);
            if (gop.found_existing) {
                removed += 1;
                continue; // Skip duplicate
            }

            try content.appendSlice(msg.content);
            try content.append('\n');
            kept_messages += 1;
            kept_tokens += msg.token_count;
        }

        if (removed > 0) {
            // Prepend dedup notice
            var final_content = std.ArrayList(u8).init(self.allocator);
            try std.fmt.format(final_content.writer(),
                "[Removed {d} semantically similar messages]\n\n{s}",
                .{ removed, content.items });
            self.allocator.free(content.items);
            return CompressionResult{
                .original_messages = messages.len,
                .compressed_messages = kept_messages,
                .original_tokens = total_tokens,
                .compressed_tokens = kept_tokens + 30,
                .strategy_used = .semantic_dedup,
                .compressed_content = try final_content.toOwnedSlice(),
                .feedback_ratings = std.ArrayList(FeedbackRating).init(self.allocator),
            };
        }

        return CompressionResult{
            .original_messages = messages.len,
            .compressed_messages = kept_messages,
            .original_tokens = total_tokens,
            .compressed_tokens = kept_tokens,
            .strategy_used = .semantic_dedup,
            .compressed_content = try content.toOwnedSlice(),
            .feedback_ratings = std.ArrayList(FeedbackRating).init(self.allocator),
        };
    }

    /// Strategy 5: Hybrid — incremental compression + LLM summarization for older messages.
    fn hybridCompress(self: *ContextCompressor, messages: []CompressionMessage) !CompressionResult {
        // First pass: semantic dedup
        var deduped = try self.semanticDedup(messages);
        // Second pass: incremental compression of deduplicated result
        // (Simplified: just use incremental on the original messages)
        // In production, we'd re-parse the deduplicated content into messages first.
        _ = deduped;
        return self.incrementalCompress(messages);
    }

    /// Generate a summary of content using LLM (placeholder for real API call).
    fn generateSummary(self: *ContextCompressor, content: []const u8) ![]const u8 {
        // In production, this would call the LLM API with a compression prompt:
        // "Summarize the following conversation context concisely, preserving key decisions,
        //  facts, and action items. Keep it under {max_tokens} tokens."
        //
        // For now, use extractive summarization (key sentence extraction)

        var lines = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (lines.items) |l| self.allocator.free(l);
            lines.deinit();
        }

        var line_iter = std.mem.splitSequence(u8, content, "\n");
        while (line_iter.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len < 20) continue; // Skip short lines
            // Extract lines that look important (contain key patterns)
            if (std.mem.containsAtLeast(u8, trimmed, 1, "important") or
                std.mem.containsAtLeast(u8, trimmed, 1, "decision") or
                std.mem.containsAtLeast(u8, trimmed, 1, "result") or
                std.mem.containsAtLeast(u8, trimmed, 1, "error") or
                std.mem.containsAtLeast(u8, trimmed, 1, "success") or
                std.mem.containsAtLeast(u8, trimmed, 1, "TODO") or
                std.mem.containsAtLeast(u8, trimmed, 1, "note:") or
                std.mem.startsWith(u8, trimmed, "#") or
                std.mem.startsWith(u8, trimmed, "- ") or
                std.mem.startsWith(u8, trimmed, "* "))
            {
                try lines.append(try self.allocator.dupe(u8, trimmed));
            }
        }

        // Limit summary size
        const max_lines = @min(lines.items.len, 20);
        var result = std.ArrayList(u8).init(self.allocator);
        for (lines.items[0..max_lines]) |line| {
            try result.appendSlice(line);
            try result.append('\n');
        }

        // Always add a general summary line
        try std.fmt.format(result.writer(),
            "[Auto-summary: {d} lines from {d} chars of context]",
            .{ max_lines, content.len });

        return result.toOwnedSlice();
    }

    /// Record user feedback on a compression result.
    pub fn recordFeedback(self: *ContextCompressor, rating: u8, text: []const u8, strategy: CompressionStrategy) !void {
        try self.feedback_history.append(.{
            .rating = rating,
            .feedback_text = try self.allocator.dupe(u8, text),
            .timestamp_ms = std.time.milliTimestamp(),
            .strategy = strategy,
        });

        // Adjust strategy based on feedback
        if (self.config.feedback_enabled) {
            self.adjustStrategyFromFeedback();
        }
    }

    /// Auto-adjust compression strategy based on accumulated feedback.
    fn adjustStrategyFromFeedback(self: *ContextCompressor) void {
        if (self.feedback_history.items.len < 3) return;

        // Calculate average rating per strategy
        var strategy_ratings: [5]struct { count: usize, total: u32 } = .{
            .{ .count = 0, .total = 0 }, // auto_compact
            .{ .count = 0, .total = 0 }, // llm_summarize
            .{ .count = 0, .total = 0 }, // incremental
            .{ .count = 0, .total = 0 }, // semantic_dedup
            .{ .count = 0, .total = 0 }, // hybrid
        };

        for (self.feedback_history.items) |feedback| {
            const idx = @intFromEnum(feedback.strategy);
            strategy_ratings[idx].count += 1;
            strategy_ratings[idx].total += feedback.rating;
        }

        // Find strategy with highest average rating
        var best_strategy: CompressionStrategy = .hybrid;
        var best_avg: f64 = 0.0;
        for (strategy_ratings, 0..) |sr, i| {
            if (sr.count < 2) continue;
            const avg: f64 = @as(f64, @floatFromInt(sr.total)) / @as(f64, @floatFromInt(sr.count));
            if (avg > best_avg) {
                best_avg = avg;
                best_strategy = @enumFromInt(i);
            }
        }

        if (best_avg >= 3.5) {
            self.config.strategy = best_strategy;
            log.info("Adjusted compression strategy to {s} (avg rating: {d:.1})", .{
                @tagName(best_strategy), best_avg,
            });
        }
    }

    /// Get compression statistics.
    pub fn stats(self: ContextCompressor) CompressionStats {
        if (self.compression_history.items.len == 0) {
            return .{
                .total_compressions = 0,
                .total_tokens_saved = 0,
                .avg_compression_ratio = 1.0,
                .last_strategy = self.config.strategy,
                .feedback_count = self.feedback_history.items.len,
                .avg_rating = 0.0,
            };
        }

        var total_saved: usize = 0;
        var total_ratio: f64 = 0.0;
        var last_strategy: CompressionStrategy = .auto_compact;

        for (self.compression_history.items) |result| {
            total_saved += result.tokensSaved();
            total_ratio += result.compressionRatio();
            last_strategy = result.strategy_used;
        }

        var avg_rating: f64 = 0.0;
        if (self.feedback_history.items.len > 0) {
            var total_rating: u32 = 0;
            for (self.feedback_history.items) |f| total_rating += f.rating;
            avg_rating = @as(f64, @floatFromInt(total_rating)) / @as(f64, @floatFromInt(self.feedback_history.items.len));
        }

        return .{
            .total_compressions = self.compression_history.items.len,
            .total_tokens_saved = total_saved,
            .avg_compression_ratio = total_ratio / @as(f64, @floatFromInt(self.compression_history.items.len)),
            .last_strategy = last_strategy,
            .feedback_count = self.feedback_history.items.len,
            .avg_rating = avg_rating,
        };
    }
};

pub const CompressionStats = struct {
    total_compressions: usize,
    total_tokens_saved: usize,
    avg_compression_ratio: f64,
    last_strategy: CompressionStrategy,
    feedback_count: usize,
    avg_rating: f64,
};

// ── Tests ──────────────────────────────────────────────────────────────────

test "auto-compaction keeps recent messages" {
    const allocator = std.testing.allocator;
    var compressor = ContextCompressor.init(allocator, .{
        .keep_recent_messages = 3,
        .min_messages_to_compress = 5,
    });
    defer compressor.deinit();

    var messages = std.ArrayList(CompressionMessage).init(allocator);
    defer {
        for (messages.items) |*m| m.deinit(allocator);
        messages.deinit();
    }

    for (0..10) |i| {
        try messages.append(.{
            .role = if (i % 2 == 0) .user else .assistant,
            .content = try std.fmt.allocPrint(allocator, "Message {d} content here with some text", .{i}),
            .token_count = 20,
            .timestamp_ms = @as(i64, @intCast(i)) * 1000,
        });
    }

    var result = try compressor.compress(messages.items);
    defer result.deinit(allocator);

    try std.testing.expect(result.compressed_messages < result.original_messages);
    try std.logging.expect(result.compressed_tokens <= result.original_tokens);
}

test "incremental compression extracts key points" {
    const allocator = std.testing.allocator;
    var compressor = ContextCompressor.init(allocator, .{
        .strategy = .incremental,
        .keep_recent_messages = 2,
        .min_messages_to_compress = 3,
    });
    defer compressor.deinit();

    var messages = std.ArrayList(CompressionMessage).init(allocator);
    defer {
        for (messages.items) |*m| m.deinit(allocator);
        messages.deinit();
    }

    for (0..8) |i| {
        try messages.append(.{
            .role = if (i % 2 == 0) .user else .assistant,
            .content = try std.fmt.allocPrint(allocator, "Important decision #{d}: We decided to use Zig for the project", .{i}),
            .token_count = 25,
            .timestamp_ms = @as(i64, @intCast(i)) * 1000,
        });
    }

    var result = try compressor.compress(messages.items);
    defer result.deinit(allocator);

    try std.testing.expect(result.strategy_used == .incremental);
    try std.testing.expect(result.compressed_messages < result.original_messages);
}

test "feedback adjusts strategy" {
    const allocator = std.testing.allocator;
    var compressor = ContextCompressor.init(allocator, .{
        .feedback_enabled = true,
        .strategy = .auto_compact,
    });
    defer compressor.deinit();

    // Add feedback preferring incremental
    try compressor.recordFeedback(5, "Incremental is best", .incremental);
    try compressor.recordFeedback(4, "Good results", .incremental);
    try compressor.recordFeedback(2, "Auto-compact loses context", .auto_compact);

    compressor.adjustStrategyFromFeedback();
    try std.testing.expect(compressor.config.strategy == .incremental);
}

test "CompressionResult stats" {
    const result = CompressionResult{
        .original_messages = 100,
        .compressed_messages = 30,
        .original_tokens = 50000,
        .compressed_tokens = 15000,
        .strategy_used = .llm_summarize,
        .compressed_content = "compressed",
        .feedback_ratings = std.ArrayList(FeedbackRating).init(std.testing.allocator),
    };

    try std.testing.expect(std.math.approxEqAbs(f64, result.compressionRatio(), 0.3, 0.01));
    try std.testing.expect(result.tokensSaved() == 35000);
}