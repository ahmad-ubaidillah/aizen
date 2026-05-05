//! Model Metadata Smart Routing — route tasks to optimal model by type/cost/speed.
//!
//! Evaluates tasks against model capabilities and selects the best match:
//!   - Task type: code, reasoning, vision, creative, summarization
//!   - Cost priority: minimize token cost
//!   - Speed priority: minimize latency
//!   - Quality priority: maximize accuracy
//!
//! Usage:
//!   var router = ModelRouter.init(allocator, registry);
//!   const model = router.selectModel(.{ .task_type = .code, .priority = .quality });

const std = @import("std");
const log = std.log.scoped(.model_router);

pub const TaskType = enum {
    code,
    reasoning,
    vision,
    creative,
    summarization,
    chat,
    tool_use,
};

pub const Priority = enum {
    quality,   // Best output quality regardless of cost
    balanced,  // Balance quality and cost
    cost,      // Minimize cost
    speed,     // Minimize latency
};

pub const ModelCapability = struct {
    code: f64 = 0.0,
    reasoning: f64 = 0.0,
    vision: f64 = 0.0,
    creative: f64 = 0.0,
    summarization: f64 = 0.0,
    chat: f64 = 0.0,
    tool_use: f64 = 0.0,
};

pub const ModelMetadata = struct {
    id: []const u8,
    provider: []const u8,
    display_name: []const u8,
    capabilities: ModelCapability,
    /// Relative cost per 1K tokens (1.0 = baseline)
    cost_factor: f64 = 1.0,
    /// Relative latency factor (1.0 = baseline)
    latency_factor: f64 = 1.0,
    /// Context window size in tokens
    context_window: usize = 4096,
    /// Supports streaming?
    supports_streaming: bool = true,
    /// Supports vision / image input?
    supports_vision: bool = false,
    /// Supports tool use?
    supports_tools: bool = false,
    /// Is the model currently available/healthy?
    is_available: bool = true,

    pub fn scoreForTask(self: ModelMetadata, task: TaskType, priority: Priority) f64 {
        const capability = switch (task) {
            .code => self.capabilities.code,
            .reasoning => self.capabilities.reasoning,
            .vision => self.capabilities.vision,
            .creative => self.capabilities.creative,
            .summarization => self.capabilities.summarization,
            .chat => self.capabilities.chat,
            .tool_use => self.capabilities.tool_use,
        };

        if (capability == 0.0 or !self.is_available) return 0.0;

        const cost_score = 1.0 / @max(self.cost_factor, 0.1);
        const speed_score = 1.0 / @max(self.latency_factor, 0.1);

        return switch (priority) {
            .quality => capability * 0.9 + cost_score * 0.05 + speed_score * 0.05,
            .balanced => capability * 0.5 + cost_score * 0.25 + speed_score * 0.25,
            .cost => capability * 0.3 + cost_score * 0.6 + speed_score * 0.1,
            .speed => capability * 0.3 + cost_score * 0.1 + speed_score * 0.6,
        };
    }
};

pub const RoutingRequest = struct {
    task_type: TaskType,
    priority: Priority = .balanced,
    /// Minimum context window required
    min_context: usize = 0,
    /// Requires vision support?
    requires_vision: bool = false,
    /// Requires tool use support?
    requires_tools: bool = false,
    /// Preferred provider (optional)
    preferred_provider: ?[]const u8 = null,
};

pub const RoutingResult = struct {
    model: ModelMetadata,
    score: f64,
    reason: []const u8,
};

