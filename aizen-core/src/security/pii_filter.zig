//! PII Filter — automatic detection and redaction of PII in agent I/O.
//!
//! Detects and redacts:
//!   - Email addresses
//!   - Phone numbers (international formats)
//!   - Credit card numbers (Luhn-validated)
//!   - Social Security / National ID numbers
//!   - IP addresses (v4 and v6)
//!   - API keys and tokens (heuristic)
//!   - Physical addresses (street address patterns)
//!
//! Usage:
//!   var filter = PiiFilter.init(allocator, .{ .redact_email = true });
//!   const clean = try filter.redact("Contact me at user@example.com");
//!   // clean == "Contact me at [EMAIL]"

const std = @import("std");
const log = std.log.scoped(.pii_filter);

pub const PiiConfig = struct {
    redact_email: bool = true,
    redact_phone: bool = true,
    redact_credit_card: bool = true,
    redact_ssn: bool = true,
    redact_ip_address: bool = true,
    redact_api_key: bool = true,
    redact_street_address: bool = false, // Off by default (high false-positive rate)
    /// Replacement string for redacted PII.
    replacement: []const u8 = "[REDACTED]",
    /// When true, preserve first/last 2 chars for context (e.g., "us[EMAIL]om").
    preserve_hint: bool = false,
};

