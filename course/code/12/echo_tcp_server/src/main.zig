const std = @import("std");
const net = std.net;
const windows = std.os.windows;

const max_sockets = 1000;
const POLLRDNORM: i16 = 0x0100;
const POLLERR: i16 = 0x0001;
const POLLHUP: i16 = 0x0002;
const POLLNVAL: i16 = 0x0004;

pub fn main() !void {
    const address = try net.Address.parseIp4("127.0.0.1", 8080);
    var server = net.StreamServer.init(net.StreamServer.Options{ .reuse_port = true });
    defer server.deinit();

    try server.listen(address);

    var sockfds: [max_sockets]windows.ws2_32.pollfd = undefined;
    var connections: [max_sockets]?net.StreamServer.Connection = undefined;

    var buf: [1024]u8 = std.mem.zeroes([1024]u8);

    for (0..max_sockets) |i| {
        sockfds[i].fd = windows.ws2_32.INVALID_SOCKET;
        sockfds[i].events = POLLRDNORM;
        connections[i] = null;
    }
    if (server.sockfd) |fd| {
        sockfds[0].fd = fd;
    } else {
        @panic("server socket is null");
    }

    std.log.info("start listening", .{});

    while (true) {
        var nums = windows.poll(&sockfds, max_sockets, -1);
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
            if (sockfd.fd == windows.ws2_32.INVALID_SOCKET) {
                continue;
            }
            if (sockfd.revents & (POLLRDNORM) != 0) {
                const c = connections[i];
                if (c) |connection| {
                    const len = try connection.stream.read(&buf);
                    if (len == 0) {
                        connection.stream.close();
                        sockfds[i].fd = windows.ws2_32.INVALID_SOCKET;
                        connections[i] = null;
                        std.log.info("client {} close", .{i});
                    } else {
                        _ = try connection.stream.write(buf[0..len]);
                    }
                }
            } else if (sockfd.revents & (POLLNVAL | POLLERR | POLLHUP) != 0) {
                sockfds[i].fd = windows.ws2_32.INVALID_SOCKET;
                connections[i] = null;
                std.log.info("client {} close", .{i});
            }

            nums -= 1;
        }

        if (sockfds[0].revents & POLLRDNORM != 0 and nums > 0) {
            const client = try server.accept();
            for (1..max_sockets) |i| {
                if (sockfds[i].fd == windows.ws2_32.INVALID_SOCKET) {
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

    try windows.ws2_32.WSACleanup();
}
