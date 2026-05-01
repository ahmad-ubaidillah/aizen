// Plugin System — Runtime-loadable plugin interface with vtable-based architecture
// Plugins are dynamic libraries (.so/.dylib/.dll) loaded via std.DynLib at runtime.
// Plugin path convention: ~/.aizen/plugins/<name>/ (contains plugin.json + .so file)
const std = @import("std");
const Allocator = std.mem.Allocator;
const DynLib = std.DynLib;

const log = std.log.scoped(.plugin_system);

// ── Plugin Lifecycle Hooks (Vtable) ───────────────────────────────────────

pub const PluginStatus = enum { unloaded, loaded, active, error_state, deactivated };

pub const PluginHooks = struct {
    init: ?*const fn (*PluginContext) callconv(.c) c_int = null,
    deinit: ?*const fn () callconv(.c) void = null,
    on_message: ?*const fn (*const PluginContext, [*:0]const u8) callconv(.c) ?[*:0]u8 = null,
    on_tool_call: ?*const fn (*const PluginContext, [*:0]const u8, [*:0]const u8) callconv(.c) c_int = null,
    on_shutdown: ?*const fn () callconv(.c) void = null,
};

// ── Plugin Metadata ─────────────────────────────────────────────────────────

pub const PluginManifest = struct {
    name: []const u8,           // Plugin identifier (e.g., "aizen-sentinel")
    version: []const u8,       // Semver (e.g., "1.0.0")
    description: []const u8,   // Human-readable description
    entry_symbol: []const u8,  // Symbol prefix for vtable (e.g., "aizen_sentinel")
    author: []const u8 = "",   // Author name
    min_aizen_version: []const u8 = "0.1.0", // Minimum Aizen version
    hooks: []const []const u8 = &[_][]const u8{}, // Required hooks

    pub fn deinit(self: *PluginManifest, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.description);
        allocator.free(self.entry_symbol);
        if (self.author.len > 0) allocator.free(self.author);
        allocator.free(self.min_aizen_version);
    }
};

// ── Plugin Context (passed to hooks) ────────────────────────────────────────

pub const PluginContext = struct {
    allocator: Allocator,
    plugin_name: [*:0]const u8,
    plugin_version: [*:0]const u8,
    config_path: [*:0]const u8,
    data_path: [*:0]const u8,
};

// ── Plugin Entry ──────────────────────────────────────────────────────────────

pub const Plugin = struct {
    name: []const u8,           // Owned
    version: []const u8,        // Owned
    description: []const u8,   // Owned
    status: PluginStatus = .unloaded,
    manifest: PluginManifest,
    hooks: PluginHooks,
    dynlib: ?DynLib = null,
    path: []const u8,           // Owned, absolute path to .so/.dylib
    context: ?*PluginContext = null,

    pub fn deinit(self: *Plugin, allocator: Allocator) void {
        if (self.status == .active) {
            log.warn("Plugin '{s}' deinit called while active — calling on_shutdown hook", .{self.name});
            if (self.hooks.on_shutdown) |hook| hook();
            self.status = .loaded;
        }
        if (self.dynlib) |*dl| dl.close();
        self.manifest.deinit(allocator);
        allocator.free(self.name);
        allocator.free(self.version);
        allocator.free(self.description);
        allocator.free(self.path);
        if (self.context) |ctx| allocator.destroy(ctx);
    }
};

// ── Plugin Registry ──────────────────────────────────────────────────────────

