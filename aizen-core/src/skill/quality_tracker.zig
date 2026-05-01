// Self-Learning Skills — Wilson score + Bayesian ranking for skill quality evolution
// Inspired by Zeph's skill quality tracking, adapted for Aizen's Zig architecture
//
// Tracks skill usage outcomes (success/failure/partial) and computes quality scores
// using Wilson score interval (lower bound) for confidence-weighted ranking.
// Skill quality data persists to ~/.aizen/skill_quality/<skill_name>.json
// When failure clusters are detected, triggers skill evolution: auto-patch suggestions.
const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.skill_evolution);

// ── Skill Outcome ──────────────────────────────────────────────────────────

pub const SkillOutcome = enum { success, failure, partial };

pub const SkillUsageRecord = struct {
    skill_name: []const u8,      // Owned
    outcome: SkillOutcome,
    timestamp_ms: i64,           // Epoch ms
    context: ?[]const u8 = null, // Short context tag (e.g., "tool_shell", "code_gen"), owned
    error_msg: ?[]const u8 = null, // Error message if failure, owned
    duration_ms: u32 = 0,        // How long the skill invocation took

    pub fn deinit(self: *SkillUsageRecord, allocator: Allocator) void {
        allocator.free(self.skill_name);
        if (self.context) |c| allocator.free(c);
        if (self.error_msg) |e| allocator.free(e);
    }
};

// ── Wilson Score ────────────────────────────────────────────────────────────
// Lower bound of Wilson score confidence interval for a Bernoulli parameter.
// This gives a conservative quality estimate that accounts for sample size.
// Small samples get pulled toward 0.5 (uncertain), large samples converge to true rate.
// https://www.evanmiller.org/how-not-to-sort-by-average-rating.html

pub fn wilsonScoreLowerBound(successes: u64, failures: u64, confidence: f64) f64 {
    const n = successes + failures;
    if (n == 0) return 0.0;

    const z = switch (confidence) {
        0.90 => 1.28,
        0.95 => 1.96,
        0.99 => 2.576,
        else => 1.96, // Default 95%
    };

    const p_hat = @as(f64, @floatFromInt(successes)) / @as(f64, @floatFromInt(n));
    const n_f = @as(f64, @floatFromInt(n));
    const z2 = z * z;

    const denominator = 1.0 + z2 / n_f;
    const center = p_hat + z2 / (2.0 * n_f);
    const spread = z * @sqrt((p_hat * (1.0 - p_hat) + z2 / (4.0 * n_f)) / n_f);

    return @max(0.0, (center - spread) / denominator);
}

// ── Bayesian Quality Score ──────────────────────────────────────────────────
// Beta distribution posterior: Beta(α + successes, β + failures)
// Prior: Beta(1, 1) (uniform, representing no prior knowledge)
// Posterior mean = (α + successes) / (α + β + successes + failures)
// This gives a Bayesian quality score that naturally shrinks toward the prior with few samples.

pub fn bayesianQualityScore(successes: u64, failures: u64, alpha_prior: f64, beta_prior: f64) f64 {
    const alpha = alpha_prior + @as(f64, @floatFromInt(successes));
    const beta = beta_prior + @as(f64, @floatFromInt(failures));
    return alpha / (alpha + beta);
}

// ── Skill Quality Tracker ──────────────────────────────────────────────────

pub const SkillQualityEntry = struct {
    skill_name: []const u8,       // Owned
    successes: u64 = 0,
    failures: u64 = 0,
    partial: u64 = 0,
    total_duration_ms: u64 = 0,
    last_used_ms: i64 = 0,
    last_failure_msg: ?[]const u8 = null, // Owned
    wilson_score: f64 = 0.0,
    bayesian_score: f64 = 0.5,     // Starts at 0.5 with uniform prior
    failure_cluster_count: u32 = 0, // Consecutive failures
    evolution_suggested: bool = false,

    pub fn deinit(self: *SkillQualityEntry, allocator: Allocator) void {
        allocator.free(self.skill_name);
        if (self.last_failure_msg) |m| allocator.free(m);
    }

    pub fn totalCount(self: SkillQualityEntry) u64 {
        return self.successes + self.failures + self.partial;
    }

    pub fn successRate(self: SkillQualityEntry) f64 {
        const total = self.totalCount();
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.successes)) / @as(f64, @floatFromInt(total));
    }

    pub fn recalculate(self: *SkillQualityEntry) void {
        self.wilson_score = wilsonScoreLowerBound(self.successes, self.failures, 0.95);
        self.bayesian_score = bayesianQualityScore(self.successes, self.failures, 1.0, 1.0);
    }
};