pub const ModelRegistry = struct {
    allocator: std.mem.Allocator,
    models: std.ArrayList(ModelMetadata),

    pub fn init(allocator: std.mem.Allocator) ModelRegistry {
        return .{
            .allocator = allocator,
            .models = std.ArrayList(ModelMetadata).empty,
        };
    }

    pub fn deinit(self: *ModelRegistry) void {
        self.models.deinit(self.allocator);
    }

    pub fn register(self: *ModelRegistry, model: ModelMetadata) !void {
        try self.models.append(self.allocator, model);
    }

    pub fn findById(self: *const ModelRegistry, id: []const u8) ?ModelMetadata {
        for (self.models.items) |model| {
            if (std.mem.eql(u8, model.id, id)) return model;
        }
        return null;
    }

    /// Register built-in model metadata for common providers.
    pub fn registerDefaults(self: *ModelRegistry) !void {
        // OpenAI models
        try self.register(.{
            .id = "gpt-4o",
            .provider = "openai",
            .display_name = "GPT-4o",
            .capabilities = .{ .code = 0.95, .reasoning = 0.95, .vision = 0.95, .creative = 0.85, .summarization = 0.95, .chat = 0.95, .tool_use = 0.95 },
            .cost_factor = 2.5,
            .latency_factor = 1.2,
            .context_window = 128000,
            .supports_vision = true,
            .supports_tools = true,
        });
        try self.register(.{
            .id = "gpt-4o-mini",
            .provider = "openai",
            .display_name = "GPT-4o Mini",
            .capabilities = .{ .code = 0.80, .reasoning = 0.80, .vision = 0.75, .creative = 0.75, .summarization = 0.85, .chat = 0.85, .tool_use = 0.85 },
            .cost_factor = 0.15,
            .latency_factor = 0.6,
            .context_window = 128000,
            .supports_vision = true,
            .supports_tools = true,
        });
        try self.register(.{
            .id = "o1",
            .provider = "openai",
            .display_name = "o1 (Reasoning)",
            .capabilities = .{ .code = 0.90, .reasoning = 0.98, .vision = 0.0, .creative = 0.70, .summarization = 0.90, .chat = 0.85, .tool_use = 0.80 },
            .cost_factor = 6.0,
            .latency_factor = 3.0,
            .context_window = 200000,
            .supports_tools = false,
        });

        // Anthropic models
        try self.register(.{
            .id = "claude-sonnet-4",
            .provider = "anthropic",
            .display_name = "Claude 4 Sonnet",
            .capabilities = .{ .code = 0.95, .reasoning = 0.95, .vision = 0.95, .creative = 0.90, .summarization = 0.95, .chat = 0.95, .tool_use = 0.95 },
            .cost_factor = 3.0,
            .latency_factor = 1.5,
            .context_window = 200000,
            .supports_vision = true,
            .supports_tools = true,
        });
        try self.register(.{
            .id = "claude-haiku-4",
            .provider = "anthropic",
            .display_name = "Claude 4 Haiku",
            .capabilities = .{ .code = 0.75, .reasoning = 0.75, .vision = 0.70, .creative = 0.70, .summarization = 0.80, .chat = 0.80, .tool_use = 0.80 },
            .cost_factor = 0.25,
            .latency_factor = 0.5,
            .context_window = 200000,
            .supports_vision = true,
            .supports_tools = true,
        });

        // Google models
        try self.register(.{
            .id = "gemini-2.5-pro",
            .provider = "google",
            .display_name = "Gemini 2.5 Pro",
            .capabilities = .{ .code = 0.90, .reasoning = 0.92, .vision = 0.95, .creative = 0.85, .summarization = 0.90, .chat = 0.90, .tool_use = 0.85 },
            .cost_factor = 1.8,
            .latency_factor = 1.0,
            .context_window = 1000000,
            .supports_vision = true,
            .supports_tools = true,
        });

        // Local / cost-effective models
        try self.register(.{
            .id = "llama-3.1-70b",
            .provider = "local",
            .display_name = "Llama 3.1 70B",
            .capabilities = .{ .code = 0.80, .reasoning = 0.80, .vision = 0.0, .creative = 0.75, .summarization = 0.80, .chat = 0.85, .tool_use = 0.70 },
            .cost_factor = 0.05,
            .latency_factor = 0.8,
            .context_window = 128000,
            .supports_tools = true,
        });
    }
};

