const http = @import("../root.zig");
const std = @import("std");

const Socket = @import("Socket/root.zig");
const This = @This();

addr: *const std.Io.net.IpAddress,
socket: *const Socket,
reader: *std.Io.Reader,

pub fn handle(self: *This, buf: []u8) !void {
    _ = self;
    _ = buf;

    return error.Foo;
}
