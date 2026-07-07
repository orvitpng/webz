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

    var buf: [1][]u8 = .{reader.buffer[reader.end..]};
    const vec = if (data[0].len == 0) &buf else data;
    const n = self.socket.read_vec(vec) catch |err| {
        self.err = err;
        return error.ReadFailed;
    };

    if (n == 0) return error.EndOfStream;
    if (data[0].len == 0) reader.end += n;
    return n;
}