pub const ModelRouter = struct {
    allocator: std.mem.Allocator,
    registry: *const ModelRegistry,

    pub fn init(allocator: std.mem.Allocator, registry: *const ModelRegistry) ModelRouter {
        return .{ .allocator = allocator, .registry = registry };
    }

    pub fn deinit(self: *ModelRouter) void {
        _ = self;
    }

    /// Select the best model for a given task.
    pub fn selectModel(self: *ModelRouter, request: RoutingRequest) ?RoutingResult {
        var best_score: f64 = 0.0;
        var best_model: ?ModelMetadata = null;
        var best_reason: []const u8 = "none";

        for (self.registry.models.items) |model| {
            // Filter by requirements
            if (request.min_context > 0 and model.context_window < request.min_context) continue;
            if (request.requires_vision and !model.supports_vision) continue;
            if (request.requires_tools and !model.supports_tools) continue;
            if (request.preferred_provider) |provider| {
                if (!std.mem.eql(u8, model.provider, provider)) continue;
            }

            const score = model.scoreForTask(request.task_type, request.priority);
            if (score > best_score) {
                best_score = score;
                best_model = model;
                best_reason = switch (request.priority) {
                    .quality => "highest capability score",
                    .cost => "best capability per cost",
                    .speed => "best capability per latency",
                    .balanced => "best balanced score",
                };
            }
        }

        if (best_model) |m| {
            return RoutingResult{
                .model = m,
                .score = best_score,
                .reason = best_reason,
            };
        }

        return null;
    }

    /// Rank all models for a task, returning sorted results (highest score first).
    pub fn rankModels(self: *ModelRouter, request: RoutingRequest) ![]RoutingResult {
        var results = std.ArrayList(RoutingResult).empty;
        errdefer results.deinit(self.allocator);

        for (self.registry.models.items) |model| {
            if (request.min_context > 0 and model.context_window < request.min_context) continue;
            if (request.requires_vision and !model.supports_vision) continue;
            if (request.requires_tools and !model.supports_tools) continue;
            if (request.preferred_provider) |provider| {
                if (!std.mem.eql(u8, model.provider, provider)) continue;
            }

            const score = model.scoreForTask(request.task_type, request.priority);
            if (score > 0) {
                try results.append(self.allocator, .{
                    .model = model,
                    .score = score,
                    .reason = "ranked",
                });
            }
        }

        // Sort by score descending
        const SortCtx = struct {
            fn lessThan(_: void, a: RoutingResult, b: RoutingResult) bool {
                return a.score > b.score;
            }
        };
        std.mem.sort(RoutingResult, results.items, {}, SortCtx.lessThan);

        return results.toOwnedSlice(self.allocator);
    }
};

// ── Tests ───────────────────────────────────────────────────────

test "ModelRegistry register and find" {
    const allocator = std.testing.allocator;
    var registry = ModelRegistry.init(allocator);
    defer registry.deinit();

    try registry.register(.{
        .id = "test-model",
        .provider = "test",
        .display_name = "Test Model",
        .capabilities = .{ .code = 0.9, .chat = 0.8 },
    });

    const found = registry.findById("test-model");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("test-model", found.?.id);
}

test "ModelRouter selects best model for code task" {
    const allocator = std.testing.allocator;
    var registry = ModelRegistry.init(allocator);
    defer registry.deinit();
    try registry.registerDefaults();

    var router = ModelRouter.init(allocator, &registry);
    defer router.deinit();

    const result = router.selectModel(.{ .task_type = .code, .priority = .quality });
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.score > 0.0);
}

test "ModelRouter filters by vision requirement" {
    const allocator = std.testing.allocator;
    var registry = ModelRegistry.init(allocator);
    defer registry.deinit();
    try registry.registerDefaults();

    var router = ModelRouter.init(allocator, &registry);
    defer router.deinit();

    const result = router.selectModel(.{ .task_type = .vision, .requires_vision = true });
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.model.supports_vision);
}

test "ModelRouter filters by context window" {
    const allocator = std.testing.allocator;
    var registry = ModelRegistry.init(allocator);
    defer registry.deinit();
    try registry.registerDefaults();

    var router = ModelRouter.init(allocator, &registry);
    defer router.deinit();

    const result = router.selectModel(.{ .task_type = .chat, .min_context = 500000 });
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.model.context_window >= 500000);
}

test "ModelRouter cost priority prefers cheaper model" {
    const allocator = std.testing.allocator;
    var registry = ModelRegistry.init(allocator);
    defer registry.deinit();
    try registry.registerDefaults();

    var router = ModelRouter.init(allocator, &registry);
    defer router.deinit();

    const result = router.selectModel(.{ .task_type = .chat, .priority = .cost });
    try std.testing.expect(result != null);
    // Cost-priority should prefer cheaper models
    try std.testing.expect(result.?.model.cost_factor <= 1.0);
}

test "ModelRouter rankModels returns sorted results" {
    const allocator = std.testing.allocator;
    var registry = ModelRegistry.init(allocator);
    defer registry.deinit();
    try registry.registerDefaults();

    var router = ModelRouter.init(allocator, &registry);
    defer router.deinit();

    const ranked = try router.rankModels(.{ .task_type = .code });
    defer allocator.free(ranked);

    try std.testing.expect(ranked.len > 1);
    // Should be sorted descending
    try std.testing.expect(ranked[0].score >= ranked[1].score);
}