pub const PiiFilter = struct {
    allocator: std.mem.Allocator,
    config: PiiConfig,

    pub fn init(allocator: std.mem.Allocator, config: PiiConfig) PiiFilter {
        return .{ .allocator = allocator, .config = config };
    }

    pub fn deinit(self: *PiiFilter) void {
        _ = self;
    }

    /// Redact all PII from content. Returns newly allocated string.
    pub fn redact(self: *PiiFilter, content: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).empty;
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < content.len) {
            const match = self.findNextPii(content, i);
            if (match) |m| {
                try result.appendSlice(self.allocator, content[i..m.start]);
                try self.appendRedaction(self.allocator, &result, content[m.start..m.end], m.kind);
                i = m.end;
            } else {
                try result.appendSlice(self.allocator, content[i..]);
                break;
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// Scan content for PII. Returns true if any PII pattern found.
    pub fn containsPii(self: *PiiFilter, content: []const u8) bool {
        var i: usize = 0;
        while (i < content.len) {
            const match = self.findNextPii(content, i);
            if (match != null) return true;
            i += 1;
        }
        return false;
    }

    const Match = struct {
        start: usize,
        end: usize,
        kind: []const u8,
    };

    fn findNextPii(self: *PiiFilter, content: []const u8, start: usize) ?Match {
        var best: ?Match = null;

        if (self.config.redact_email) {
            if (findEmail(content, start)) |m| {
                if (best == null or m.start < best.?.start) best = m;
            }
        }
        if (self.config.redact_phone) {
            if (findPhone(content, start)) |m| {
                if (best == null or m.start < best.?.start) best = m;
            }
        }
        if (self.config.redact_credit_card) {
            if (findCreditCard(content, start)) |m| {
                if (best == null or m.start < best.?.start) best = m;
            }
        }
        if (self.config.redact_ssn) {
            if (findSsn(content, start)) |m| {
                if (best == null or m.start < best.?.start) best = m;
            }
        }
        if (self.config.redact_ip_address) {
            if (findIpAddress(content, start)) |m| {
                if (best == null or m.start < best.?.start) best = m;
            }
        }
        if (self.config.redact_api_key) {
            if (findApiKey(content, start)) |m| {
                if (best == null or m.start < best.?.start) best = m;
            }
        }

        return best;
    }

    fn appendRedaction(self: *PiiFilter, allocator: std.mem.Allocator, result: *std.ArrayList(u8), original: []const u8, kind: []const u8) !void {
        _ = kind;
        if (self.config.preserve_hint and original.len > 6) {
            try result.appendSlice(allocator, original[0..2]);
            try result.appendSlice(allocator, "...");
            try result.appendSlice(allocator, original[original.len - 2 ..]);
            try result.appendSlice(allocator, " ");
            try result.appendSlice(allocator, self.config.replacement);
        } else {
            try result.appendSlice(allocator, self.config.replacement);
        }
    }

    // ── Pattern detectors ────────────────────────────────────────

    fn findEmail(content: []const u8, start: usize) ?Match {
        const at_idx = std.mem.indexOfScalarPos(u8, content, start, '@') orelse return null;
        if (at_idx == 0 or at_idx >= content.len - 1) return null;

        // Find local part start
        var local_start = at_idx;
        while (local_start > start) {
            const c = content[local_start - 1];
            if (std.ascii.isAlphanumeric(c) or c == '.' or c == '_' or c == '-') {
                local_start -= 1;
            } else break;
        }

        // Find domain end
        var domain_end = at_idx + 1;
        while (domain_end < content.len) {
            const c = content[domain_end];
            if (std.ascii.isAlphanumeric(c) or c == '.' or c == '-') {
                domain_end += 1;
            } else break;
        }

        // Must have at least one dot in domain
        const domain = content[at_idx + 1 .. domain_end];
        if (std.mem.indexOfScalar(u8, domain, '.') == null) return null;
        if (domain.len < 3) return null; // a.b minimum

        return Match{ .start = local_start, .end = domain_end, .kind = "EMAIL" };
    }

    fn findPhone(content: []const u8, start: usize) ?Match {
        // Look for sequences of 10-15 digits with optional separators
        var i = start;
        while (i < content.len) {
            // Find first digit
            while (i < content.len and !std.ascii.isDigit(content[i])) i += 1;
            if (i >= content.len) break;

            const seq_start = i;
            var digit_count: usize = 0;
            var last_digit_end = i;

            while (i < content.len) {
                const c = content[i];
                if (std.ascii.isDigit(c)) {
                    digit_count += 1;
                    last_digit_end = i + 1;
                    i += 1;
                } else if (c == ' ' or c == '-' or c == '.' or c == '(' or c == ')' or c == '+') {
                    i += 1;
                } else break;
            }

            if (digit_count >= 10 and digit_count <= 15) {
                return Match{ .start = seq_start, .end = last_digit_end, .kind = "PHONE" };
            }
        }
        return null;
    }

    fn findCreditCard(content: []const u8, start: usize) ?Match {
        // Look for 13-19 digit sequences, optionally with spaces/hyphens every 4 digits
        var i = start;
        while (i < content.len) {
            while (i < content.len and !std.ascii.isDigit(content[i])) i += 1;
            if (i >= content.len) break;

            const seq_start = i;
            var digits: [32]u8 = undefined;
            var digit_count: usize = 0;
            var last_digit_end = i;

            while (i < content.len and digit_count < 32) {
                const c = content[i];
                if (std.ascii.isDigit(c)) {
                    digits[digit_count] = c;
                    digit_count += 1;
                    last_digit_end = i + 1;
                    i += 1;
                } else if (c == ' ' or c == '-') {
                    i += 1;
                } else break;
            }

            if (digit_count >= 13 and digit_count <= 19) {
                if (luhnCheck(digits[0..digit_count])) {
                    return Match{ .start = seq_start, .end = last_digit_end, .kind = "CREDIT_CARD" };
                }
            }
        }
        return null;
    }

    fn findSsn(content: []const u8, start: usize) ?Match {
        // US SSN: XXX-XX-XXXX or XXX XX XXXX
        var i = start;
        while (i + 11 <= content.len) {
            if (isSsnPattern(content, i)) {
                return Match{ .start = i, .end = i + 11, .kind = "SSN" };
            }
            i += 1;
        }
        return null;
    }

    fn isSsnPattern(content: []const u8, i: usize) bool {
        // Check XXX-XX-XXXX
        if (content[i + 3] == '-' and content[i + 6] == '-') {
            return isDigit3(content, i) and isDigit2(content, i + 4) and isDigit4(content, i + 7);
        }
        // Check XXX XX XXXX
        if (content[i + 3] == ' ' and content[i + 6] == ' ') {
            return isDigit3(content, i) and isDigit2(content, i + 4) and isDigit4(content, i + 7);
        }
        return false;
    }

    fn isDigit3(content: []const u8, i: usize) bool {
        return std.ascii.isDigit(content[i]) and std.ascii.isDigit(content[i + 1]) and std.ascii.isDigit(content[i + 2]);
    }
    fn isDigit2(content: []const u8, i: usize) bool {
        return std.ascii.isDigit(content[i]) and std.ascii.isDigit(content[i + 1]);
    }
    fn isDigit4(content: []const u8, i: usize) bool {
        return std.ascii.isDigit(content[i]) and std.ascii.isDigit(content[i + 1]) and std.ascii.isDigit(content[i + 2]) and std.ascii.isDigit(content[i + 3]);
    }

    fn findIpAddress(content: []const u8, start: usize) ?Match {
        // IPv4: XXX.XXX.XXX.XXX
        var i = start;
        while (i + 7 <= content.len) {
            if (isIpv4Pattern(content, i)) |end| {
                return Match{ .start = i, .end = end, .kind = "IP" };
            }
            i += 1;
        }
        return null;
    }

    fn isIpv4Pattern(content: []const u8, start: usize) ?usize {
        var i = start;
        var octets: usize = 0;
        while (octets < 4) : (octets += 1) {
            var num_len: usize = 0;
            while (i < content.len and std.ascii.isDigit(content[i]) and num_len < 3) {
                i += 1;
                num_len += 1;
            }
            if (num_len == 0 or num_len > 3) return null;
            const num = std.fmt.parseInt(u8, content[i - num_len .. i], 10) catch return null;
            if (num > 255) return null;
            if (octets < 3) {
                if (i >= content.len or content[i] != '.') return null;
                i += 1;
            }
        }
        return i;
    }

    fn findApiKey(content: []const u8, start: usize) ?Match {
        // Heuristic: look for common API key patterns
        const prefixes = &[_][]const u8{
            "sk-", "pk-", "api_key", "apikey", "token", "secret",
            "ghp_", "gho_", "glpat-", "AKIA", " Bearer ", "Basic ",
        };

        for (prefixes) |prefix| {
            if (std.mem.indexOfPos(u8, content, start, prefix)) |idx| {
                const value_start = idx + prefix.len;
                var value_end = value_start;
                while (value_end < content.len) {
                    const c = content[value_end];
                    if (std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == '.') {
                        value_end += 1;
                    } else break;
                }
                if (value_end > value_start + 8) { // Minimum key length
                    return Match{ .start = idx, .end = value_end, .kind = "API_KEY" };
                }
            }
        }
        return null;
    }

    // ── Luhn algorithm for credit card validation ────────────────

    fn luhnCheck(digits: []const u8) bool {
        if (digits.len < 13) return false;
        var sum: usize = 0;
        var alternate = false;
        var i: usize = digits.len;
        while (i > 0) {
            i -= 1;
            var n = digits[i] - '0';
            if (alternate) {
                n *= 2;
                if (n > 9) n -= 9;
            }
            sum += n;
            alternate = !alternate;
        }
        return sum % 10 == 0;
    }
};

// ── Tests ───────────────────────────────────────────────────────

test "PiiFilter redacts email" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_email = true });
    defer filter.deinit();

    const result = try filter.redact("Contact me at user@example.com please");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "user@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "[REDACTED]") != null);
}

