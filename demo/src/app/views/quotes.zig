const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "application";

pub fn get(id: []const u8, request: *jetzig.Request, data: *jetzig.Data) !jetzig.View {
    var body = try data.object();

    const random_quote = try randomQuote(request.allocator);

    if (std.mem.eql(u8, id, "random")) {
        try body.put("quote", data.string(random_quote.quote));
        try body.put("author", data.string(random_quote.author));
    } else {
        try body.put("quote", data.string("If you can dream it, you can achieve it."));
        try body.put("author", data.string("Zig Ziglar"));
    }

    return request.render(.ok);
}

pub fn post(request: *jetzig.Request, data: *jetzig.Data) !jetzig.View {
    var root = try data.object();
    const params = try request.params();
    try root.put("param", params.get("foo").?);

    return request.render(.ok);
}

const Quote = struct {
    quote: []const u8,
    author: []const u8,
};

// Quotes taken from: https://gist.github.com/natebass/b0a548425a73bdf8ea5c618149fe1fce
fn randomQuote(allocator: std.mem.Allocator) !Quote {
    const path = "src/app/config/quotes.json";
    const stat = try std.fs.cwd().statFile(path);
    const json = try std.fs.cwd().readFileAlloc(allocator, path, @intCast(stat.size));
    const quotes = try std.json.parseFromSlice([]Quote, allocator, json, .{});
    return quotes.value[std.crypto.random.intRangeLessThan(usize, 0, quotes.value.len)];
}

test "get" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();

    const response = try app.request(.GET, "/quotes/initial", .{});
    try response.expectBodyContains("If you can dream it, you can achieve it.");
}
