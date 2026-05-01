// Aizen TUI — Terminal UI Dashboard with Bubble Tea-style architecture
// Provides: chat panel, metrics sidebar, provider selector, control panels
// Design inspired by OpenCode TUI + Aigo's RPG-style layout
const std = @import("std");
const Allocator = std.mem.Allocator;
const quality_tracker = @import("../skill/quality_tracker.zig");
const rate_limit = @import("../providers/rate_limit.zig");
const credential_pool = @import("../providers/credential_pool.zig");

const log = std.log.scoped(.tui);

// ── Terminal Colors & Styles ───────────────────────────────────────────────

pub const Color = struct {
    pub const cyan = "\x1b[36m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const red = "\x1b[31m";
    pub const magenta = "\x1b[35m";
    pub const blue = "\x1b[34m";
    pub const white = "\x1b[37m";
    pub const gray = "\x1b[90m";
    pub const dim = "\x1b[2m";
    pub const bold = "\x1b[1m";
    pub const reset = "\x1b[0m";
    pub const clear_screen = "\x1b[2J\x1b[H";

    pub fn rgb(r: u8, g: u8, b: u8) []const u8 {
        // Returns static string; caller must provide buffer
        // Format: \x1b[38;2;R;G;Bm
        _ = r; _ = g; _ = b;
        return cyan; // Simplified; real impl would use dynamic buffer
    }
};

// ── TUI Model ───────────────────────────────────────────────────────────────

pub const TuiMode = enum { chat, metrics, providers, skills, settings };

pub const ChatMessage = struct {
    role: enum { user, assistant, system, tool },
    content: []const u8,    // Owned
    timestamp_ms: i64,
    tokens_used: u32 = 0,
    model: []const u8 = "", // Owned

    pub fn deinit(self: *ChatMessage, allocator: Allocator) void {
        allocator.free(self.content);
        if (self.model.len > 0) allocator.free(self.model);
    }
};

pub const ProviderStatus = struct {
    name: []const u8,        // Owned
    is_active: bool = false,
    key_count: u32 = 0,
    active_key_label: []const u8 = "", // Owned
    rate_limit_pct: f64 = 0.0,
    total_requests: u64 = 0,
    total_errors: u64 = 0,
};

pub const SkillStatus = struct {
    name: []const u8,        // Owned
    quality_score: f64 = 0.5,
    total_uses: u64 = 0,
    success_rate: f64 = 0.0,
    last_used: []const u8 = "", // Owned, relative time string
    needs_evolution: bool = false,
};

pub const TuiModel = struct {
    allocator: Allocator,
    mode: TuiMode = .chat,
    running: bool = true,

    // Chat panel
    messages: std.ArrayList(ChatMessage),
    input_buffer: std.ArrayList(u8),
    input_cursor: usize = 0,
    scroll_offset: usize = 0,

    // Sidebar data
    providers: std.ArrayList(ProviderStatus),
    skills: std.ArrayList(SkillStatus),

    // Metrics
    total_tokens: u64 = 0,
    total_cost: f64 = 0.0,
    session_duration_ms: i64 = 0,
    requests_count: u64 = 0,

    // Layout
    term_width: usize = 80,
    term_height: usize = 24,
    sidebar_width: usize = 30,

    // Spinner
    spinner_frames: []const []const u8 = &[_][]const u8{ "⚔", "⛨", "▲", "z", "◆" },
    spinner_index: usize = 0,
    is_processing: bool = false,

    // Command buffer
    command_history: std.ArrayList([]const u8),

    pub fn init(allocator: Allocator) !TuiModel {
        return .{
            .allocator = allocator,
            .messages = std.ArrayList(ChatMessage).init(allocator),
            .input_buffer = std.ArrayList(u8).init(allocator),
            .providers = std.ArrayList(ProviderStatus).init(allocator),
            .skills = std.ArrayList(SkillStatus).init(allocator),
            .command_history = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *TuiModel) void {
        for (self.messages.items) |*m| m.deinit(self.allocator);
        self.messages.deinit();
        self.input_buffer.deinit();
        for (self.providers.items) |*p| {
            self.allocator.free(p.name);
            if (p.active_key_label.len > 0) self.allocator.free(p.active_key_label);
        }
        self.providers.deinit();
        for (self.skills.items) |*s| {
            self.allocator.free(s.name);
            if (s.last_used.len > 0) self.allocator.free(s.last_used);
        }
        self.skills.deinit();
        for (self.command_history.items) |cmd| self.allocator.free(cmd);
        self.command_history.deinit();
    }

    // ── Rendering ──────────────────────────────────────────────────────

    pub fn render(self: *TuiModel, writer: anytype) !void {
        // Clear screen and move to top
        try writer.writeAll(Color.clear_screen);
        try writer.writeAll(Color.reset);

        // Header bar
        try self.renderHeader(writer);

        // Main content area (split: chat + sidebar)
        try self.renderChatPanel(writer);
        try self.renderSidebar(writer);

        // Input bar at bottom
        try self.renderInputBar(writer);
    }

    fn renderHeader(self: *TuiModel, writer: anytype) !void {
        try writer.writeAll(Color.cyan);
        try writer.writeAll(Color.bold);
        try writer.writeAll(" ⚔ Aizen Agent ");
        try writer.writeAll(Color.reset);

        // Mode tabs
        const modes = [_]struct { mode: TuiMode, label: []const u8 }{
            .{ .mode = .chat, .label = "Chat" },
            .{ .mode = .metrics, .label = "Metrics" },
            .{ .mode = .providers, .label = "Providers" },
            .{ .mode = .skills, .label = "Skills" },
            .{ .mode = .settings, .label = "Settings" },
        };
        for (modes) |m| {
            if (m.mode == self.mode) {
                try writer.writeAll(Color.cyan);
                try writer.writeAll(" [");
                try writer.writeAll(m.label);
                try writer.writeAll("] ");
                try writer.writeAll(Color.reset);
            } else {
                try writer.writeAll(Color.dim);
                try writer.writeAll("  ");
                try writer.writeAll(m.label);
                try writer.writeAll("  ");
                try writer.writeAll(Color.reset);
            }
        }

        // Processing spinner
        if (self.is_processing) {
            try writer.writeAll(" ");
            try writer.writeAll(Color.cyan);
            try writer.writeAll(self.spinner_frames[self.spinner_index % self.spinner_frames.len]);
            try writer.writeAll(Color.reset);
        }

        // Fill rest with dashes
        var remaining: usize = self.term_width - 60; // Approximate header length
        while (remaining > 0) : (remaining -= 1) {
            try writer.writeAll("─");
        }
        try writer.writeAll("\n");
    }

    fn renderChatPanel(self: *TuiModel, writer: anytype) !void {
        const chat_height = self.term_height - 4; // minus header + input + borders
        const visible_start = if (self.messages.items.len > chat_height)
            self.messages.items.len - chat_height + self.scroll_offset
        else
            0;

        var i: usize = visible_start;
        var line: usize = 0;
        while (i < self.messages.items.len and line < chat_height) : ({
            i += 1;
            line += 1;
        }) {
            const msg = self.messages.items[i];
            const role_color = switch (msg.role) {
                .user => Color.green,
                .assistant => Color.cyan,
                .system => Color.yellow,
                .tool => Color.magenta,
            };
            const role_label = switch (msg.role) {
                .user => "You",
                .assistant => "Aizen",
                .system => "System",
                .tool => "Tool",
            };

            try writer.writeAll(role_color);
            try std.fmt.format(writer, "{s:>6}", .{role_label});
            try writer.writeAll(Color.reset);
            try writer.writeAll(" │ ");

            // Truncate content to fit
            const max_len = self.term_width - self.sidebar_width - 12;
            if (msg.content.len > max_len) {
                try writer.writeAll(msg.content[0..max_len]);
                try writer.writeAll("…");
            } else {
                try writer.writeAll(msg.content);
            }
            try writer.writeAll("\n");
        }

        // Fill remaining lines
        while (line < chat_height) : (line += 1) {
            try writer.writeAll("\n");
        }
    }

    fn renderSidebar(self: *TuiModel, writer: anytype) !void {
        // Move cursor to right side (simplified — real impl uses alternate screen)
        try writer.writeAll(Color.dim);
        try writer.writeAll("┌─");
        try writer.writeAll(switch (self.mode) {
            .chat => "Context",
            .metrics => "Metrics",
            .providers => "Providers",
            .skills => "Skills",
            .settings => "Settings",
        });
        try writer.writeAll("─");

        switch (self.mode) {
            .chat, .metrics => {
                // Show token usage and cost
                try std.fmt.format(writer, "\n│ Tokens: {d}", .{self.total_tokens});
                try std.fmt.format(writer, "\n│ Cost: ${d:.4}", .{self.total_cost});
                try std.fmt.format(writer, "\n│ Requests: {d}", .{self.requests_count});

                // Show active provider
                for (self.providers.items) |p| {
                    if (p.is_active) {
                        try writer.writeAll("\n│\n│ ");
                        try writer.writeAll(Color.cyan);
                        try std.fmt.format(writer, "● {s}", .{p.name});
                        try writer.writeAll(Color.reset);
                        try std.fmt.format(writer, "\n│ Key: {s}", .{p.active_key_label});
                        if (p.rate_limit_pct > 0) {
                            try std.fmt.format(writer, "\n│ Rate: {d:.0}%", .{p.rate_limit_pct});
                        }
                        break;
                    }
                }
            },
            .providers => {
                for (self.providers.items) |p| {
                    try writer.writeAll("\n│ ");
                    if (p.is_active) try writer.writeAll(Color.green) else try writer.writeAll(Color.gray);
                    try std.fmt.format(writer, "{s} ({d} keys)", .{ p.name, p.key_count });
                    try writer.writeAll(Color.reset);
                }
            },
            .skills => {
                for (self.skills.items) |s| {
                    try writer.writeAll("\n│ ");
                    const quality_color = if (s.quality_score > 0.7) Color.green else if (s.quality_score > 0.4) Color.yellow else Color.red;
                    try writer.writeAll(quality_color);
                    try std.fmt.format(writer, "{s} {d:.0}%", .{ s.name, s.quality_score * 100.0 });
                    try writer.writeAll(Color.reset);
                    if (s.needs_evolution) {
                        try writer.writeAll(Color.yellow);
                        try writer.writeAll(" ⚠");
                        try writer.writeAll(Color.reset);
                    }
                }
            },
            .settings => {
                try writer.writeAll("\n│ Ctrl+P: Switch provider");
                try writer.writeAll("\n│ Ctrl+S: Toggle sidebar");
                try writer.writeAll("\n│ Ctrl+C: Exit");
                try writer.writeAll("\n│ /help: Commands");
            },
        }
        try writer.writeAll(Color.reset);
        try writer.writeAll("\n└───────────\n");
    }

    fn renderInputBar(self: *TuiModel, writer: anytype) !void {
        try writer.writeAll(Color.cyan);
        try writer.writeAll(" ──▶ ");
        try writer.writeAll(Color.reset);
        if (self.input_buffer.items.len > 0) {
            try writer.writeAll(self.input_buffer.items);
        } else {
            try writer.writeAll(Color.dim);
            try writer.writeAll("Type your message or /help for commands...");
            try writer.writeAll(Color.reset);
        }
        try writer.writeAll("\n");
    }

    // ── Message Management ──────────────────────────────────────────────

    pub fn addMessage(self: *TuiModel, role: @typeInfo(@TypeOf(ChatMessage)).Struct.fields[0].type, content: []const u8, model: []const u8) !void {
        const owned_content = try self.allocator.dupe(u8, content);
        const owned_model = if (model.len > 0) try self.allocator.dupe(u8, model) else "";
        try self.messages.append(.{
            .role = role,
            .content = owned_content,
            .timestamp_ms = std.time.milliTimestamp(),
            .model = owned_model,
        });
    }

    pub fn addUserMessage(self: *TuiModel, content: []const u8) !void {
        try self.addMessage(.user, content, "");
    }

    pub fn addAssistantMessage(self: *TuiModel, content: []const u8, model: []const u8) !void {
        try self.addMessage(.assistant, content, model);
    }

    pub fn addSystemMessage(self: *TuiModel, content: []const u8) !void {
        try self.addMessage(.system, content, "");
    }

    // ── Metrics Updates ──────────────────────────────────────────────────

    pub fn updateProviderStatus(self: *TuiModel, name: []const u8, is_active: bool, key_count: u32, key_label: []const u8, rate_pct: f64) !void {
        for (self.providers.items) |*p| {
            if (std.mem.eql(u8, p.name, name)) {
                p.is_active = is_active;
                p.key_count = key_count;
                if (p.active_key_label.len > 0) self.allocator.free(p.active_key_label);
                p.active_key_label = try self.allocator.dupe(u8, key_label);
                p.rate_limit_pct = rate_pct;
                return;
            }
        }
        // New provider
        try self.providers.append(.{
            .name = try self.allocator.dupe(u8, name),
            .is_active = is_active,
            .key_count = key_count,
            .active_key_label = try self.allocator.dupe(u8, key_label),
            .rate_limit_pct = rate_pct,
        });
    }

    pub fn updateSkillStatus(self: *TuiModel, name: []const u8, score: f64, uses: u64, success_rate: f64, last_used: []const u8, needs_evo: bool) !void {
        for (self.skills.items) |*s| {
            if (std.mem.eql(u8, s.name, name)) {
                s.quality_score = score;
                s.total_uses = uses;
                s.success_rate = success_rate;
                if (s.last_used.len > 0) self.allocator.free(s.last_used);
                s.last_used = try self.allocator.dupe(u8, last_used);
                s.needs_evolution = needs_evo;
                return;
            }
        }
        try self.skills.append(.{
            .name = try self.allocator.dupe(u8, name),
            .quality_score = score,
            .total_uses = uses,
            .success_rate = success_rate,
            .last_used = try self.allocator.dupe(u8, last_used),
            .needs_evolution = needs_evo,
        });
    }

    pub fn incrementTokens(self: *TuiModel, tokens: u64) void {
        self.total_tokens += tokens;
        self.requests_count += 1;
    }

    pub fn tickSpinner(self: *TuiModel) void {
        self.spinner_index = (self.spinner_index + 1) % self.spinner_frames.len;
    }
};

// ── Slash Commands ──────────────────────────────────────────────────────────

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    handler: fn (*TuiModel, []const u8) anyerror!void,
};

pub const COMMANDS = [_]struct { name: []const u8, desc: []const u8 }{
    .{ .name = "/help", .desc = "Show available commands" },
    .{ .name = "/providers", .desc = "List available providers" },
    .{ .name = "/use <provider>", .desc = "Switch to a provider" },
    .{ .name = "/model <name>", .desc = "Switch model" },
    .{ .name = "/skills", .desc = "Show skill quality rankings" },
    .{ .name = "/metrics", .desc = "Show token usage and cost" },
    .{ .name = "/clear", .desc = "Clear chat history" },
    .{ .name = "/quit", .desc = "Exit Aizen" },
    .{ .name = "/q", .desc = "Exit Aizen (shortcut)" },
};

// ── Tests ──────────────────────────────────────────────────────────────────

test "TuiModel init/deinit" {
    const allocator = std.testing.allocator;
    var model = try TuiModel.init(allocator);
    defer model.deinit();
    try std.testing.expect(model.mode == .chat);
    try std.testing.expect(model.running == true);
}

test "TuiModel add messages" {
    const allocator = std.testing.allocator;
    var model = try TuiModel.init(allocator);
    defer model.deinit();

    try model.addUserMessage("Hello Aizen!");
    try std.testing.expect(model.messages.items.len == 1);
    try std.testing.expect(model.messages.items[0].role == .user);

    try model.addAssistantMessage("Hi! How can I help?", "minimax-m2.7");
    try std.testing.expect(model.messages.items.len == 2);
    try std.testing.expect(model.messages.items[1].role == .assistant);
}

test "TuiModel provider and skill status" {
    const allocator = std.testing.allocator;
    var model = try TuiModel.init(allocator);
    defer model.deinit();

    try model.updateProviderStatus("openrouter", true, 2, "primary-key", 35.5);
    try std.testing.expect(model.providers.items.len == 1);
    try std.testing.expect(model.providers.items[0].is_active);

    try model.updateSkillStatus("shell", 0.85, 120, 0.90, "2m ago", false);
    try std.testing.expect(model.skills.items.len == 1);
    try std.testing.expect(model.skills.items[0].quality_score == 0.85);
}

test "TuiModel token tracking" {
    const allocator = std.testing.allocator;
    var model = try TuiModel.init(allocator);
    defer model.deinit();

    model.incrementTokens(1500);
    model.incrementTokens(2000);
    try std.testing.expect(model.total_tokens == 3500);
    try std.testing.expect(model.requests_count == 2);
}

test "Spinner rotation" {
    const allocator = std.testing.allocator;
    var model = try TuiModel.init(allocator);
    defer model.deinit();

    try std.testing.expect(model.spinner_index == 0);
    model.tickSpinner();
    try std.testing.expect(model.spinner_index == 1);
    model.tickSpinner();
    model.tickSpinner();
    model.tickSpinner();
    model.tickSpinner();
    try std.testing.expect(model.spinner_index == 0); // Wraps around
}