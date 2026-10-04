const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const net = Io.net;

pub fn main() !void {
    // #region listen
    // 初始化 Threaded I/O 后端（单线程模式）
    var threaded: Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    const io = threaded.io();

    // 解析地址并监听
    const port: u16 = 8080;
    const address: net.IpAddress = .{ .ip4 = .loopback(port) };

    // 初始化一个server，这里就包含了 socket() 和 bind() 两个过程
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    // #endregion listen

    std.log.info("start listening at {d}...", .{port});

    // 无限循环，等待客户端连接
    while (true) {
        // #region new-connection
        // 等待新的连接
        std.log.info("waiting for client...", .{});
        const stream = try server.accept(io);
        std.log.info("new client connected!", .{});
        // #endregion new-connection

        // #region exist-connections
        // 处理客户端数据（简化版本：一次处理一个客户端）
        // 初始化读写缓冲区
        var read_buffer: [4096]u8 = undefined;
        var write_buffer: [4096]u8 = undefined;
        var reader = stream.reader(io, &read_buffer);
        var writer = stream.writer(io, &write_buffer);

        while (true) {
            // 读取客户端发送的数据
            // 使用 peekGreedy(1) 获取至少 1 字节，返回所有可用数据
            const data = reader.interface.peekGreedy(1) catch |err| {
                if (err == error.EndOfStream) {
                    std.log.info("client disconnected", .{});
                    break;
                }
                if (reader.err) |read_err| {
                    std.log.err("read error: {}", .{read_err});
                }
                break;
            };

            if (data.len == 0) {
                std.log.info("client disconnected", .{});
                break;
            }

            // 消费已读取的数据
            reader.interface.toss(data.len);

            // 将数据写回给客户端（echo）
            writer.interface.writeAll(data) catch |err| {
                std.log.err("write error: {}", .{err});
                if (writer.err) |write_err| {
                    std.log.err("underlying error: {}", .{write_err});
                }
                break;
            };
            writer.interface.flush() catch |err| {
                std.log.err("flush error: {}", .{err});
                break;
            };
        }

        stream.close(io);
        // #endregion exist-connections
    }
}
