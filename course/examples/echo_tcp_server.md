---
outline: deep
---

# Echo Tcp Server

我们来进行编写一个小小的示例———— Echo Tcp Server，帮助我们理解更多的内容。

> 代码一共也就一百行左右，简洁但不简单！

## 前置知识

### Socket

Socket（套接字）是计算机网络中用于实现不同计算机或同一台计算机上的不同进程之间的通信的一种技术。它提供了一种标准的 API，程序员可以使用这个 API 来编写网络应用程序。

一个Socket由三个部分组成：**协议**、**本地地址**和**远程地址**，协议决定了Socket的类型和通信方式，例如TCP或UDP，本地地址是Socket绑定的网络接口和端口号，远程地址是Socket连接的目标网络接口和端口号。

除了常见的 **TCP** 和 **UDP** 外，还有一种叫做 **Unix Socket**，用于在同一台机器上的不同进程间进行通信，并不使用网络协议栈，而是直接在内核中传递数据，比 TCP 和 UDP 更加高效。

### IO多路复用

**I/O 多路复用**是一种允许一个进程同时监视多个 I/O 通道（例如，*socket*、*文件描述符*等），并知道哪个通道可以进行读写操作的技术。这样，一个进程就可以同时处理多个 I/O 操作，而无需为每个 I/O 操作启动一个新的线程或进程。

> I/O 多路复用的主要优点是提高了程序的效率。如果没有 I/O 多路复用，程序可能需要为每个 I/O 操作创建一个新的线程或进程，这会消耗大量的系统资源。通过使用 I/O 多路复用，程序可以在一个单独的线程或进程中处理多个 I/O 操作，从而减少了系统资源的使用。

I/O 多路复用的常见实现包括 select、poll 和 epoll 等系统调用。这些系统调用允许程序指定一个文件描述符列表，并等待其中任何一个文件描述符准备好进行 I/O 操作。当一个或多个文件描述符准备好时，系统调用返回，程序就可以进行相应的读或写操作。

## 实战

本示例仅使用了 poll （POSIX标准之一）

```zig
const std = @import("std");
const net = std.net;
const windows = std.os.windows;
const posix = std.posix;

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

    var sockfds: [max_sockets]posix.windows.ws2_32.pollfd = undefined;
    var connections: [max_sockets]?net.StreamServer.Connection = undefined;

    var buf: [1024]u8 = std.mem.zeroes([1024]u8);

    for (0..max_sockets) |i| {
        sockfds[i].fd = posix.windows.ws2_32.INVALID_SOCKET;
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
        const nums = windows.poll(&sockfds, max_sockets, -1);
        if (nums == 0) {
            continue;
        }
        if (nums < 0) {
            @panic("An error occurred in poll");
        }

        for (1..max_sockets) |i| {
            const sockfd = sockfds[i];
            if (sockfd.fd == posix.windows.ws2_32.INVALID_SOCKET) {
                continue;
            }
            if (sockfd.revents & (POLLRDNORM) != 0) {
                const c = connections[i];
                if (c) |connection| {
                    const len = try connection.stream.read(&buf);
                    _ = try connection.stream.write(buf[0..len]);
                }
            } else if (sockfd.revents & (POLLNVAL | POLLERR | POLLHUP) != 0) {
                sockfds[i].fd = posix.windows.ws2_32.INVALID_SOCKET;
                connections[i] = null;
                std.log.info("client {} close", .{i});
            }
        }

        if (sockfds[0].revents & POLLRDNORM != 0) {
            const client = try server.accept();
            for (1..max_sockets) |i| {
                if (sockfds[i].fd == posix.windows.ws2_32.INVALID_SOCKET) {
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

    try posix.windows.ws2_32.WSACleanup();
}
```