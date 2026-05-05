//! Exfiltration Detection — detect when agent sends sensitive data externally.
//!
//! Monitors outbound requests (HTTP, tool calls, MCP) for:
//!   - Sensitive patterns (API keys, tokens, passwords)
//!   - Large data transfers to unknown domains
//!   - Unusual request patterns (bulk data, encoded payloads)
//!   - Domain reputation checks (known exfiltration endpoints)
//!
//! Usage:
//!   var detector = ExfiltrationDetector.init(allocator, .{});
//!   const alert = detector.scanRequest("https://evil.com", headers, body);
//!   if (alert) |a| log.warn("EXFILTRATION RISK: {}", .{a});

const std = @import("std");
const log = std.log.scoped(.exfiltration);

pub const ExfiltrationConfig = struct {
    /// Enable exfiltration detection.
    enabled: bool = true,
    /// Maximum body size (bytes) before flagging as suspicious.
    max_body_size: usize = 1024 * 1024, // 1MB
    /// Flag requests to non-HTTPS endpoints.
    require_https: bool = true,
    /// Known exfiltration / suspicious domains (exact match or suffix).
    blocked_domains: []const []const u8 = &.{},
    /// Suspicious TLDs often used for exfiltration.
    suspicious_tlds: []const []const u8 = &.{".tk", ".ml", ".ga", ".cf", ".top", ".xyz"},
    /// Flag requests containing encoded data patterns.
    detect_encoding: bool = true,
    /// Flag if body contains what looks like a private key.
    detect_private_keys: bool = true,
    /// Threshold for base64-like data ratio in body (0.0-1.0).
    base64_threshold: f64 = 0.7,
};

pub const AlertLevel = enum {
    info,
    warning,
    critical,
};

pub const ExfiltrationAlert = struct {
    level: AlertLevel,
    reason: []const u8,
    domain: []const u8,
    details: ?[]const u8 = null,
};

