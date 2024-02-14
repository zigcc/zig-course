const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const windows = std.os.windows;

const poll =
    if (builtin.os.tag == .windows)
    std.os.windows.poll
else if (builtin.os.tag == .linux)
    std.os.linux.poll
else
    @compileError("not support current system");

const pollfd =
    if (builtin.os.tag == .windows)
    std.os.windows.ws2_32.pollfd
else if (builtin.os.tag == .linux)
    std.os.linux.pollfd
else
    @compileError("not support current system");

const max_sockets = 1000;

const POLLIN: i16 =
    if (builtin.os.tag == .windows)
    0x0100
else if (builtin.os.tag == .linux)
    0x0001
else
    @compileError("not support current system");

const POLLERR: i16 =
    if (builtin.os.tag == .windows)
    0x0001
else if (builtin.os.tag == .linux)
    0x0008
else
    @compileError("not support current system");
const POLLHUP: i16 =
    if (builtin.os.tag == .windows)
    0x0002
else if (builtin.os.tag == .linux)
    0x0010
else
    @compileError("not support current system");

const POLLNVAL: i16 =
    if (builtin.os.tag == .windows)
    0x0004
else if (builtin.os.tag == .linux)
    0x0020
else
    @compileError("not support current system");

const INVALID_SOCKET =
    if (builtin.os.tag == .windows)
    std.os.windows.ws2_32.INVALID_SOCKET
else if (builtin.os.tag == .linux)
    -1
else
    @compileError("not support current system");

pub fn main() !void {
    const address = try net.Address.parseIp4("127.0.0.1", 8080);
    var server = net.StreamServer.init(net.StreamServer.Options{ .reuse_port = true });
    defer server.deinit();
    try server.listen(address);

    var buf: [1024]u8 = std.mem.zeroes([1024]u8);
    var connections: [max_sockets]?net.StreamServer.Connection = undefined;
    var sockfds: [max_sockets]pollfd = undefined;

    for (0..max_sockets) |i| {
        sockfds[i].fd = INVALID_SOCKET;
        sockfds[i].events = POLLIN;
        connections[i] = null;
    }
    if (server.sockfd) |fd| {
        sockfds[0].fd = fd;
    } else {
        @panic("server socket is null");
    }

    std.log.info("start listening", .{});

    while (true) {
        var nums = poll(&sockfds, max_sockets, -1);
        if (nums == 0) {
            continue;
        }
        if (nums < 0) {
            @panic("An error occurred in poll");
        }

        for (1..max_sockets) |i| {
            if (nums == 0) {
                break;
            }
            const sockfd = sockfds[i];
            if (sockfd.fd == INVALID_SOCKET) {
                continue;
            }
            if (sockfd.revents & (POLLIN) != 0) {
                const c = connections[i];
                if (c) |connection| {
                    const len = try connection.stream.read(&buf);
                    if (len == 0) {
                        connection.stream.close();
                        sockfds[i].fd = INVALID_SOCKET;
                        connections[i] = null;
                        std.log.info("client {} close", .{i});
                    } else {
                        _ = try connection.stream.write(buf[0..len]);
                    }
                }
            } else if (sockfd.revents & (POLLNVAL | POLLERR | POLLHUP) != 0) {
                sockfds[i].fd = INVALID_SOCKET;
                connections[i] = null;
                std.log.info("client {} close", .{i});
            }

            nums -= 1;
        }

        if (sockfds[0].revents & POLLIN != 0 and nums > 0) {
            const client = try server.accept();
            for (1..max_sockets) |i| {
                if (sockfds[i].fd == INVALID_SOCKET) {
                    sockfds[i].fd = client.stream.handle;
                    connections[i] = client;
                    std.log.info("new client {} comes", .{i});
                    break;
                }
                if (i == max_sockets) {
                    @panic("too many clients");
                }
            }
        }
    }

    if (builtin.os.tag == .windows) {
        try windows.ws2_32.WSACleanup();
    }
}
