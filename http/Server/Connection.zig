const http = @import("../root.zig");
const std = @import("std");

const Socket = @import("Socket/root.zig");
const This = @This();

addr: *const std.Io.net.IpAddress,
socket: *const Socket,
reader: *std.Io.Reader,

// TODO: these need to be configurable
const TARGET_MAX = 2048;

// TODO: The allocator here is used under many layers of abstraction. First the
// std.mem.Allocator itself, then under various writers. I wish I could collapse
// into just one abstraction. Maybe use an arena.. anything to speed this up as
// I imagine allocation is going to be a primary bottleneck as this gets faster.
pub fn start(self: *This, alloc: std.mem.Allocator) !void {
    while (try self.handle(alloc)) {}
}

// TODO: this should have a minute-long timeout, reset at the first read
fn handle(self: *This, alloc: std.mem.Allocator) !bool {
    // This could cause problems in the future if max_len increases as requests
    // can be extremely short. Also fill requires the reader to be buffered at
    // least as long as the amount you are filling.
    try self.reader.fill(http.Method.max_len + 1);
    const old = self.socket.io.swapCancelProtection(.blocked);
    defer _ = self.socket.io.swapCancelProtection(old);

    const method = try self.get_method();
    const target = try self.get_target(alloc);
    defer alloc.free(target);

    // "HTTP/1.0\r" is 9 long
    try self.reader.fill(9);
    const version = try self.get_version();

    std.log.debug(
        \\{} "{s}" {}
    , .{ method, target, version });

    return true;
}

fn get_method(self: *This) !http.Method {
    const str = try self.reader.takeDelimiter(' ') orelse
        return error.Malformed;
    return http.Method.from(str) orelse
        return error.UnknownMethod;
}

fn get_target(self: *This, alloc: std.mem.Allocator) ![]const u8 {
    var writer = std.Io.Writer.Allocating.init(alloc);
    errdefer writer.deinit();

    const n = self.reader.streamDelimiterLimit(
        &writer.writer,
        ' ',
        .limited(TARGET_MAX),
    ) catch |err| return switch (err) {
        error.StreamTooLong => error.UriTooLong,
        else => err,
    };

    _ = try self.reader.takeByte();
    if (n == 0) return error.Malformed;

    return writer.toOwnedSlice();
}

fn get_version(self: *This) !http.Version {
    const str = try self.reader.takeDelimiter('\r') orelse
        return error.Malformed;
    if (try self.reader.takeByte() != '\n')
        return error.Malformed;
    return http.Version.from(str) orelse
        return error.UnknownVersion;
}