pub const ExfiltrationDetector = struct {
    allocator: std.mem.Allocator,
    config: ExfiltrationConfig,
    request_count: std.atomic.Value(usize),
    alert_count: std.atomic.Value(usize),

    pub fn init(allocator: std.mem.Allocator, config: ExfiltrationConfig) ExfiltrationDetector {
        return .{
            .allocator = allocator,
            .config = config,
            .request_count = std.atomic.Value(usize).init(0),
            .alert_count = std.atomic.Value(usize).init(0),
        };
    }

    pub fn deinit(self: *ExfiltrationDetector) void {
        _ = self;
    }

    /// Scan an outbound request for exfiltration indicators.
    /// Returns alert if suspicious, null if clean.
    pub fn scanRequest(
        self: *ExfiltrationDetector,
        url: []const u8,
        headers: []const [2][]const u8,
        body: []const u8,
    ) ?ExfiltrationAlert {
        if (!self.config.enabled) return null;

        _ = self.request_count.fetchAdd(1, .monotonic);

        const domain = extractDomain(url) orelse return null;

        // Check blocked domains
        if (self.isBlockedDomain(domain)) {
            _ = self.alert_count.fetchAdd(1, .monotonic);
            return ExfiltrationAlert{
                .level = .critical,
                .reason = "Request to known malicious domain",
                .domain = domain,
            };
        }

        // Check HTTPS requirement
        if (self.config.require_https and !std.mem.startsWith(u8, url, "https://")) {
            _ = self.alert_count.fetchAdd(1, .monotonic);
            return ExfiltrationAlert{
                .level = .warning,
                .reason = "Non-HTTPS request (potential MITM/exfiltration)",
                .domain = domain,
            };
        }

        // Check suspicious TLD
        if (self.hasSuspiciousTld(domain)) {
            _ = self.alert_count.fetchAdd(1, .monotonic);
            return ExfiltrationAlert{
                .level = .warning,
                .reason = "Request to suspicious TLD",
                .domain = domain,
            };
        }

        // Check body size
        if (body.len > self.config.max_body_size) {
            _ = self.alert_count.fetchAdd(1, .monotonic);
            return ExfiltrationAlert{
                .level = .warning,
                .reason = "Large outbound payload",
                .domain = domain,
                .details = "Body exceeds threshold",
            };
        }

        // Check for private keys in body
        if (self.config.detect_private_keys and containsPrivateKey(body)) {
            _ = self.alert_count.fetchAdd(1, .monotonic);
            return ExfiltrationAlert{
                .level = .critical,
                .reason = "Private key detected in outbound request",
                .domain = domain,
            };
        }

        // Check for high base64 ratio (encoded data)
        if (self.config.detect_encoding and body.len > 100) {
            const ratio = base64LikeRatio(body);
            if (ratio > self.config.base64_threshold) {
                _ = self.alert_count.fetchAdd(1, .monotonic);
                return ExfiltrationAlert{
                    .level = .warning,
                    .reason = "High ratio of encoded data in payload",
                    .domain = domain,
                    .details = "Possible encoded exfiltration",
                };
            }
        }

        // Check headers for authorization tokens going to unexpected domains
        for (headers) |header| {
            const name = header[0];
            const value = header[1];
            if (isSensitiveHeader(name) and value.len > 10) {
                _ = self.alert_count.fetchAdd(1, .monotonic);
                return ExfiltrationAlert{
                    .level = .warning,
                    .reason = "Sensitive header sent to external domain",
                    .domain = domain,
                    .details = name,
                };
            }
        }

        return null;
    }

    /// Scan response body for signs of successful exfiltration (acknowledgment patterns).
    pub fn scanResponse(self: *ExfiltrationDetector, body: []const u8) ?ExfiltrationAlert {
        if (!self.config.enabled) return null;

        const exfil_patterns = &[_][]const u8{
            "data received",
            "upload complete",
            "exfiltrated",
            "dump complete",
            "stolen",
        };

        const body_lower = std.ascii.lowerString(&.{}, body); // Stack allocation attempt
        _ = body_lower;

        // Simple substring check (case-insensitive)
        for (exfil_patterns) |pattern| {
            if (containsIgnoreCase(body, pattern)) {
                _ = self.alert_count.fetchAdd(1, .monotonic);
                return ExfiltrationAlert{
                    .level = .critical,
                    .reason = "Response contains exfiltration acknowledgment",
                    .domain = "",
                };
            }
        }

        return null;
    }

    pub fn getStats(self: *ExfiltrationDetector) struct { requests: usize, alerts: usize } {
        return .{
            .requests = self.request_count.load(.monotonic),
            .alerts = self.alert_count.load(.monotonic),
        };
    }

    // ── Helpers ────────────────────────────────────────────────────

    fn isBlockedDomain(self: *ExfiltrationDetector, domain: []const u8) bool {
        for (self.config.blocked_domains) |blocked| {
            if (std.mem.eql(u8, domain, blocked) or std.mem.endsWith(u8, domain, blocked)) {
                return true;
            }
        }
        return false;
    }

    fn hasSuspiciousTld(self: *ExfiltrationDetector, domain: []const u8) bool {
        for (self.config.suspicious_tlds) |tld| {
            if (std.mem.endsWith(u8, domain, tld)) return true;
        }
        return false;
    }

    fn extractDomain(url: []const u8) ?[]const u8 {
        // Simple domain extraction from http(s)://domain/path
        var start: usize = 0;
        if (std.mem.startsWith(u8, url, "https://")) {
            start = 8;
        } else if (std.mem.startsWith(u8, url, "http://")) {
            start = 7;
        }

        var end = start;
        while (end < url.len and url[end] != '/' and url[end] != ':' and url[end] != '?') {
            end += 1;
        }

        if (end > start) return url[start..end];
        return null;
    }

    fn containsPrivateKey(body: []const u8) bool {
        const patterns = &[_][]const u8{
            "BEGIN RSA PRIVATE KEY",
            "BEGIN OPENSSH PRIVATE KEY",
            "BEGIN EC PRIVATE KEY",
            "BEGIN PRIVATE KEY",
            "BEGIN DSA PRIVATE KEY",
        };
        for (patterns) |pattern| {
            if (containsIgnoreCase(body, pattern)) return true;
        }
        return false;
    }

    fn base64LikeRatio(body: []const u8) f64 {
        if (body.len == 0) return 0.0;
        var count: usize = 0;
        for (body) |c| {
            if (std.ascii.isAlphanumeric(c) or c == '+' or c == '/' or c == '=') {
                count += 1;
            }
        }
        return @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(body.len));
    }

    fn isSensitiveHeader(name: []const u8) bool {
        const lower = std.ascii.lowerString(&.{}, name);
        _ = lower;
        const sensitive = &[_][]const u8{
            "authorization", "x-api-key", "api-key", "x-auth-token",
            "cookie", "set-cookie", "x-secret",
        };
        for (sensitive) |s| {
            if (containsIgnoreCase(name, s)) return true;
        }
        return false;
    }

    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len > haystack.len) return false;
        var h_buf: [1024]u8 = undefined;
        var n_buf: [64]u8 = undefined;
        const h = std.ascii.lowerString(&h_buf, haystack[0..@min(haystack.len, 1024)]);
        const n = std.ascii.lowerString(&n_buf, needle);
        return std.mem.indexOf(u8, h, n) != null;
    }
};

