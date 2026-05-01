const std = @import("std");
const std_compat = @import("compat.zig");

pub fn run() !void {
    const manifest =
        \\{
        \\  "schema_version": 1,
        \\  "name": "aizen-watch",
        \\  "display_name": "AizenWatch",
        \\  "description": "Headless observability, tracing, evals, and run intelligence for aizen",
        \\  "icon": "pulse",
        \\  "repo": "aizen/aizen-watch",
        \\  "platforms": {
        \\    "aarch64-macos": { "asset": "aizen-watch-macos-aarch64.bin", "binary": "aizen-watch" },
        \\    "x86_64-macos": { "asset": "aizen-watch-macos-x86_64.bin", "binary": "aizen-watch" },
        \\    "x86_64-linux": { "asset": "aizen-watch-linux-x86_64.bin", "binary": "aizen-watch" },
        \\    "aarch64-linux": { "asset": "aizen-watch-linux-aarch64.bin", "binary": "aizen-watch" },
        \\    "riscv64-linux": { "asset": "aizen-watch-linux-riscv64.bin", "binary": "aizen-watch" },
        \\    "x86_64-windows": { "asset": "aizen-watch-windows-x86_64.exe", "binary": "aizen-watch.exe" },
        \\    "aarch64-windows": { "asset": "aizen-watch-windows-aarch64.exe", "binary": "aizen-watch.exe" }
        \\  },
        \\  "build_from_source": {
        \\    "zig_version": "0.16.0",
        \\    "command": "zig build -Doptimize=ReleaseSmall",
        \\    "output": "zig-out/bin/aizen-watch"
        \\  },
        \\  "launch": { "command": "aizen-watch", "args": ["serve"] },
        \\  "health": { "endpoint": "/health", "port_from_config": "port" },
        \\  "ports": [{ "name": "api", "config_key": "port", "default": 7710, "protocol": "http" }],
        \\  "wizard": { "steps": [
        \\    { "id": "port", "title": "API Port", "type": "number", "required": true, "default_value": "7710", "options": [] },
        \\    { "id": "api_token", "title": "API Token", "description": "Optional bearer token for write/query API access", "type": "secret", "required": false, "options": [] },
        \\    { "id": "data_dir", "title": "Data Directory", "description": "Directory for aizen-watch JSONL storage files", "type": "text", "required": true, "default_value": "data", "options": [] },
        \\    { "id": "host", "title": "Bind Host", "description": "IP address to bind the HTTP API to", "type": "text", "required": false, "default_value": "127.0.0.1", "advanced": true, "options": [] }
        \\  ] },
        \\  "depends_on": [],
        \\  "connects_to": [
        \\    { "component": "aizen", "role": "telemetry-source", "description": "Ingest OTLP traces emitted by aizen runtime observers" },
        \\    { "component": "aizen-kanban", "role": "task-context", "description": "Attach tracker ids and pipeline context to runs" },
        \\    { "component": "aizen-orchestrate", "role": "strategy-context", "description": "Attach orchestration strategy/version metadata to runs" }
        \\  ]
        \\}
    ;

    const stdout = std_compat.fs.File.stdout();
    try stdout.writeAll(manifest);
    try stdout.writeAll("\n");
}
