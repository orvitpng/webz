const std = @import("std");

handle: std.Io.net.Socket.Handle,

pub fn write_vec(self: @This(), io: std.Io, vec: []const []const u8) !void {
    var i: usize = 0;
    var j: usize = 0;

    while (i < vec.len) {
        const left = vec[i + 1 ..];
        j += try if (left.len == 0)
            io.vtable.netWrite(io.userdata, self.handle, vec[i][j..], &.{}, 0)
        else
            io.vtable.netWrite(io.userdata, self.handle, vec[i][j..], left, 1);

        while (i < vec.len and j >= vec[i].len) {
            j -= vec[i].len;
            i += 1;
        }
    }
}

pub fn discard(self: @This(), io: std.Io, buf: []u8) !void {
    var vec: [1][]u8 = .{buf};
    while (try io.vtable.netRead(io.userdata, self.handle, &vec) != 0) {}
}

pub fn shutdown(self: @This(), io: std.Io, how: std.Io.net.ShutdownHow) !void {
    try io.vtable.netShutdown(io.userdata, self.handle, how);
}

pub fn close(self: @This(), io: std.Io) void {
    io.vtable.netClose(io.userdata, (&self.handle)[0..1]);
}
