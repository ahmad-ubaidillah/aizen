//! Memory Quality Gate — MemReader implementation.
//!
//! Evaluates memory writes on three dimensions:
//!   1. Information value — uniqueness and usefulness vs existing memories
//!   2. Reference completeness — presence of citations, links, structured data
//!   3. Contradiction risk — conflict with existing stored memories
//!
//! Scores are 0.0–1.0 per dimension. Overall score is weighted average.
//! Memories below threshold can be rejected or flagged for review.

const std = @import("std");
const std_compat = @import("compat");
const root = @import("root.zig");
const MemoryEntry = root.MemoryEntry;
const MemoryCategory = root.MemoryCategory;
const freeEntries = root.freeEntries;
const log = std.log.scoped(.mem_quality);

pub const Error = error{LowQualityMemory};

/// Quality score for a single memory entry.
/// All scores are in range [0.0, 1.0].
pub const QualityScore = struct {
    /// How unique and useful is this information?
    information_value: f64 = 0.0,
    /// Does it have proper citations, links, structured references?
    reference_completeness: f64 = 0.0,
    /// Does it contradict existing memories? (1.0 = no contradiction)
    contradiction_risk: f64 = 1.0,
    /// Weighted overall score (higher = better quality)
    overall: f64 = 0.0,

    pub fn format(
        self: QualityScore,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Quality{{info={d:.2}, refs={d:.2}, contra={d:.2}, overall={d:.2}}}", .{
            self.information_value,
            self.reference_completeness,
            self.contradiction_risk,
            self.overall,
        });
    }
};

/// Configuration for the memory quality gate.
pub const QualityConfig = struct {
    /// Enable quality scoring on store().
    enabled: bool = false,
    /// Minimum overall score to accept a memory (0.0–1.0).
    /// Memories below this are rejected.
    min_overall_score: f64 = 0.3,
    /// Weight for information_value in overall score.
    weight_information: f64 = 0.5,
    /// Weight for reference_completeness in overall score.
    weight_references: f64 = 0.3,
    /// Weight for contradiction_risk in overall score.
    weight_contradiction: f64 = 0.2,
    /// When true, low-quality memories are stored with a flag instead of rejected.
    flag_instead_of_reject: bool = true,
    /// Maximum memories to check for contradiction (performance limit).
    max_contradiction_check: usize = 50,
    /// Minimum content length to score (very short memories get low info value).
    min_content_length: usize = 20,
};

/// Result of a quality check.
pub const QualityResult = struct {
    score: QualityScore,
    accepted: bool,
    reason: ?[]const u8 = null,

    pub fn deinit(self: *const QualityResult, allocator: std.mem.Allocator) void {
        if (self.reason) |r| allocator.free(r);
    }
};

