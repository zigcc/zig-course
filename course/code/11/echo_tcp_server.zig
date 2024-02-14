const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const windows = std.os.windows;

// #region poll
const poll =
    if (builtin.os.tag == .windows)
    // 如果是 windows，则调用 std.os.windows.poll
    // 它是对 WSAPoll 的封装
    std.os.windows.poll
else if (builtin.os.tag == .linux)
    // 如果是 linux，则调用 std.os.linux.poll
    // 它是对 系统调用 poll 的封装
    std.os.linux.poll
else
    @compileError("not support current system");
// #endregion poll

// #region pollfd
const pollfd =
    if (builtin.os.tag == .windows)
    // 如果是 windows
    std.os.windows.ws2_32.pollfd
else if (builtin.os.tag == .linux)
    // 如果是 linux
    std.os.linux.pollfd
else
    @compileError("not support current system");
// #endregion pollfd

// 以下定义的是poll的事件类型，在windows和linux下的值是不一样的
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

// 以下定义的是socket的无效值，在windows和linux下的值是不一样的
const INVALID_SOCKET =
    if (builtin.os.tag == .windows)
    std.os.windows.ws2_32.INVALID_SOCKET
else if (builtin.os.tag == .linux)
    -1
else
    @compileError("not support current system");

pub fn main() !void {
    // #region listen
    // 解析地址
    const address = try net.Address.parseIp4("127.0.0.1", 8080);
    // 初始化一个server，这里就包含了 socket() 和 bind() 两个过程
    var server = net.StreamServer.init(net.StreamServer.Options{ .reuse_port = true });
    defer server.deinit();
    // 开始listen
    try server.listen(address);
    // #endregion listen

    // #region data
    // 定义最大连接数
    const max_sockets = 1000;
    // buffer 用于存储 client 发过来的数据
    var buf: [1024]u8 = std.mem.zeroes([1024]u8);
    // 存储 accept 拿到的 connections
    var connections: [max_sockets]?net.StreamServer.Connection = undefined;
    // sockfds 用于存储 pollfd, 用于传递给 poll 函数
    var sockfds: [max_sockets]pollfd = undefined;
    // #endregion data
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

    // 无限循环，等待客户端连接或者已连接的客户端发送数据
    while (true) {
        // 调用 poll，nums 是返回的事件数量
        var nums = poll(&sockfds, max_sockets, -1);
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
            if (nums == 0) {
                break;
            }
            const sockfd = sockfds[i];
            // 检查是否是无效的 socket
            if (sockfd.fd == INVALID_SOCKET) {
                continue;
            }
            // 检查是否是 POLLIN 事件，即是否有数据可读
            if (sockfd.revents & (POLLIN) != 0) {
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
                        sockfds[i].fd = INVALID_SOCKET;
                        connections[i] = null;
                        std.log.info("client {} close", .{i});
                    } else {
                        // 如果读取到了数据，那么将数据写回去
                        _ = try connection.stream.write(buf[0..len]);
                    }
                }
            }
            // 检查是否是 POLLNVAL | POLLERR | POLLHUP 事件，即是否有错误发生，或者连接断开
            else if (sockfd.revents & (POLLNVAL | POLLERR | POLLHUP) != 0) {
                // 将 pollfd 和 connection 置为无效
                sockfds[i].fd = INVALID_SOCKET;
                connections[i] = null;
                std.log.info("client {} close", .{i});
            }

            // 处理完一个事件，nums 减一
            // 这里的 nums 是 poll 返回的事件数量
            nums -= 1;
        }
        // #endregion exist-connections

        // #region new-connection
        // 检查是否有新的连接
        // 这里的 sockfds[0] 是 server 的 pollfd
        // 这里的 nums 检查可有可无，因为我们只关心是否有新的连接，POLLIN 就足够了
        if (sockfds[0].revents & POLLIN != 0 and nums > 0) {
            // 如果有新的连接，那么调用 accept
            const client = try server.accept();
            for (1..max_sockets) |i| {
                // 找到一个空的 pollfd，将新的连接放进去
                if (sockfds[i].fd == INVALID_SOCKET) {
                    sockfds[i].fd = client.stream.handle;
                    connections[i] = client;
                    std.log.info("new client {} comes", .{i});
                    break;
                }
                // 如果没有找到空的 pollfd，那么说明连接数已经达到了最大值
                if (i == max_sockets) {
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