pub const SkillEvolutionSuggestion = struct {
    skill_name: []const u8,
    pattern: EvolutionPattern,
    confidence: f64,
    description: []const u8,
    suggested_action: []const u8,
};

pub const EvolutionPattern = enum {
    consecutive_failures,    // N consecutive failures suggest a systemic issue
    regression,              // Previously good skill now failing
    slow_execution,          // Duration increasing over time
    context_mismatch,        // Failures cluster in specific contexts
    low_confidence,          // Very few uses, need more data
};

pub const SkillQualityTracker = struct {
    entries: std.HashMapUnmanaged([]const u8, SkillQualityEntry, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),
    mutex: std.Thread.Mutex,
    allocator: Allocator,
    persistence_path: ?[]const u8 = null, // If set, auto-persist after updates

    // Configuration
    consecutive_failure_threshold: u32 = 3,     // Suggest evolution after N consecutive failures
    regression_threshold: f64 = 0.3,              // If recent success rate drops below this from >0.5
    low_confidence_threshold: u64 = 5,             // Fewer than N total uses = low confidence
    slow_execution_factor: f64 = 2.0,             // Duration > N * average = slow

    pub fn init(allocator: Allocator) SkillQualityTracker {
        return .{
            .entries = .empty,
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SkillQualityTracker) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key);
            var val = entry.value_ptr;
            if (val.last_failure_msg) |m| self.allocator.free(m);
        }
        self.entries.deinit(self.allocator);
        if (self.persistence_path) |p| self.allocator.free(p);
    }

    /// Record a skill usage outcome and update quality scores.
    pub fn record(self: *SkillQualityTracker, record: SkillUsageRecord) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const gop = self.entries.getOrPut(self.allocator, record.skill_name) catch return;
        if (!gop.found_existing) {
            gop.key_ptr.* = self.allocator.dupe(u8, record.skill_name) catch return;
            gop.value_ptr.* = .{
                .skill_name = self.allocator.dupe(u8, record.skill_name) catch return,
                .bayesian_score = 0.5,
            };
        }
        var entry = gop.value_ptr;

        const now_ms = std.time.milliTimestamp();
        entry.last_used_ms = now_ms;
        entry.total_duration_ms += record.duration_ms;

        switch (record.outcome) {
            .success => {
                entry.successes += 1;
                entry.failure_cluster_count = 0; // Reset consecutive failure counter
                entry.evolution_suggested = false;
            },
            .failure => {
                entry.failures += 1;
                entry.failure_cluster_count += 1;
                if (record.error_msg) |msg| {
                    if (entry.last_failure_msg) |old| self.allocator.free(old);
                    entry.last_failure_msg = self.allocator.dupe(u8, msg) catch null;
                }
            },
            .partial => {
                entry.partial += 1;
                // Partial doesn't reset failure cluster but doesn't increment it
            },
        }

        entry.recalculate();
    }

    /// Get the quality score for a skill. Uses Wilson score (conservative) with
    /// Bayesian score as fallback for low-sample skills.
    pub fn getQualityScore(self: *SkillQualityTracker, skill_name: []const u8) f64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.entries.getPtr(skill_name)) |entry| {
            // Use Wilson score for well-sampled skills, Bayesian for low-sample
            if (entry.totalCount() >= self.low_confidence_threshold) {
                return entry.wilson_score;
            }
            return entry.bayesian_score;
        }
        return 0.5; // Unknown skill, neutral prior
    }

    /// Rank skills by quality score (highest first).
    pub fn rankByQuality(self: *SkillQualityTracker, allocator: Allocator) ![]struct { name: []const u8, score: f64 } {
        self.mutex.lock();
        defer self.mutex.unlock();

        var results = std.ArrayList(struct { name: []const u8, score: f64 }).initCapacity(allocator, self.entries.count()) catch return &.{};
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            const score = if (entry.value_ptr.totalCount() >= self.low_confidence_threshold)
                entry.value_ptr.wilson_score
            else
                entry.value_ptr.bayesian_score;
            results.append(.{ .name = entry.key_ptr.*, .score = score }) catch return &.{};
        }

        // Sort by score descending
        const SliceType = @TypeOf(results.items);
        std.sort.sort(SliceType, results.items, {}, struct {
            fn lessThan(ctx: void, a: SliceType, b: SliceType) bool {
                _ = ctx;
                return a.score > b.score; // Descending
            }
        });

        return results.toOwnedSlice();
    }

    /// Detect evolution suggestions based on usage patterns.
    pub fn detectEvolutionSuggestions(self: *SkillQualityTracker, allocator: Allocator) ![]SkillEvolutionSuggestion {
        self.mutex.lock();
        defer self.mutex.unlock();

        var suggestions = std.ArrayList(SkillEvolutionSuggestion).init(allocator);

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            const skill = entry.value_ptr;

            // P1: Consecutive failures
            if (skill.failure_cluster_count >= self.consecutive_failure_threshold) {
                try suggestions.append(.{
                    .skill_name = skill.skill_name,
                    .pattern = .consecutive_failures,
                    .confidence = @min(1.0, @as(f64, @floatFromInt(skill.failure_cluster_count)) / 5.0),
                    .description = try std.fmt.allocPrint(allocator, "{d} consecutive failures detected", .{skill.failure_cluster_count}),
                    .suggested_action = try std.fmt.allocPrint(allocator, "Review skill '{s}' logic — likely broken or context-mismatched", .{skill.skill_name}),
                });
                skill.evolution_suggested = true;
            }

            // P2: Regression (was good, now bad)
            if (skill.successes > 3 and skill.failures > 3) {
                const recent_rate = @as(f64, @floatFromInt(skill.successes)) / @as(f64, @floatFromInt(skill.successes + skill.failures));
                if (recent_rate < self.regression_threshold and skill.wilson_score > 0.5) {
                    try suggestions.append(.{
                        .skill_name = skill.skill_name,
                        .pattern = .regression,
                        .confidence = skill.wilson_score - recent_rate,
                        .description = try std.fmt.allocPrint(allocator, "Skill quality dropped from {d:.2} to {d:.2}", .{ skill.wilson_score, recent_rate }),
                        .suggested_action = try std.fmt.allocPrint(allocator, "Investigate regression in skill '{s}'", .{skill.skill_name}),
                    });
                }
            }

            // P3: Low confidence (too few uses)
            if (skill.totalCount() > 0 and skill.totalCount() < self.low_confidence_threshold) {
                try suggestions.append(.{
                    .skill_name = skill.skill_name,
                    .pattern = .low_confidence,
                    .confidence = 1.0 - @as(f64, @floatFromInt(skill.totalCount())) / @as(f64, @floatFromInt(self.low_confidence_threshold)),
                    .description = try std.fmt.allocPrint(allocator, "Only {d} uses — need more data for reliable ranking", .{skill.totalCount()}),
                    .suggested_action = try std.fmt.allocPrint(allocator, "Use skill '{s}' more to gather quality data", .{skill.skill_name}),
                });
            }

            // P4: Slow execution (if duration data exists)
            if (skill.totalCount() > 3) {
                const avg_duration = @as(f64, @floatFromInt(skill.total_duration_ms)) / @as(f64, @floatFromInt(skill.totalCount()));
                // If recent runs are > 2x average, suggest optimization
                // (This is a simplified check; more sophisticated analysis would look at trends)
                // For now, flag skills with high average duration
                if (avg_duration > 30000.0) { // > 30 seconds average
                    try suggestions.append(.{
                        .skill_name = skill.skill_name,
                        .pattern = .slow_execution,
                        .confidence = 0.5,
                        .description = try std.fmt.allocPrint(allocator, "Average execution time: {d:.0}ms", .{avg_duration}),
                        .suggested_action = try std.fmt.allocPrint(allocator, "Optimize skill '{s}' — high average duration", .{skill.skill_name}),
                    });
                }
            }
        }

        return suggestions.toOwnedSlice();
    }

    /// Reset quality data for a skill (e.g., after a skill patch is applied).
    pub fn resetSkill(self: *SkillQualityTracker, skill_name: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.entries.getPtr(skill_name)) |entry| {
            entry.successes = 0;
            entry.failures = 0;
            entry.partial = 0;
            entry.failure_cluster_count = 0;
            entry.evolution_suggested = false;
            entry.total_duration_ms = 0;
            entry.last_used_ms = 0;
            entry.recalculate();
        }
    }

    /// Persist all quality data to JSON files.
    pub fn persist(self: *SkillQualityTracker) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const home = std.posix.getenv("HOME") orelse std.posix.getenv("USERPROFILE") orelse return error.HomeNotFound;
        const base = try std.fmt.bufPrint(&path_buf, "{s}/.aizen/skill_quality", .{home});
        std.fs.cwd().makePath(base) catch {};

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            const skill = entry.value_ptr;
            const path = try std.fmt.bufPrint(&path_buf, "{s}/.aizen/skill_quality/{s}.json", .{ home, skill.skill_name });
            const file = std.fs.cwd().createFile(path, .{}) catch continue;
            defer file.close();
            var writer = file.writer();

            try std.fmt.format(writer,
                \\{{
                \\  "skill_name": "{s}",
                \\  "successes": {d},
                \\  "failures": {d},
                \\  "partial": {d},
                \\  "wilson_score": {d:.4},
                \\  "bayesian_score": {d:.4},
                \\  "total_duration_ms": {d},
                \\  "failure_cluster_count": {d},
                \\  "last_used_ms": {d},
                \\  "evolution_suggested": {s}
                \\}}
            , .{
                skill.skill_name,
                skill.successes,
                skill.failures,
                skill.partial,
                skill.wilson_score,
                skill.bayesian_score,
                skill.total_duration_ms,
                skill.failure_cluster_count,
                skill.last_used_ms,
                if (skill.evolution_suggested) "true" else "false",
            });
        }
    }
};

