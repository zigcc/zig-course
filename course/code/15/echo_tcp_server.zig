const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const windows = std.os.windows;
const linux = std.os.linux;

// POLLIN, POLLERR, POLLHUP, POLLNVAL 均是 poll 的事件

/// windows context 定义
const windows_context = struct {
    const POLLIN: i16 = 0x0100;
    const POLLERR: i16 = 0x0001;
    const POLLHUP: i16 = 0x0002;
    const POLLNVAL: i16 = 0x0004;
    const INVALID_SOCKET = windows.ws2_32.INVALID_SOCKET;
};

/// linux context 定义
const linux_context = struct {
    const POLLIN: i16 = 0x0001;
    const POLLERR: i16 = 0x0008;
    const POLLHUP: i16 = 0x0010;
    const POLLNVAL: i16 = 0x0020;
    const INVALID_SOCKET = -1;
};

/// macOS context 定义
const macos_context = struct {
    const POLLIN: i16 = 0x0001;
    const POLLERR: i16 = 0x0008;
    const POLLHUP: i16 = 0x0010;
    const POLLNVAL: i16 = 0x0020;
    const INVALID_SOCKET = -1;
};

const context = switch (builtin.os.tag) {
    .windows => windows_context,
    .linux => linux_context,
    .macos => macos_context,
    else => @compileError("unsupported os"),
};

pub fn main() !void {
    // #region listen
    // 解析地址
    const port = 8080;
    const address = try net.Address.parseIp4("127.0.0.1", port);
    // 初始化一个server，这里就包含了 socket() 和 bind() 两个过程
    var server = try address.listen(.{ .reuse_port = true });
    defer server.deinit();
    // #endregion listen

    // #region data
    // 定义最大连接数
    const max_sockets = 1000;
    // buffer 用于存储 client 发过来的数据
    var buf: [1024]u8 = std.mem.zeroes([1024]u8);
    // 存储 accept 拿到的 connections
    var connections: [max_sockets]?net.Server.Connection = undefined;
    // sockfds 用于存储 pollfd, 用于传递给 poll 函数
    var sockfds: [max_sockets]if (builtin.os.tag == .windows)
        windows.ws2_32.pollfd
    else
        std.posix.pollfd = undefined;
    // #endregion data
    for (0..max_sockets) |i| {
        sockfds[i].fd = context.INVALID_SOCKET;
        sockfds[i].events = context.POLLIN;
        connections[i] = null;
    }
    sockfds[0].fd = server.stream.handle;

    std.log.info("start listening at {d}...", .{port});

    // 无限循环，等待客户端连接或者已连接的客户端发送数据
    while (true) {
        // 调用 poll，nums 是返回的事件数量
        var nums = if (builtin.os.tag == .windows) windows.poll(&sockfds, max_sockets, -1) else try std.posix.poll(&sockfds, -1);
        if (nums == 0) {
            continue;
        }
        // 如果返回的事件数量小于0，说明出错了
        // 仅仅在 windows 下会出现这种情况
        if (nums < 0) {
            @panic("An error occurred in poll");
        }

        // NOTE: 值得注意的是，我们使用的模型是先处理已连接的客户端，再处理新连接的客户端

        // #region exist-connections
        // 遍历所有的连接，处理事件
        for (1..max_sockets) |i| {
            // 这里的 nums 是 poll 返回的事件数量
            // 在windows下，WSApoll允许返回0，未超时且没有套接字处于指定的状态
            if (nums == 0) {
                break;
            }
            const sockfd = sockfds[i];

            // 检查是否是无效的 socket
            if (sockfd.fd == context.INVALID_SOCKET) {
                continue;
            }

            // 由于 windows 针对无效的socket也会触发POLLNVAL
            // 当前 sock 有 IO 事件时，处理完后将 nums 减一
            defer if (sockfd.revents != 0) {
                nums -= 1;
            };

            // 检查是否是 POLLIN 事件，即是否有数据可读
            if (sockfd.revents & (context.POLLIN) != 0) {
                const c = connections[i];
                if (c) |connection| {
                    const len = try connection.stream.read(&buf);
                    // 如果连接已经断开，那么关闭连接
                    // 这是因为如果已经 close 的连接，读取的时候会返回0
                    if (len == 0) {
                        // 但为了保险起见，我们还是调用 close
                        // 因为有可能是连接没有断开，但是出现了错误
                        connection.stream.close();
                        // 将 pollfd 和 connection 置为无效
                        sockfds[i].fd = context.INVALID_SOCKET;
                        std.log.info("client from {any} close!", .{
                            connection.address,
                        });
                        connections[i] = null;
                    } else {
                        // 如果读取到了数据，那么将数据写回去
                        // 但仅仅这样写一次并不安全
                        // 最优解应该是使用for循环检测写入的数据大小是否等于buf长度
                        // 如果不等于就继续写入
                        // 这是因为 TCP 是一个面向流的协议
                        // 它并不保证一次 write 调用能够发送所有的数据
                        // 作为示例，我们不检查是否全部写入
                        _ = try connection.stream.write(buf[0..len]);
                    }
                }
            }
            // 检查是否是 POLLNVAL | POLLERR | POLLHUP 事件，即是否有错误发生，或者连接断开
            else if ((sockfd.revents &
                (context.POLLNVAL | context.POLLERR | context.POLLHUP)) != 0)
            {
                // 将 pollfd 和 connection 置为无效
                sockfds[i].fd = context.INVALID_SOCKET;
                connections[i] = null;
                std.log.info("client {} close", .{i});
            }
        }
        // #endregion exist-connections

        // #region new-connection
        // 检查是否有新的连接
        // 这里的 sockfds[0] 是 server 的 pollfd
        // 这里的 nums 检查可有可无，因为我们只关心是否有新的连接，POLLIN 就足够了
        if (sockfds[0].revents & context.POLLIN != 0 and nums > 0) {
            std.log.info("new client", .{});
            // 如果有新的连接，那么调用 accept
            const client = try server.accept();
            for (1..max_sockets) |i| {
                // 找到一个空的 pollfd，将新的连接放进去
                if (sockfds[i].fd == context.INVALID_SOCKET) {
                    sockfds[i].fd = client.stream.handle;
                    connections[i] = client;
                    std.log.info("new client {} comes", .{i});
                    break;
                }
                // 如果没有找到空的 pollfd，那么说明连接数已经达到了最大值
                if (i == max_sockets - 1) {
                    @panic("too many clients");
                }
            }
        }
        // #endregion new-connection
    }

    if (builtin.os.tag == .windows) {
        try windows.ws2_32.WSACleanup();
    }
}
