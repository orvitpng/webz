const std = @import("std");

const Socket = @import("root.zig");
const This = @This();

socket: *const Socket,
face: std.Io.Reader,
err: ?std.Io.net.Stream.Reader.Error = null,

pub fn stream(
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
    limit: std.Io.Limit,
) std.Io.Reader.StreamError!usize {
    const buf = limit.slice(writer.unusedCapacitySlice());
    var vec: [1][]u8 = .{buf};

    const n = try read_vec(reader, &vec);
    writer.advance(n);
    return n;
}

pub fn read_vec(reader: *std.Io.Reader, data: [][]u8) std.Io.Reader.Error!usize {
    const self: *This = @fieldParentPtr("face", reader);
    const n = self.socket.read_vec(data) catch |err| {
        self.err = err;
        return error.ReadFailed;
    };

    if (n == 0) return error.EndOfStream;
    return n;
}
