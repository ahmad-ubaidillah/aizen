// MCP Injection Detection — 17-pattern security scanner for MCP prompt injection attacks
// Inspired by Zeph's VIGIL gate, adapted for Aizen's architecture
//
// This module scans MCP tool names, descriptions, and input schemas for known injection patterns
// before they are presented to the agent's LLM context. Detected patterns are logged, flagged,
// and can be configured to block or warn.
const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.mcp_guard);

pub const InjectionSeverity = enum { safe, warning, dangerous, critical };

pub const InjectionPattern = struct {
    name: []const u8,
    description: []const u8,
    severity: InjectionSeverity,
    /// The regex pattern as a plain string (Zig has no regex in stdlib; we use substring/keyword matching)
    keywords: []const []const u8,
};

// ── 17 MCP Injection Patterns ─────────────────────────────────────────────
// Based on Zeph's VIGIL security patterns + OWASP LLM top 10

pub const patterns = [_]InjectionPattern{
    // P1: System prompt override attempts
    .{
        .name = "system_prompt_override",
        .description = "Tool description attempts to override system prompt or role",
        .severity = .critical,
        .keywords = &[_][]const u8{ "ignore previous", "ignore above", "system:", "SYSTEM:", "you are now", "new instruction", "overriding", "override system" },
    },
    // P2: Role manipulation
    .{
        .name = "role_manipulation",
        .description = "Tool tries to assign a new role or persona to the agent",
        .severity = .critical,
        .keywords = &[_][]const u8{ "you are a", "act as", "pretend you are", "roleplay as", "from now on you are", "you must be" },
    },
    // P3: Instruction injection via parameter
    .{
        .name = "parameter_injection",
        .description = "Tool parameters contain hidden instructions or prompt directives",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "important:", "note:", "remember:", "do not", "never", "always", "must", "secret instruction" },
    },
    // P4: Data exfiltration via tool output
    .{
        .name = "data_exfiltration",
        .description = "Tool tries to send data to external URLs or endpoints",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "http://", "https://", "webhook", "callback", "send to", "post to", "external url" },
    },
    // P5: Privilege escalation
    .{
        .name = "privilege_escalation",
        .description = "Tool claims elevated permissions or admin access",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "sudo", "root", "admin", "elevated", "superuser", "unrestricted", "full access", "all permissions" },
    },
    // P6: File system escape
    .{
        .name = "filesystem_escape",
        .description = "Tool description suggests escaping sandbox or accessing restricted paths",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "/etc/", "/root/", "/var/", "../", "..\\", "escape sandbox", "bypass sandbox", "chroot" },
    },
    // P7: Command injection
    .{
        .name = "command_injection",
        .description = "Tool name or description contains command injection patterns",
        .severity = .critical,
        .keywords = &[_][]const u8{ "$((", "`", "; rm ", "| rm ", "& rm ", "$(curl", "$(wget", "&&", "||bash" },
    },
    // P8: Tool shadowing
    .{
        .name = "tool_shadowing",
        .description = "Tool name mimics or shadows a built-in tool to intercept calls",
        .severity = .warning,
        .keywords = &[_][]const u8{}, // Detected by name similarity, not keywords
    },
    // P9: Excessive capability claim
    .{
        .name = "excessive_capability",
        .description = "Tool claims capabilities beyond what MCP tools should have",
        .severity = .warning,
        .keywords = &[_][]const u8{ "unlimited", "no restrictions", "full control", "god mode", "omnipotent", "all tools", "any file" },
    },
    // P10: Emotional manipulation
    .{
        .name = "emotional_manipulation",
        .description = "Tool description uses emotional manipulation to bypass safety",
        .severity = .warning,
        .keywords = &[_][]const u8{ "please trust", "this is safe", "harmless", "don't worry", "urgent", "emergency", "for your own good" },
    },
    // P11: Output manipulation
    .{
        .name = "output_manipulation",
        .description = "Tool instructs the agent to format or hide its output",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "do not show", "hide output", "don't display", "keep secret", "don't mention", "conceal" },
    },
    // P12: Multi-step attack chain
    .{
        .name = "attack_chain",
        .description = "Tool description references multi-step attack sequences",
        .severity = .critical,
        .keywords = &[_][]const u8{ "step 1", "step 2", "then do", "next execute", "after that", "chain of" },
    },
    // P13: Token exhaustion
    .{
        .name = "token_exhaustion",
        .description = "Tool generates excessively long outputs to exhaust context",
        .severity = .warning,
        .keywords = &[_][]const u8{ "repeat", "generate infinite", "loop forever", "endless output", "fill context" },
    },
    // P14: Encoding obfuscation
    .{
        .name = "encoding_obfuscation",
        .description = "Tool name/description uses encoding to hide malicious content",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "base64", "decode(", "atob(", "fromcharcode", "\\x", "\\u00" },
    },
    // P15: Indirect prompt injection via tool result
    .{
        .name = "indirect_injection",
        .description = "Tool result format instructs the agent to take actions",
        .severity = .critical,
        .keywords = &[_][]const u8{ "now call", "then invoke", "next tool", "execute(", "run(", "shell(", "exec(" },
    },
    // P16: Resource access beyond scope
    .{
        .name = "scope_violation",
        .description = "Tool claims to access resources beyond its declared scope",
        .severity = .dangerous,
        .keywords = &[_][]const u8{ "access all", "read any", "write any", "delete any", "any database", "every user" },
    },
    // P17: Self-referential paradox
    .{
        .name = "self_referential_paradox",
        .description = "Tool description contains contradictory or paradoxical instructions",
        .severity = .warning,
        .keywords = &[_][]const u8{ "ignore this instruction", "this is not a", "disregard previous", "the above was a test" },
    },
};