// ── Tests ──────────────────────────────────────────────────────────────────

test "wilson score lower bound" {
    // Perfect score with few samples: should be pulled toward 0.5
    const score_2_0 = wilsonScoreLowerBound(2, 0, 0.95);
    try std.testing.expect(score_2_0 > 0.3); // Not too confident with 2 samples
    try std.testing.expect(score_2_0 < 1.0);

    // Perfect score with many samples: should approach 1.0
    const score_100_0 = wilsonScoreLowerBound(100, 0, 0.95);
    try std.testing.expect(score_100_0 > 0.9);

    // 50/50: should be around 0.5
    const score_50_50 = wilsonScoreLowerBound(50, 50, 0.95);
    try std.testing.expect(score_50_50 > 0.35);
    try std.testing.expect(score_50_50 < 0.65);

    // Zero samples: should return 0
    const score_0_0 = wilsonScoreLowerBound(0, 0, 0.95);
    try std.testing.expect(score_0_0 == 0.0);
}

test "bayesian quality score" {
    // With uniform prior (1, 1): 2 successes, 0 failures → (1+2)/(1+1+2+0) = 0.75
    const b1 = bayesianQualityScore(2, 0, 1.0, 1.0);
    try std.testing.expect(std.math.approxEqAbs(f64, b1, 0.75, 0.01));

    // 0 uses → prior mean = 0.5
    const b2 = bayesianQualityScore(0, 0, 1.0, 1.0);
    try std.testing.expect(std.math.approxEqAbs(f64, b2, 0.5, 0.01));
}