/// MemReader — memory quality gate.
///
/// Usage:
///   var reader = MemReader.init(allocator, config);
///   defer reader.deinit();
///   const result = try reader.evaluate(content, existing_memories);
///   if (!result.accepted) return error.LowQualityMemory;
pub const MemReader = struct {
    allocator: std.mem.Allocator,
    config: QualityConfig,

    pub fn init(allocator: std.mem.Allocator, config: QualityConfig) MemReader {
        return .{ .allocator = allocator, .config = config };
    }

    pub fn deinit(self: *MemReader) void {
        _ = self;
    }

    /// Evaluate a memory content against existing memories.
    /// `existing` is a slice of MemoryEntry from recall() or list().
    /// Caller owns `existing` memory; this function does not free it.
    pub fn evaluate(
        self: *MemReader,
        content: []const u8,
        existing: []const MemoryEntry,
    ) !QualityResult {
        if (!self.config.enabled) {
            return QualityResult{
                .score = .{ .overall = 1.0 },
                .accepted = true,
            };
        }

        const info_score = try self.scoreInformationValue(content, existing);
        const ref_score = self.scoreReferenceCompleteness(content);
        const contra_score = try self.scoreContradictionRisk(content, existing);

        const overall = self.config.weight_information * info_score +
            self.config.weight_references * ref_score +
            self.config.weight_contradiction * contra_score;

        const accepted = overall >= self.config.min_overall_score;

        var reason: ?[]const u8 = null;
        if (!accepted) {
            reason = try std.fmt.allocPrint(self.allocator, "overall score {d:.2} below threshold {d:.2}", .{
                overall, self.config.min_overall_score,
            });
        }

        return QualityResult{
            .score = .{
                .information_value = info_score,
                .reference_completeness = ref_score,
                .contradiction_risk = contra_score,
                .overall = overall,
            },
            .accepted = accepted,
            .reason = reason,
        };
    }

    // ── Scoring heuristics ─────────────────────────────────────────

    /// Information value: uniqueness vs existing + content richness.
    fn scoreInformationValue(
        self: *MemReader,
        content: []const u8,
        existing: []const MemoryEntry,
    ) !f64 {
        // Too short = low value
        if (content.len < self.config.min_content_length) {
            return @as(f64, @floatFromInt(content.len)) / @as(f64, @floatFromInt(self.config.min_content_length));
        }

        // Check similarity to existing memories (lower similarity = higher value)
        var max_similarity: f64 = 0.0;
        const check_limit = @min(existing.len, self.config.max_contradiction_check);

        for (existing[0..check_limit]) |entry| {
            const sim = jaccardSimilarity(content, entry.content);
            if (sim > max_similarity) max_similarity = sim;
        }

        // Uniqueness = 1 - max_similarity
        const uniqueness = 1.0 - max_similarity;

        // Content richness: longer (up to a point) = more valuable
        const richness = richnessScore(content);

        // Combine: 60% uniqueness, 40% richness
        return 0.6 * uniqueness + 0.4 * richness;
    }

    /// Reference completeness: presence of URLs, citations, structured data.
    fn scoreReferenceCompleteness(self: *MemReader, content: []const u8) f64 {
        _ = self;
        var score: f64 = 0.0;

        // Has URL?
        if (std.mem.indexOf(u8, content, "://") != null or
            std.mem.indexOf(u8, content, "www.") != null)
        {
            score += 0.3;
        }

        // Has citation pattern [1], (Author, 2024), etc.
        if (std.mem.indexOf(u8, content, "[") != null and
            std.mem.indexOf(u8, content, "]") != null)
        {
            score += 0.2;
        }

        // Has markdown link [text](url)
        if (std.mem.indexOf(u8, content, "](") != null) {
            score += 0.2;
        }

        // Has structured data (JSON-like, key-value, tables)
        if (std.mem.indexOf(u8, content, "{") != null or
            std.mem.indexOf(u8, content, "|") != null or
            std.mem.indexOf(u8, content, ": ") != null)
        {
            score += 0.15;
        }

        // Has code block or technical content
        if (std.mem.indexOf(u8, content, "```") != null or
            std.mem.indexOf(u8, content, "`") != null)
        {
            score += 0.15;
        }

        return @min(score, 1.0);
    }

    /// Contradiction risk: 1.0 = no contradiction, 0.0 = high contradiction.
    fn scoreContradictionRisk(
        self: *MemReader,
        content: []const u8,
        existing: []const MemoryEntry,
    ) !f64 {
        if (existing.len == 0) return 1.0; // No existing = no contradiction

        const check_limit = @min(existing.len, self.config.max_contradiction_check);
        var contradiction_count: usize = 0;

        for (existing[0..check_limit]) |entry| {
            if (detectContradiction(content, entry.content)) {
                contradiction_count += 1;
            }
        }

        // Risk decreases as contradiction ratio increases
        const ratio = @as(f64, @floatFromInt(contradiction_count)) /
            @as(f64, @floatFromInt(check_limit));
        return 1.0 - ratio;
    }

    // ── Helpers ──────────────────────────────────────────────────

    /// Jaccard similarity on whitespace-tokenized, lowercased words.
    fn jaccardSimilarity(a: []const u8, b: []const u8) f64 {
        var buf_a: [1024]u8 = undefined;
        var buf_b: [1024]u8 = undefined;

        const a_lower = std.ascii.lowerString(&buf_a, a[0..@min(a.len, 1024)]);
        const b_lower = std.ascii.lowerString(&buf_b, b[0..@min(b.len, 1024)]);

        // Simple tokenization: split on whitespace
        var tokens_a: [128][]const u8 = undefined;
        var tokens_b: [128][]const u8 = undefined;
        var count_a: usize = 0;
        var count_b: usize = 0;

        var it_a = std.mem.tokenizeAny(u8, a_lower, " \t\n\r.,;:!?()[]{}\"'");
        while (it_a.next()) |tok| {
            if (count_a < 128) {
                tokens_a[count_a] = tok;
                count_a += 1;
            }
        }

        var it_b = std.mem.tokenizeAny(u8, b_lower, " \t\n\r.,;:!?()[]{}\"'");
        while (it_b.next()) |tok| {
            if (count_b < 128) {
                tokens_b[count_b] = tok;
                count_b += 1;
            }
        }

        if (count_a == 0 and count_b == 0) return 1.0;
        if (count_a == 0 or count_b == 0) return 0.0;

        // Count intersection
        var intersection: usize = 0;
        for (tokens_a[0..count_a]) |ta| {
            for (tokens_b[0..count_b]) |tb| {
                if (std.mem.eql(u8, ta, tb)) {
                    intersection += 1;
                    break;
                }
            }
        }

        const union_count = count_a + count_b - intersection;
        if (union_count == 0) return 1.0;

        return @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(union_count));
    }

    /// Detect contradiction between two memory contents.
    /// Simple heuristic: high similarity but with negation words.
    fn detectContradiction(a: []const u8, b: []const u8) bool {
        const sim = jaccardSimilarity(a, b);
        if (sim < 0.3) return false; // Too different to contradict

        // Check for negation patterns
        const negations = &[_][]const u8{
            "not ", "no ", "never ", "false", "incorrect",
            "wrong", "doesn't", "don't", "didn't", "isn't",
            "wasn't", "can't", "cannot", "failed", "error",
        };

        var a_has_neg = false;
        var b_has_neg = false;

        for (negations) |neg| {
            if (std.mem.indexOf(u8, a, neg) != null) a_has_neg = true;
            if (std.mem.indexOf(u8, b, neg) != null) b_has_neg = true;
        }

        // Contradiction: one has negation, other doesn't, and they're similar
        return (a_has_neg != b_has_neg) and sim > 0.5;
    }

    /// Content richness score based on length, structure, and diversity.
    fn richnessScore(content: []const u8) f64 {
        // Length score: ideal is 200-2000 chars
        const len = content.len;
        const len_score = if (len < 100)
            @as(f64, @floatFromInt(len)) / @as(f64, 100.0)
        else if (len > 5000)
            @as(f64, 0.7) // Too long might be noise
        else
            @as(f64, 1.0);

        // Sentence diversity (more sentences = richer)
        var sentence_count: usize = 0;
        for (content) |c| {
            if (c == '.' or c == '!' or c == '?') sentence_count += 1;
        }
        const sentence_score = @min(@as(f64, @floatFromInt(sentence_count)) / 5.0, 1.0);

        // Has structured content?
        var structure_score: f64 = 0.0;
        if (std.mem.indexOf(u8, content, "\n") != null) structure_score += 0.2;
        if (std.mem.indexOf(u8, content, "-") != null or std.mem.indexOf(u8, content, "*") != null) structure_score += 0.1;
        if (std.mem.indexOf(u8, content, ":") != null) structure_score += 0.1;

        return 0.5 * len_score + 0.3 * sentence_score + 0.2 * structure_score;
    }
};

