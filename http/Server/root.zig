const http = @import("../root.zig");
const std = @import("std");

const Stream = @import("Stream.zig");
const This = @This();

pub const Connection = @import("Connection.zig");

server: std.Io.net.Server,
group: std.Io.Group = .init,
// TODO: with maturity, determine if this is needed
stopping: std.atomic.Value(bool) = .init(false),

pub fn listen(io: std.Io, address: std.Io.net.IpAddress) !This {
    return .{ .server = try address.listen(io, .{ .reuse_address = true }) };
}

pub fn start(self: *This, io: std.Io) !void {
    while (true) {
        const stream = self.server.accept(io) catch |err|
            return if (err == error.SocketNotListening and
                self.stopping.load(.monotonic))
            {} else err;
        try self.group.concurrent(io, connect, .{
            io,
            stream.socket.address,
            stream.socket.handle,
        });
    }
}

pub fn stop(self: *This, io: std.Io) void {
    self.stopping.store(true, .monotonic);
    self.server.deinit(io);
    self.group.cancel(io);
}

fn connect(
    io: std.Io,
    addr: std.Io.net.IpAddress,
    handle: std.Io.net.Socket.Handle,
) std.Io.Cancelable!void {
    var stream: Stream = .{ .handle = handle };
    defer stream.close(io);

    const conn: Connection = .{
        .address = &addr,
        .stream = &stream,
    };

    // TODO: I kind of hate this
    var buf: [4096]u8 = undefined;
    conn.handle(&buf) catch |err| {
        const status: http.Status = switch (err) {
            // error.Canceled => return err,
            else => blk: {
                std.log.err("handle: {s}", .{@errorName(err)});
                break :blk .server_error;
            },
        };

        _ = std.fmt.printInt(&buf, @intFromEnum(status), 10, .lower, .{});
        buf[3] = ' ';

        stream.write_vec(io, &.{
            "HTTP/1.1 ",
            buf[0..4],
            status.string(),
            "\r\n\r\n",
        }) catch return;
    };

    stream.shutdown(io, .send) catch return;
    stream.discard(io, &buf) catch return;
}
