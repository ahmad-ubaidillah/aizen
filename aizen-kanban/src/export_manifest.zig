const std = @import("std");
const std_compat = @import("compat.zig");

pub fn run() !void {
    const manifest =
        \\{
        \\  "schema_version": 1,
        \\  "name": "aizen-kanban",
        \\  "display_name": "AizenKanban",
        \\  "description": "Headless task and issue tracker for AI agents",
        \\  "icon": "tickets",
        \\  "repo": "aizen/aizen-kanban",
        \\  "platforms": {
        \\    "aarch64-macos": { "asset": "aizen-kanban-macos-aarch64", "binary": "aizen-kanban" },
        \\    "x86_64-macos": { "asset": "aizen-kanban-macos-x86_64", "binary": "aizen-kanban" },
        \\    "x86_64-linux": { "asset": "aizen-kanban-linux-x86_64", "binary": "aizen-kanban" },
        \\    "aarch64-linux": { "asset": "aizen-kanban-linux-aarch64", "binary": "aizen-kanban" },
        \\    "riscv64-linux": { "asset": "aizen-kanban-linux-riscv64", "binary": "aizen-kanban" },
        \\    "x86_64-windows": { "asset": "aizen-kanban-windows-x86_64.exe", "binary": "aizen-kanban.exe" },
        \\    "aarch64-windows": { "asset": "aizen-kanban-windows-aarch64.exe", "binary": "aizen-kanban.exe" }
        \\  },
        \\  "build_from_source": {
        \\    "zig_version": "0.16.0",
        \\    "command": "zig build -Doptimize=ReleaseSmall",
        \\    "output": "zig-out/bin/aizen-kanban"
        \\  },
        \\  "launch": { "command": "aizen-kanban", "args": [] },
        \\  "health": { "endpoint": "/health", "port_from_config": "port" },
        \\  "ports": [{ "name": "api", "config_key": "port", "default": 7700, "protocol": "http" }],
        \\  "wizard": { "steps": [
        \\    { "id": "port", "title": "API Port", "type": "number", "required": true, "options": [] },
        \\    { "id": "api_token", "title": "API Token", "description": "Optional bearer token for tracker API auth", "type": "secret", "required": false, "options": [] },
        \\    { "id": "db_path", "title": "Database Path", "type": "text", "required": true, "options": [] }
        \\  ] },
        \\  "depends_on": [],
        \\  "connects_to": []
        \\}
    ;
    const stdout = std_compat.fs.File.stdout();
    try stdout.writeAll(manifest);
    try stdout.writeAll("\n");
}