// ── Tests ───────────────────────────────────────────────────────

test "MemReader basic scoring" {
    const allocator = std.testing.allocator;
    var reader = MemReader.init(allocator, .{ .enabled = true });
    defer reader.deinit();

    const existing = &[_]MemoryEntry{};
    var result = try reader.evaluate("This is a test memory with some content.", existing);
    defer result.deinit(allocator);

    try std.testing.expect(result.accepted);
    try std.testing.expect(result.score.overall > 0.0);
}

test "MemReader rejects very short content" {
    const allocator = std.testing.allocator;
    var reader = MemReader.init(allocator, .{
        .enabled = true,
        .min_overall_score = 0.5,
        .min_content_length = 50,
    });
    defer reader.deinit();

    const existing = &[_]MemoryEntry{};
    var result = try reader.evaluate("Hi", existing);
    defer result.deinit(allocator);

    try std.testing.expect(!result.accepted);
}

test "MemReader detects high similarity" {
    const allocator = std.testing.allocator;
    var reader = MemReader.init(allocator, .{ .enabled = true });
    defer reader.deinit();

    const existing = &[_]MemoryEntry{
        .{
            .id = "1",
            .key = "key1",
            .content = "The quick brown fox jumps over the lazy dog",
            .category = .core,
            .timestamp = "2026-01-01T00:00:00Z",
        },
    };

    var result = try reader.evaluate("The quick brown fox jumps over the lazy dog exactly the same", existing);
    defer result.deinit(allocator);

    // Should have low information value due to high similarity
    try std.testing.expect(result.score.information_value < 0.5);
}

test "MemReader reference completeness" {
    const allocator = std.testing.allocator;
    var reader = MemReader.init(allocator, .{ .enabled = true });
    defer reader.deinit();

    const existing = &[_]MemoryEntry{};
    var result = try reader.evaluate("See [docs](https://example.com) and citation [1] for details.", existing);
    defer result.deinit(allocator);

    try std.testing.expect(result.score.reference_completeness > 0.5);
}

test "MemReader contradiction detection" {
    const allocator = std.testing.allocator;
    var reader = MemReader.init(allocator, .{ .enabled = true });
    defer reader.deinit();

    const existing = &[_]MemoryEntry{
        .{
            .id = "1",
            .key = "key1",
            .content = "The server is running on port 8080",
            .category = .core,
            .timestamp = "2026-01-01T00:00:00Z",
        },
    };

    var result = try reader.evaluate("The server is not running on port 8080", existing);
    defer result.deinit(allocator);

    try std.testing.expect(result.score.contradiction_risk < 0.5);
}
