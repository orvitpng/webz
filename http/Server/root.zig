const http = @import("../root.zig");
const std = @import("std");

const Connection = @import("Connection.zig");
const Socket = @import("Socket/root.zig");
const This = @This();

server: std.Io.net.Server,
group: std.Io.Group = .init,

// TODO: this should be configurable
const BUF_SIZE = 4096;

pub fn listen(io: std.Io, address: std.Io.net.IpAddress) !This {
    return .{ .server = try address.listen(io, .{ .reuse_address = true }) };
}

pub fn start(self: *This, alloc: std.mem.Allocator, io: std.Io) !void {
    while (true) {
        const stream = self.server.accept(io) catch |err|
            return if (err == error.SocketNotListening) {} else err;
        try self.group.concurrent(io, handle, .{
            alloc,
            stream.socket.address,
            .{ .io = io, .handle = stream.socket.handle },
        });
    }
}

pub fn stop(self: *This, io: std.Io) void {
    self.server.deinit(io);
    self.group.cancel(io);
}

fn handle(
    alloc: std.mem.Allocator,
    addr: std.Io.net.IpAddress,
    socket: Socket,
) std.Io.Cancelable!void {
    defer socket.close();

    var buf: [BUF_SIZE]u8 = undefined;
    var reader = socket.reader(&buf);
    var conn = Connection{
        .addr = &addr,
        .reader = &reader.face,
        .socket = &socket,
    };

    conn.start(alloc) catch |err| {
        const status: http.Status =
            switch (get_err(&reader, err)) {
                error.Malformed,
                error.StreamTooLong,
                => .bad_request,
                error.UnknownMethod => .not_implemented,
                error.UriTooLong => .uri_too_long,
                error.UnknownVersion => .version_not_supported,

                error.Canceled => return error.Canceled,
                error.EndOfStream => return,

                else => blk: {
                    std.log.err("handle: {s}", .{@errorName(err)});
                    break :blk .server_error;
                },
            };

        const head = std.fmt.bufPrint(
            &buf,
            "HTTP/1.1 {d} ",
            .{@intFromEnum(status)},
        ) catch unreachable;
        socket.write_vec_all(&.{
            head,
            status.string(),
            "\r\n\r\n",
        }) catch return;
    };

    socket.shutdown(.send) catch return;
    // TODO: this should have a timeout
    socket.discard_all(&buf) catch return;
}

fn get_err(reader: *const Socket.Reader, err: anyerror) anyerror {
    return switch (err) {
        error.ReadFailed => reader.err.?,
        else => return err,
    };
}