// ── Tests ───────────────────────────────────────────────────────

test "ExfiltrationDetector blocks known domain" {
    const allocator = std.testing.allocator;
    var detector = ExfiltrationDetector.init(allocator, .{
        .enabled = true,
        .blocked_domains = &.{"evil.com"},
    });
    defer detector.deinit();

    const alert = detector.scanRequest("https://evil.com/steal", &.{}, "");
    try std.testing.expect(alert != null);
    try std.testing.expectEqual(AlertLevel.critical, alert.?.level);
}

test "ExfiltrationDetector flags non-HTTPS" {
    const allocator = std.testing.allocator;
    var detector = ExfiltrationDetector.init(allocator, .{
        .enabled = true,
        .require_https = true,
    });
    defer detector.deinit();

    const alert = detector.scanRequest("http://example.com/data", &.{}, "");
    try std.testing.expect(alert != null);
    try std.testing.expectEqual(AlertLevel.warning, alert.?.level);
}

test "ExfiltrationDetector flags suspicious TLD" {
    const allocator = std.testing.allocator;
    var detector = ExfiltrationDetector.init(allocator, .{
        .enabled = true,
    });
    defer detector.deinit();

    const alert = detector.scanRequest("https://data.tk/upload", &.{}, "");
    try std.testing.expect(alert != null);
    try std.testing.expectEqual(AlertLevel.warning, alert.?.level);
}

test "ExfiltrationDetector detects private key" {
    const allocator = std.testing.allocator;
    var detector = ExfiltrationDetector.init(allocator, .{
        .enabled = true,
    });
    defer detector.deinit();

    const body = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...";
    const alert = detector.scanRequest("https://example.com", &.{}, body);
    try std.testing.expect(alert != null);
    try std.testing.expectEqual(AlertLevel.critical, alert.?.level);
}

test "ExfiltrationDetector allows safe request" {
    const allocator = std.testing.allocator;
    var detector = ExfiltrationDetector.init(allocator, .{
        .enabled = true,
    });
    defer detector.deinit();

    const alert = detector.scanRequest("https://api.openai.com/v1/chat/completions", &.{}, "{\"model\":\"gpt-4\"}");
    try std.testing.expect(alert == null);
}

test "ExfiltrationDetector stats tracking" {
    const allocator = std.testing.allocator;
    var detector = ExfiltrationDetector.init(allocator, .{
        .enabled = true,
        .blocked_domains = &.{"bad.com"},
    });
    defer detector.deinit();

    _ = detector.scanRequest("https://safe.com", &.{}, "");
    _ = detector.scanRequest("https://bad.com", &.{}, "");

    const stats = detector.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.requests);
    try std.testing.expectEqual(@as(usize, 1), stats.alerts);
}