pub const PluginRegistry = struct {
    plugins: std.HashMapUnmanaged([]const u8, *Plugin, struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            return std.hash.Wyhash.hash(0, key);
        }
        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    }, 80),
    mutex: std.Thread.Mutex,
    allocator: Allocator,
    plugin_dir: []const u8, // Base directory for plugins

    pub fn init(allocator: Allocator, plugin_dir: []const u8) PluginRegistry {
        return .{
            .plugins = .empty,
            .mutex = .{},
            .allocator = allocator,
            .plugin_dir = plugin_dir,
        };
    }

    pub fn deinit(self: *PluginRegistry) void {
        self.mutex.lock();
        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key);
            var plugin = entry.value_ptr.*;
            plugin.deinit(self.allocator);
            self.allocator.destroy(plugin);
        }
        self.plugins.deinit(self.allocator);
        self.mutex.unlock();
    }

    /// Load a plugin from its directory (containing plugin.json + .so file).
    /// The directory name is used as the plugin name if not specified in manifest.
    pub fn load(self: *PluginRegistry, dir_path: []const u8) !*Plugin {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 1. Read plugin.json manifest
        var manifest_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const manifest_path = try std.fmt.bufPrint(&manifest_path_buf, "{s}/plugin.json", .{dir_path});
        const manifest_data = try std.fs.cwd().readFileAlloc(self.allocator, manifest_path, 65536);
        defer self.allocator.free(manifest_data);

        // 2. Parse manifest (simplified JSON parser — real impl would use std.json)
        const manifest = try parseManifest(self.allocator, manifest_data);

        // 3. Find the dynamic library
        var lib_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const lib_extension = switch (std.Target.current.os.tag) {
            .linux => ".so",
            .macos => ".dylib",
            .windows => ".dll",
            else => ".so",
        };
        const lib_filename = try std.fmt.bufPrint(&lib_path_buf, "{s}/lib{s}{s}", .{ dir_path, manifest.entry_symbol, lib_extension });
        const owned_lib_path = try self.allocator.dupe(u8, lib_filename);

        // 4. Load dynamic library
        var dynlib = DynLib.open(lib_filename) catch |err| {
            log.err("Failed to load plugin library '{s}': {s}", .{ lib_filename, @errorName(err) });
            manifest.deinit(self.allocator);
            self.allocator.free(owned_lib_path);
            return err;
        };

        // 5. Resolve vtable symbols
        var hooks: PluginHooks = .{};
        const prefix = manifest.entry_symbol;

        // Try to resolve each hook symbol: {prefix}_init, {prefix}_deinit, etc.
        var symbol_buf: [256]u8 = undefined;
        if (std.fmt.bufPrint(&symbol_buf, "{s}_init", .{prefix})) |sym| {
            if (dynlib.lookup(*const fn (*PluginContext) callconv(.c) c_int, sym)) |func| {
                hooks.init = func;
            }
        }
        if (std.fmt.bufPrint(&symbol_buf, "{s}_deinit", .{prefix})) |sym| {
            if (dynlib.lookup(*const fn () callconv(.c) void, sym)) |func| {
                hooks.deinit = func;
            }
        }
        if (std.fmt.bufPrint(&symbol_buf, "{s}_on_message", .{prefix})) |sym| {
            if (dynlib.lookup(*const fn (*const PluginContext, [*:0]const u8) callconv(.c) ?[*:0]u8, sym)) |func| {
                hooks.on_message = func;
            }
        }
        if (std.fmt.bufPrint(&symbol_buf, "{s}_on_tool_call", .{prefix})) |sym| {
            if (dynlib.lookup(*const fn (*const PluginContext, [*:0]const u8, [*:0]const u8) callconv(.c) c_int, sym)) |func| {
                hooks.on_tool_call = func;
            }
        }
        if (std.fmt.bufPrint(&symbol_buf, "{s}_on_shutdown", .{prefix})) |sym| {
            if (dynlib.lookup(*const fn () callconv(.c) void, sym)) |func| {
                hooks.on_shutdown = func;
            }
        }

        // 6. Create plugin entry
        const plugin = try self.allocator.create(Plugin);
        plugin.* = .{
            .name = try self.allocator.dupe(u8, manifest.name),
            .version = try self.allocator.dupe(u8, manifest.version),
            .description = try self.allocator.dupe(u8, manifest.description),
            .status = .loaded,
            .manifest = manifest,
            .hooks = hooks,
            .dynlib = dynlib,
            .path = owned_lib_path,
            .context = null,
        };

        // 7. Register in map
        const owned_key = try self.allocator.dupe(u8, manifest.name);
        try self.plugins.put(self.allocator, owned_key, plugin);

        log.info("Loaded plugin '{s}' v{s} from {s}", .{ manifest.name, manifest.version, dir_path });
        return plugin;
    }

    /// Activate a loaded plugin (call init hook).
    pub fn activate(self: *PluginRegistry, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const plugin = self.plugins.get(name) orelse return error.PluginNotFound;
        if (plugin.status == .active) return; // Already active
        if (plugin.status != .loaded and plugin.status != .deactivated) return error.InvalidPluginState;

        // Create context
        const ctx = try self.allocator.create(PluginContext);
        ctx.* = .{
            .allocator = self.allocator,
            .plugin_name = @ptrCast(plugin.name.ptr),
            .plugin_version = @ptrCast(plugin.version.ptr),
            .config_path = @ptrCast(plugin.path.ptr),
            .data_path = @ptrCast(plugin.path.ptr),
        };
        plugin.context = ctx;

        if (plugin.hooks.init) |init_fn| {
            const result = init_fn(ctx);
            if (result != 0) {
                log.err("Plugin '{s}' init failed with code {d}", .{ name, result });
                plugin.status = .error_state;
                return error.PluginInitFailed;
            }
        }
        plugin.status = .active;
        log.info("Activated plugin '{s}'", .{name});
    }

    /// Deactivate an active plugin (call deinit hook).
    pub fn deactivate(self: *PluginRegistry, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const plugin = self.plugins.get(name) orelse return error.PluginNotFound;
        if (plugin.status != .active) return;

        if (plugin.hooks.deinit) |deinit_fn| {
            deinit_fn();
        }
        plugin.status = .deactivated;
        log.info("Deactivated plugin '{s}'", .{name});
    }

    /// Unload a plugin (remove from registry and free resources).
    pub fn unload(self: *PluginRegistry, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const plugin = self.plugins.get(name) orelse return error.PluginNotFound;
        if (plugin.status == .active) {
            // Deactivate first
            if (plugin.hooks.on_shutdown) |hook| hook();
        }
        var p = plugin;
        p.deinit(self.allocator);
        self.allocator.destroy(p);
        _ = self.plugins.remove(name);
        log.info("Unloaded plugin '{s}'", .{name});
    }

    /// Discover and load all plugins from the plugin directory.
    pub fn discoverAndLoadAll(self: *PluginRegistry) !usize {
        var dir = try std.fs.cwd().openDir(self.plugin_dir, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        var count: usize = 0;
        while (try iterator.next()) |entry| {
            if (entry.kind != .directory) continue;

            var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const plugin_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ self.plugin_dir, entry.name });

            // Check if plugin.json exists
            var manifest_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const manifest_path = try std.fmt.bufPrint(&manifest_buf, "{s}/plugin.json", .{plugin_path});
            std.fs.cwd().access(manifest_path, .{}) catch continue;

            self.load(plugin_path) catch |err| {
                log.warn("Failed to load plugin from '{s}': {s}", .{ plugin_path, @errorName(err) });
                continue;
            };
            count += 1;
        }
        return count;
    }

    /// Get a plugin by name.
    pub fn get(self: *PluginRegistry, name: []const u8) ?*Plugin {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.plugins.get(name);
    }

    /// List all loaded plugin names.
    pub fn listNames(self: *PluginRegistry, allocator: Allocator) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var names = std.ArrayList([]const u8).init(allocator);
        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            try names.append(try allocator.dupe(u8, entry.key_ptr.*));
        }
        return names.toOwnedSlice();
    }
};