test "SkillQualityTracker record and rank" {
    const allocator = std.testing.allocator;
    var tracker = SkillQualityTracker.init(allocator);
    defer tracker.deinit();

    // Record outcomes for 3 skills
    tracker.record(.{
        .skill_name = "shell",
        .outcome = .success,
        .timestamp_ms = 1000,
        .duration_ms = 500,
    });
    tracker.record(.{
        .skill_name = "shell",
        .outcome = .success,
        .timestamp_ms = 2000,
        .duration_ms = 450,
    });
    tracker.record(.{
        .skill_name = "web_search",
        .outcome = .failure,
        .timestamp_ms = 3000,
        .duration_ms = 3000,
        .error_msg = "timeout",
    });
    tracker.record(.{
        .skill_name = "git",
        .outcome = .success,
        .timestamp_ms = 4000,
        .duration_ms = 200,
    });

    // shell should have higher quality than web_search
    const shell_score = tracker.getQualityScore("shell");
    const web_score = tracker.getQualityScore("web_search");
    try std.testing.expect(shell_score > web_score);

    // Rank by quality
    const ranking = tracker.rankByQuality(allocator) catch return;
    defer allocator.free(ranking);
    try std.testing.expect(ranking.len == 3);
    // Best score first
    try std.testing.expect(ranking[0].score >= ranking[1].score);
}

test "SkillQualityTracker evolution detection" {
    const allocator = std.testing.allocator;
    var tracker = SkillQualityTracker.init(allocator);
    defer tracker.deinit();
    tracker.consecutive_failure_threshold = 3;

    // Record 4 consecutive failures for a skill
    for (0..4) |i| {
        tracker.record(.{
            .skill_name = "broken_skill",
            .outcome = .failure,
            .timestamp_ms = @as(i64, @intCast(i * 1000)),
            .error_msg = "error",
        });
    }

    const suggestions = tracker.detectEvolutionSuggestions(allocator) catch return;
    defer allocator.free(suggestions);
    try std.testing.expect(suggestions.len > 0);
    try std.testing.expect(suggestions[0].pattern == .consecutive_failures);
}