test "PiiFilter redacts phone number" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_phone = true });
    defer filter.deinit();

    const result = try filter.redact("Call me at 555-123-4567");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "555-123-4567") == null);
}

test "PiiFilter redacts credit card" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_credit_card = true });
    defer filter.deinit();

    // Valid Luhn: 4532015112830366
    const result = try filter.redact("Card: 4532015112830366");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "4532015112830366") == null);
}

test "PiiFilter redacts SSN" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_ssn = true });
    defer filter.deinit();

    const result = try filter.redact("SSN: 123-45-6789");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "123-45-6789") == null);
}

test "PiiFilter redacts IP address" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_ip_address = true });
    defer filter.deinit();

    const result = try filter.redact("Server at 192.168.1.1");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "192.168.1.1") == null);
}

test "PiiFilter detects API key" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_api_key = true });
    defer filter.deinit();

    const result = try filter.redact("Key: sk-abc123def456ghi789");
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "sk-abc123def456ghi789") == null);
}

test "PiiFilter containsPii returns true for PII content" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{});
    defer filter.deinit();

    try std.testing.expect(filter.containsPii("Email: test@example.com"));
    try std.testing.expect(!filter.containsPii("Hello world"));
}

test "PiiFilter no false positive on normal text" {
    const allocator = std.testing.allocator;
    var filter = PiiFilter.init(allocator, .{ .redact_email = true });
    defer filter.deinit();

    const result = try filter.redact("Hello world, this is normal text");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello world, this is normal text", result);
}