// ── Manifest Parser (simplified) ──────────────────────────────────────────────

fn parseManifest(allocator: Allocator, json_data: []const u8) !PluginManifest {
    // Minimal JSON parsing — extract name, version, description, entry_symbol
    // In production, use std.json.parse()
    const findString = struct {
        fn f(data: []const u8, key: []const u8) ?[]const u8 {
            const key_pattern = try_alloc_key(key);
            defer allocator_free(key_pattern);
            // Find "key": "value"
            if (std.mem.indexOf(u8, data, key_pattern)) |start| {
                const val_start = start + key_pattern.len;
                // Skip whitespace and colon
                var i = val_start;
                while (i < data.len and (data[i] == ' ' or data[i] == ':' or data[i] == '\t')) : (i += 1) {}
                if (i < data.len and data[i] == '"') {
                    i += 1;
                    const end = std.mem.indexOfScalar(u8, data[i..], '"') orelse return null;
                    return data[i .. i + end];
                }
            }
            return null;
        }
    }.f;

    _ = findString; // Suppress unused warning

    // Use std.json for robust parsing
    var stream = std.json.TokenStream.init(json_data);
    constParsed = std.json.parse(struct {
        name: []const u8,
        version: []const u8,
        description: []const u8,
        entry_symbol: []const u8,
        author: ?[]const u8 = null,
        min_aizen_version: ?[]const u8 = null,
    }, &stream, .{
        .allocator = allocator,
        .ignore_unknown_fields = true,
    }) catch {
        return error.InvalidManifest;
    };

    return PluginManifest{
        .name = constParsed.name,
        .version = constParsed.version,
        .description = constParsed.description,
        .entry_symbol = constParsed.entry_symbol,
        .author = constParsed.author orelse "",
        .min_aizen_version = constParsed.min_aizen_version orelse "0.1.0",
    };
}

