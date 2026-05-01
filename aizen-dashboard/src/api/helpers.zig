const std = @import("std");

// ─── Response types ──────────────────────────────────────────────────────────

pub const ApiResponse = struct {
    status: []const u8,
    content_type: []const u8,
    body: []const u8,
};

pub fn jsonOk(body: []const u8) ApiResponse {
    return .{ .status = "200 OK", .content_type = "application/json", .body = body };
}

pub fn notFound() ApiResponse {
    return .{
        .status = "404 Not Found",
        .content_type = "application/json",
        .body = "{\"error\":\"not found\"}",
    };
}

pub fn badRequest(msg: []const u8) ApiResponse {
    return .{
        .status = "400 Bad Request",
        .content_type = "application/json",
        .body = msg,
    };
}

pub fn serverError() ApiResponse {
    return .{
        .status = "500 Internal Server Error",
        .content_type = "application/json",
        .body = "{\"error\":\"internal error\"}",
    };
}

pub fn methodNotAllowed() ApiResponse {
    return .{
        .status = "405 Method Not Allowed",
        .content_type = "application/json",
        .body = "{\"error\":\"method not allowed\"}",
    };
}

// ─── JSON helpers ────────────────────────────────────────────────────────────

pub fn appendEscaped(buf: *std.array_list.Managed(u8), s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice("\\\""),
            '\\' => try buf.appendSlice("\\\\"),
            '\n' => try buf.appendSlice("\\n"),
            '\r' => try buf.appendSlice("\\r"),
            '\t' => try buf.appendSlice("\\t"),
            else => try buf.append(c),
        }
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

test "appendEscaped escapes special characters" {
    const allocator = std.testing.allocator;
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try appendEscaped(&buf, "hello \"world\"\nnewline\\backslash");
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnewline\\\\backslash", buf.items);
}

test "appendEscaped passes through plain text" {
    const allocator = std.testing.allocator;
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try appendEscaped(&buf, "hello world");
    try std.testing.expectEqualStrings("hello world", buf.items);
}

test "jsonOk returns correct response" {
    const resp = jsonOk("{\"ok\":true}");
    try std.testing.expectEqualStrings("200 OK", resp.status);
    try std.testing.expectEqualStrings("application/json", resp.content_type);
    try std.testing.expectEqualStrings("{\"ok\":true}", resp.body);
}

test "notFound returns 404" {
    const resp = notFound();
    try std.testing.expectEqualStrings("404 Not Found", resp.status);
    try std.testing.expectEqualStrings("{\"error\":\"not found\"}", resp.body);
}

test "badRequest returns 400" {
    const resp = badRequest("{\"error\":\"bad\"}");
    try std.testing.expectEqualStrings("400 Bad Request", resp.status);
    try std.testing.expectEqualStrings("{\"error\":\"bad\"}", resp.body);
}

test "serverError returns 500" {
    const resp = serverError();
    try std.testing.expectEqualStrings("500 Internal Server Error", resp.status);
    try std.testing.expectEqualStrings("{\"error\":\"internal error\"}", resp.body);
}

test "methodNotAllowed returns 405" {
    const resp = methodNotAllowed();
    try std.testing.expectEqualStrings("405 Method Not Allowed", resp.status);
    try std.testing.expectEqualStrings("{\"error\":\"method not allowed\"}", resp.body);
}
