const http = @import("../root.zig");
const std = @import("std");

const Socket = @import("Socket/root.zig");
const This = @This();

addr: *const std.Io.net.IpAddress,
socket: *const Socket,
reader: *std.Io.Reader,

// TODO: again, these need to be configurable
const TARGET_MAX = 16;

pub fn handle(self: *This, alloc: std.mem.Allocator, buf: []u8) !void {
    _ = buf;

    while (true) {
        self.reader.fill(http.Method.max_len + 1) catch |err|
            return switch (err) {
                error.EndOfStream => {},
                else => err,
            };

        // TODO: io probably should be gotten otherwise
        const old = self.socket.io.swapCancelProtection(.blocked);
        defer _ = self.socket.io.swapCancelProtection(old);

        if (try self.request(alloc)) return;
    }
}

fn request(self: *This, alloc: std.mem.Allocator) !bool {
    const method = blk: {
        const str = try self.reader.takeDelimiter(' ') orelse
            return error.Malformed;
        break :blk http.Method.from(str) orelse
            return error.UnknownMethod;
    };

    // TODO: starting to get slightly out of hand
    const version, const slice, const target = blk: {
        var writer = std.Io.Writer.Allocating.init(alloc);
        errdefer writer.deinit();

        const target = self.reader.streamDelimiterLimit(
            &writer.writer,
            ' ',
            .limited(TARGET_MAX),
        ) catch |err| return switch (err) {
            error.StreamTooLong => error.UriTooLong,
            else => err,
        };
        _ = try self.reader.takeByte();

        const version = try self.reader.take(http.Version.max_len);

        const slice = try writer.toOwnedSlice();
        break :blk .{
            http.Version.from(version) orelse
                return error.UnknownVersion,
            slice,
            slice[0..target],
        };
    };
    defer alloc.free(slice);

    std.log.debug(
        \\version: {s}
        \\method: {s}
        \\target: {s}
    , .{ @tagName(version), @tagName(method), target });

    return false;
}