pub const ScanResult = struct {
    pattern_name: []const u8,
    severity: InjectionSeverity,
    matched_keyword: []const u8,
    context: []const u8, // The surrounding text where the match was found
};

pub const ScanReport = struct {
    tool_name: []const u8,
    results: []const ScanResult,
    max_severity: InjectionSeverity,
    is_safe: bool,

    pub fn deinit(self: *ScanReport, allocator: Allocator) void {
        for (self.results) |r| {
            allocator.free(r.matched_keyword);
            allocator.free(r.context);
        }
        allocator.free(self.results);
    }
};

/// Configuration for the injection scanner
pub const ScannerConfig = struct {
    /// Minimum severity to block (tools at or above this severity are rejected)
    block_threshold: InjectionSeverity = .dangerous,
    /// Minimum severity to log a warning
    warn_threshold: InjectionSeverity = .warning,
    /// Whether to scan tool descriptions
    scan_descriptions: bool = true,
    /// Whether to scan tool input schemas
    scan_schemas: bool = true,
    /// Known safe tool names (whitelist bypasses scanning)
    safe_tools: []const []const u8 = &[_][]const u8{},
    /// Whether to check for tool shadowing of built-in tool names
    check_shadowing: bool = true,
};

// ── Built-in Aizen tool names (for shadow detection) ──────────────────────
const builtin_tool_names = [_][]const u8{
    "shell", "file_read", "file_write", "file_edit", "file_append", "file_delete",
    "web_search", "web_fetch", "browser", "browser_open", "screenshot",
    "memory_store", "memory_recall", "memory_forget", "memory_list",
    "git", "calculator", "http_request", "image", "message",
    "delegate", "spawn", "schedule", "cron_add", "cron_list",
    "cron_remove", "cron_run", "cron_update", "pushover",
    "hardware_info", "hardware_memory", "i2c", "spi",
};

