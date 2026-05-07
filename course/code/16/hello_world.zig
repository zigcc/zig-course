pub fn main(init: std.process.Init) !void {
    try One.main();
    try Two.main(init.io);
    try Three.main(init.io);
}

const std = @import("std");

const One = struct {
    // #region one
    pub fn main() !void {
        std.debug.print("Hello, World!\n", .{});
    }
    // #endregion one
};

const Two = struct {
    // #region two
    pub fn main(io: std.Io) !void {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
        const stdout = &stdout_writer.interface;

        var stderr_buffer: [1024]u8 = undefined;
        var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
        const stderr = &stderr_writer.interface;

        try stdout.print("Hello {s}!\n", .{"out"});
        try stderr.print("Hello {s}!\n", .{"err"});

        try stdout.flush();
        try stderr.flush();
    } // #endregion two
};

const Three = struct {
    // #region three
    pub fn main(io: std.Io) !void {
        // 定义两个缓冲区
        var stdout_buffer: [1024]u8 = undefined; // [!code focus]
        var stderr_buffer: [1024]u8 = undefined; // [!code focus]

        // 获取writer句柄// [!code focus]
        var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
        const stdout = &stdout_writer.interface;

        // 获取writer句柄// [!code focus]
        var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
        const stderr = &stderr_writer.interface;

        // 通过句柄写入buffer// [!code focus]
        try stdout.print("Hello {s}!\n", .{"out"}); // [!code focus]
        try stderr.print("Hello {s}!\n", .{"err"}); // [!code focus]

        // 尝试刷新buffer// [!code focus]
        try stdout.flush(); // [!code focus]
        try stderr.flush(); // [!code focus]
    }
    // #endregion three
};