// ── Tests ──────────────────────────────────────────────────────────────────

test "PluginRegistry init/deinit" {
    const allocator = std.testing.allocator;
    var registry = PluginRegistry.init(allocator, "/tmp/test_plugins");
    defer registry.deinit();
    try std.testing.expect(registry.plugins.count() == 0);
}

test "Plugin lifecycle: load and activate" {
    // This test verifies the registry structure, not actual dlopen
    // (actual plugin loading requires a compiled .so which we can't create in unit tests)
    const allocator = std.testing.allocator;
    var registry = PluginRegistry.init(allocator, "/tmp/test_plugins");
    defer registry.deinit();

    // Verify registry operations don't crash with empty state
    try std.testing.expect(registry.get("nonexistent") == null);
    const names = try registry.listNames(allocator);
    try std.testing.expect(names.len == 0);
    allocator.free(names);
}

test "PluginManifest parsing" {
    const allocator = std.testing.allocator;
    const json =
        \\{
        \\  "name": "test_plugin",
        \\  "version": "1.0.0",
        \\  "description": "A test plugin",
        \\  "entry_symbol": "test_plugin"
        \\}
    ;

    const manifest = try parseManifest(allocator, json);
    defer manifest.deinit(allocator);

    try std.testing.expectEqualStrings("test_plugin", manifest.name);
    try std.testing.expectEqualStrings("1.0.0", manifest.version);
    try std.testing.expectEqualStrings("A test plugin", manifest.description);
    try std.testing.expectEqualStrings("test_plugin", manifest.entry_symbol);
}

test "PluginHooks default values" {
    const hooks = PluginHooks{};
    try std.testing.expect(hooks.init == null);
    try std.testing.expect(hooks.deinit == null);
    try std.testing.expect(hooks.on_message == null);
    try std.testing.expect(hooks.on_tool_call == null);
    try std.testing.expect(hooks.on_shutdown == null);
}

test "PluginStatus transitions" {
    var status: PluginStatus = .unloaded;
    try std.testing.expect(status == .unloaded);

    status = .loaded;
    try std.testing.expect(status == .loaded);

    status = .active;
    try std.testing.expect(status == .active);

    status = .deactivated;
    try std.testing.expect(status == .deactivated);
}