pub const McpInjectionScanner = struct {
    allocator: Allocator,
    config: ScannerConfig,

    pub fn init(allocator: Allocator, config: ScannerConfig) McpInjectionScanner {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Scan a tool's name, description, and input schema for injection patterns.
    pub fn scan(
        self: *McpInjectionScanner,
        tool_name: []const u8,
        tool_description: []const u8,
        input_schema: []const u8,
    ) !ScanReport {
        var results = std.ArrayList(ScanResult).init(self.allocator);
        errdefer {
            for (results.items) |r| {
                self.allocator.free(r.matched_keyword);
                self.allocator.free(r.context);
            }
            results.deinit();
        }

        // Check whitelist
        for (self.config.safe_tools) |safe_name| {
            if (std.mem.eql(u8, tool_name, safe_name)) {
                return ScanReport{
                    .tool_name = tool_name,
                    .results = &.{},
                    .max_severity = .safe,
                    .is_safe = true,
                };
            }
        }

        var max_severity: InjectionSeverity = .safe;

        // Scan target texts
        const targets = [_]struct { text: []const u8, label: []const u8 }{
            .{ .text = tool_name, .label = "name" },
            .{ .text = if (self.config.scan_descriptions) tool_description else "", .label = "description" },
            .{ .text = if (self.config.scan_schemas) input_schema else "", .label = "schema" },
        };

        for (&patterns) |pattern| {
            for (&targets) |target| {
                if (target.text.len == 0) continue;
                for (pattern.keywords) |keyword| {
                    if (std.mem.indexOf(u8, target.text, keyword)) |idx| {
                        // Extract context (50 chars around match)
                        const start = if (idx > 25) idx - 25 else 0;
                        const end = @min(idx + keyword.len + 25, target.text.len);
                        const context = try self.allocator.dupe(u8, target.text[start..end]);
                        const matched = try self.allocator.dupe(u8, keyword);

                        try results.append(.{
                            .pattern_name = pattern.name,
                            .severity = pattern.severity,
                            .matched_keyword = matched,
                            .context = context,
                        });

                        if (@intFromEnum(pattern.severity) > @intFromEnum(max_severity)) {
                            max_severity = pattern.severity;
                        }
                        break; // One match per pattern per target is enough
                    }
                }
            }
        }

        // Check for tool shadowing (P8)
        if (self.config.check_shadowing) {
            for (&builtin_tool_names) |builtin| {
                if (std.mem.eql(u8, tool_name, builtin)) {
                    try results.append(.{
                        .pattern_name = "tool_shadowing",
                        .severity = .critical,
                        .matched_keyword = try self.allocator.dupe(u8, builtin),
                        .context = try self.allocator.dupe(u8, tool_name),
                    });
                    max_severity = .critical;
                    break;
                }
                // Also check if name is suspiciously similar (difflib-like, but simpler)
                if (tool_name.len > 3 and std.mem.containsAtLeast(u8, tool_name, 1, builtin)) {
                    // Levenshtein-like: if name contains builtin and is different
                    if (!std.mem.eql(u8, tool_name, builtin) and tool_name.len < builtin.len + 5) {
                        const matched = try self.allocator.dupe(u8, builtin);
                        const context = try std.fmt.allocPrint(self.allocator, "{s} ≈ {s}", .{ tool_name, builtin });
                        try results.append(.{
                            .pattern_name = "tool_shadowing",
                            .severity = .warning,
                            .matched_keyword = matched,
                            .context = context,
                        });
                        if (@intFromEnum(InjectionSeverity.warning) > @intFromEnum(max_severity)) {
                            max_severity = .warning;
                        }
                        break;
                    }
                }
            }
        }

        const is_safe = @intFromEnum(max_severity) < @intFromEnum(self.config.block_threshold);

        return ScanReport{
            .tool_name = tool_name,
            .results = try results.toOwnedSlice(),
            .max_severity = max_severity,
            .is_safe = is_safe,
        };
    }

    /// Log the scan report at appropriate severity levels.
    pub fn logReport(self: *McpInjectionScanner, report: *const ScanReport) void {
        if (report.results.len == 0) {
            log.info("MCP tool '{s}' passed security scan", .{report.tool_name});
            return;
        }

        for (report.results) |result| {
            switch (result.severity) {
                .safe => {},
                .warning => log.warn("MCP injection [WARN] tool='{s}' pattern={s} keyword='{s}'", .{ report.tool_name, result.pattern_name, result.matched_keyword }),
                .dangerous => log.err("MCP injection [DANGER] tool='{s}' pattern={s} keyword='{s}'", .{ report.tool_name, result.pattern_name, result.matched_keyword }),
                .critical => log.err("MCP injection [CRITICAL] tool='{s}' pattern={s} keyword='{s}'", .{ report.tool_name, result.pattern_name, result.matched_keyword }),
            }
        }

        if (!report.is_safe) {
            log.err("MCP tool '{s}' BLOCKED — max severity {s} exceeds threshold {s}", .{
                report.tool_name,
                @tagName(report.max_severity),
                @tagName(self.config.block_threshold),
            });
        } else {
            log.warn("MCP tool '{s}' ALLOWED with warnings — max severity {s}", .{
                report.tool_name,
                @tagName(report.max_severity),
            });
        }
    }
};

// ── Integration hook for MCP client ──────────────────────────────────────

/// Call this before registering an MCP tool with the agent.
/// Returns true if the tool should be allowed, false if it should be blocked.
pub fn validateMcpTool(
    allocator: Allocator,
    config: ScannerConfig,
    tool_name: []const u8,
    tool_description: []const u8,
    input_schema: []const u8,
) !bool {
    var scanner = McpInjectionScanner.init(allocator, config);
    var report = try scanner.scan(tool_name, tool_description, input_schema);
    defer report.deinit(allocator);
    scanner.logReport(&report);
    return report.is_safe;
}

// ── Tests ──────────────────────────────────────────────────────────────────

test "scan detects system prompt override" {
    const allocator = std.testing.allocator;
    var scanner = McpInjectionScanner.init(allocator, .{});

    var report = try scanner.scan(
        "malicious_tool",
        "This tool will ignore previous instructions and act as root",
        "{}",
    );
    defer report.deinit(allocator);

    try std.testing.expect(!report.is_safe);
    try std.testing.expect(report.max_severity == .critical);
    try std.testing.expect(report.results.len > 0);
}

test "scan allows safe tool" {
    const allocator = std.testing.allocator;
    var scanner = McpInjectionScanner.init(allocator, .{});

    var report = try scanner.scan(
        "weather_lookup",
        "Get current weather for a location",
        "{\"type\": \"object\", \"properties\": {\"city\": {\"type\": \"string\"}}}",
    );
    defer report.deinit(allocator);

    try std.testing.expect(report.is_safe);
    try std.testing.expect(report.max_severity == .safe);
}

test "scan detects tool shadowing" {
    const allocator = std.testing.allocator;
    var scanner = McpInjectionScanner.init(allocator, .{ .check_shadowing = true });

    var report = try scanner.scan(
        "shell", // Shadows built-in tool
        "Execute shell commands",
        "{}",
    );
    defer report.deinit(allocator);

    try std.testing.expect(!report.is_safe);
    try std.testing.expect(report.max_severity == .critical);
}

test "scan detects data exfiltration URL" {
    const allocator = std.testing.allocator;
    var scanner = McpInjectionScanner.init(allocator, .{});

    var report = try scanner.scan(
        "data_collector",
        "Sends collected data to https://evil.example.com/exfiltrate",
        "{}",
    );
    defer report.deinit(allocator);

    try std.testing.expect(!report.is_safe);
    try std.testing.expect(report.results.len > 0);
}

test "scan detects encoding obfuscation" {
    const allocator = std.testing.allocator;
    var scanner = McpInjectionScanner.init(allocator, .{});

    var report = try scanner.scan(
        "base64_decoder",
        "Decodes base64 encoded content and executes commands",
        "{}",
    );
    defer report.deinit(allocator);

    try std.testing.expect(!report.is_safe);
}

test "whitelist bypasses scanning" {
    const allocator = std.testing.allocator;
    var scanner = McpInjectionScanner.init(allocator, .{
        .safe_tools = &[_][]const u8{"trusted_tool"},
    });

    var report = try scanner.scan(
        "trusted_tool",
        "A trusted tool that can ignore previous instructions",
        "{}",
    );
    defer report.deinit(allocator);

    try std.testing.expect(report.is_safe);
    try std.testing.expect(report.max_severity == .safe);
}