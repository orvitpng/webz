const http = @import("../root.zig");
const std = @import("std");

const Stream = @import("Stream.zig");

address: *const std.Io.net.IpAddress,
stream: *Stream,

pub fn handle(self: @This(), buffer: []u8) !void {
    _ = self;
    _ = buffer;

    return error.Foo;
}
