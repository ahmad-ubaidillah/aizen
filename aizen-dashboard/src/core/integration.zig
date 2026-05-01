const std = @import("std");
const std_compat = @import("compat");
const paths_mod = @import("paths.zig");
const state_mod = @import("state.zig");

pub const AizenKanbanConfig = struct {
    name: []const u8,
    port: u16 = 7700,
    api_token: ?[]const u8 = null,
};

pub const AizenOrchestrateWorkflowConfig = struct {
    file_name: []const u8,
    pipeline_id: []const u8,
    claim_role: []const u8,
    success_trigger: []const u8,
};

pub const managed_workflow_file_name = "aizen-dashboard-tracker-workflow.json";
pub const legacy_workflow_file_name = "tracker-workflow.json";

pub const AizenOrchestrateTrackerConfig = struct {
    url: []const u8,
    api_token: ?[]const u8 = null,
    agent_id: []const u8 = "aizen-orchestrate",
    workflows_dir: []const u8 = "workflows",
    max_concurrent_tasks: u32 = 10,
    workflow: ?AizenOrchestrateWorkflowConfig = null,
};

pub const AizenOrchestrateConfig = struct {
    name: []const u8,
    port: u16 = 8080,
    api_token: ?[]const u8 = null,
    tracker: ?AizenOrchestrateTrackerConfig = null,
};

pub fn listAizenKanban(allocator: std.mem.Allocator, state: *state_mod.State, paths: paths_mod.Paths) ![]AizenKanbanConfig {
    const names = try state.instanceNames("aizen-kanban") orelse return allocator.alloc(AizenKanbanConfig, 0);
    var list: std.ArrayListUnmanaged(AizenKanbanConfig) = .empty;
    errdefer deinitAizenKanbanConfigs(allocator, list.items);
    defer list.deinit(allocator);

    for (names) |name| {
        if (try loadAizenKanbanConfig(allocator, paths, name)) |cfg| {
            var owned = cfg;
            errdefer deinitAizenKanbanConfig(allocator, &owned);
            try list.append(allocator, owned);
        }
    }

    return list.toOwnedSlice(allocator);
}

pub fn listAizenOrchestrates(allocator: std.mem.Allocator, state: *state_mod.State, paths: paths_mod.Paths) ![]AizenOrchestrateConfig {
    const names = try state.instanceNames("aizen-orchestrate") orelse return allocator.alloc(AizenOrchestrateConfig, 0);
    var list: std.ArrayListUnmanaged(AizenOrchestrateConfig) = .empty;
    errdefer deinitAizenOrchestrateConfigs(allocator, list.items);
    defer list.deinit(allocator);

    for (names) |name| {
        if (try loadAizenOrchestrateConfig(allocator, paths, name)) |cfg| {
            var owned = cfg;
            errdefer deinitAizenOrchestrateConfig(allocator, &owned);
            try list.append(allocator, owned);
        }
    }

    return list.toOwnedSlice(allocator);
}

