const std = @import("std");

pub const Reader = @import("Reader.zig");

const This = @This();

io: std.Io,
handle: std.Io.net.Socket.Handle,

pub fn reader(self: *const This, buf: []u8) Reader {
    return .{
        .socket = self,
        .face = .{
            .vtable = &.{
                .stream = &Reader.stream,
                .readVec = &Reader.read_vec,
            },
            .buffer = buf,
            .seek = 0,
            .end = 0,
        },
    };
}

pub fn read_vec(self: *const This, vec: [][]u8) !usize {
    return self.io.vtable.netRead(self.io.userdata, self.handle, vec);
}

pub fn write_vec_all(self: *const This, vec: []const []const u8) !void {
    var i: usize = 0;
    var j: usize = 0;

    while (i < vec.len) {
        const left = vec[i + 1 ..];
        j += try if (left.len == 0)
            self.io.vtable.netWrite(
                self.io.userdata,
                self.handle,
                vec[i][j..],
                &.{},
                0,
            )
        else
            self.io.vtable.netWrite(
                self.io.userdata,
                self.handle,
                vec[i][j..],
                left,
                1,
            );

        while (i < vec.len and j >= vec[i].len) {
            j -= vec[i].len;
            i += 1;
        }
    }
}

pub fn discard_all(self: *const This, buf: []u8) !void {
    var vec: [1][]u8 = .{buf};
    while (try self.io.vtable.netRead(
        self.io.userdata,
        self.handle,
        &vec,
    ) != 0) {}
}

pub fn shutdown(self: *const This, how: std.Io.net.ShutdownHow) !void {
    try self.io.vtable.netShutdown(self.io.userdata, self.handle, how);
}

pub fn close(self: *const This) void {
    self.io.vtable.netClose(self.io.userdata, (&self.handle)[0..1]);
}