pub fn loadAizenKanbanConfig(allocator: std.mem.Allocator, paths: paths_mod.Paths, name: []const u8) !?AizenKanbanConfig {
    const config_path = paths.instanceConfig(allocator, "aizen-kanban", name) catch return null;
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(AizenKanbanConfigFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    return .{
        .name = try allocator.dupe(u8, name),
        .port = parsed.value.port,
        .api_token = if (parsed.value.api_token) |token| try allocator.dupe(u8, token) else null,
    };
}

pub fn loadAizenOrchestrateConfig(allocator: std.mem.Allocator, paths: paths_mod.Paths, name: []const u8) !?AizenOrchestrateConfig {
    const config_path = paths.instanceConfig(allocator, "aizen-orchestrate", name) catch return null;
    defer allocator.free(config_path);

    const file = std_compat.fs.openFileAbsolute(config_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(AizenOrchestrateConfigFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    const config_dir = std.fs.path.dirname(config_path) orelse return null;

    return .{
        .name = try allocator.dupe(u8, name),
        .port = parsed.value.port,
        .api_token = if (parsed.value.api_token) |token| try allocator.dupe(u8, token) else null,
        .tracker = if (parsed.value.tracker) |tracker| blk: {
            const workflows_dir = try resolveRelativePath(allocator, config_dir, tracker.workflows_dir);
            const workflow = try loadPrimaryWorkflowConfig(allocator, workflows_dir);
            break :blk .{
                .url = try allocator.dupe(u8, tracker.url),
                .api_token = if (tracker.api_token) |token| try allocator.dupe(u8, token) else null,
                .agent_id = try allocator.dupe(u8, tracker.agent_id),
                .workflows_dir = workflows_dir,
                .max_concurrent_tasks = tracker.concurrency.max_concurrent_tasks,
                .workflow = workflow,
            };
        } else null,
    };
}

pub fn deinitAizenKanbanConfig(allocator: std.mem.Allocator, cfg: *AizenKanbanConfig) void {
    allocator.free(cfg.name);
    if (cfg.api_token) |token| allocator.free(token);
    cfg.* = undefined;
}

pub fn deinitAizenKanbanConfigs(allocator: std.mem.Allocator, configs: []AizenKanbanConfig) void {
    for (configs) |*cfg| deinitAizenKanbanConfig(allocator, cfg);
    allocator.free(configs);
}

pub fn deinitAizenOrchestrateConfig(allocator: std.mem.Allocator, cfg: *AizenOrchestrateConfig) void {
    allocator.free(cfg.name);
    if (cfg.api_token) |token| allocator.free(token);
    if (cfg.tracker) |*tracker| {
        allocator.free(tracker.url);
        if (tracker.api_token) |token| allocator.free(token);
        allocator.free(tracker.agent_id);
        allocator.free(tracker.workflows_dir);
        if (tracker.workflow) |*workflow| {
            allocator.free(workflow.file_name);
            allocator.free(workflow.pipeline_id);
            allocator.free(workflow.claim_role);
            allocator.free(workflow.success_trigger);
        }
    }
    cfg.* = undefined;
}

pub fn deinitAizenOrchestrateConfigs(allocator: std.mem.Allocator, configs: []AizenOrchestrateConfig) void {
    for (configs) |*cfg| deinitAizenOrchestrateConfig(allocator, cfg);
    allocator.free(configs);
}

pub fn matchAizenKanbanTarget(boiler_cfg: AizenOrchestrateConfig, tickets: []const AizenKanbanConfig) ?AizenKanbanConfig {
    const tracker = boiler_cfg.tracker orelse return null;
    const tracker_port = extractLocalPort(tracker.url) orelse return null;

    for (tickets) |ticket| {
        if (ticket.port == tracker_port) return ticket;
    }
    return null;
}

pub fn countLinkedBoilersForTickets(tickets_cfg: AizenKanbanConfig, boilers: []const AizenOrchestrateConfig) usize {
    var count: usize = 0;
    for (boilers) |boiler| {
        const target = matchAizenKanbanTarget(boiler, &.{tickets_cfg}) orelse continue;
        _ = target;
        count += 1;
    }
    return count;
}

pub fn extractLocalPort(url: []const u8) ?u16 {
    const uri = std.Uri.parse(url) catch return null;
    const host = uri.host orelse return null;
    const port = uri.port orelse return null;

    return switch (host) {
        .raw => |value| if (isLocalHost(value)) port else null,
        else => null,
    };
}

fn isLocalHost(host: []const u8) bool {
    return std.mem.eql(u8, host, "127.0.0.1") or
        std.mem.eql(u8, host, "localhost") or
        std.mem.eql(u8, host, "0.0.0.0") or
        std.mem.eql(u8, host, "::1");
}

fn loadPrimaryWorkflowConfig(allocator: std.mem.Allocator, workflows_dir: []const u8) !?AizenOrchestrateWorkflowConfig {
    var dir = std_compat.fs.openDirAbsolute(workflows_dir, .{ .iterate = true }) catch return null;
    defer dir.close();

    const managed_path = try std.fs.path.join(allocator, &.{ workflows_dir, managed_workflow_file_name });
    defer allocator.free(managed_path);
    if (std_compat.fs.openFileAbsolute(managed_path, .{})) |managed_file| {
        managed_file.close();
        return loadWorkflowConfigFromFile(allocator, workflows_dir, managed_workflow_file_name);
    } else |_| {}

    var best_name: ?[]const u8 = null;
    defer if (best_name) |value| allocator.free(value);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        if (best_name == null or std.mem.order(u8, entry.name, best_name.?) == .lt) {
            if (best_name) |value| allocator.free(value);
            best_name = try allocator.dupe(u8, entry.name);
        }
    }

    const file_name = best_name orelse return null;
    return loadWorkflowConfigFromFile(allocator, workflows_dir, file_name);
}

fn loadWorkflowConfigFromFile(allocator: std.mem.Allocator, workflows_dir: []const u8, file_name: []const u8) !?AizenOrchestrateWorkflowConfig {
    const workflow_path = try std.fs.path.join(allocator, &.{ workflows_dir, file_name });
    defer allocator.free(workflow_path);
    const file = std_compat.fs.openFileAbsolute(workflow_path, .{}) catch return null;
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);
    const parsed = std.json.parseFromSlice(WorkflowFile, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();

    return .{
        .file_name = try allocator.dupe(u8, file_name),
        .pipeline_id = try allocator.dupe(u8, parsed.value.pipeline_id),
        .claim_role = try allocator.dupe(u8, if (parsed.value.claim_roles.len > 0) parsed.value.claim_roles[0] else ""),
        .success_trigger = try allocator.dupe(u8, if (parsed.value.on_success) |cfg| cfg.transition_to else ""),
    };
}

fn resolveRelativePath(allocator: std.mem.Allocator, base_dir: []const u8, value: []const u8) ![]const u8 {
    if (value.len == 0 or std.fs.path.isAbsolute(value)) return allocator.dupe(u8, value);
    return std.fs.path.resolve(allocator, &.{ base_dir, value });
}

const AizenKanbanConfigFile = struct {
    port: u16 = 7700,
    api_token: ?[]const u8 = null,
};

const AizenOrchestrateConfigFile = struct {
    port: u16 = 8080,
    api_token: ?[]const u8 = null,
    tracker: ?struct {
        url: []const u8,
        api_token: ?[]const u8 = null,
        agent_id: []const u8 = "aizen-orchestrate",
        concurrency: struct {
            max_concurrent_tasks: u32 = 10,
        } = .{},
        workflows_dir: []const u8 = "workflows",
    } = null,
};

const WorkflowFile = struct {
    pipeline_id: []const u8,
    claim_roles: []const []const u8 = &.{},
    on_success: ?struct {
        transition_to: []const u8 = "",
    } = null,
};
