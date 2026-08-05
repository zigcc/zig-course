// 三个 struct 各自包含一段文档片段，每段都是可以直接粘贴进 src/main.zig 的完整程序。
// 因此 std 的导入放在各 struct 内部，文件级不能再有 `const std`（否则 ambiguous reference）。
pub fn main(init: @import("std").process.Init) !void {
    try One.main();
    try Two.main(init);
    try Three.main(init);
}

const One = struct {
    // #region one
    const std = @import("std");

    pub fn main() !void {
        std.debug.print("Hello, World!\n", .{});
    }
    // #endregion one
};

const Two = struct {
    // #region two
    const std = @import("std");

    pub fn main(init: std.process.Init) !void {
        const io = init.io;

        // 传入长度为 0 的缓冲区，表示不缓冲，每次 print 都直接写出
        var stdout_writer = std.Io.File.stdout().writer(io, &.{});
        const stdout = &stdout_writer.interface;

        var stderr_writer = std.Io.File.stderr().writer(io, &.{});
        const stderr = &stderr_writer.interface;

        try stdout.print("Hello {s}!\n", .{"out"});
        try stderr.print("Hello {s}!\n", .{"err"});
    }
    // #endregion two
};

const Three = struct {
    // #region three
    const std = @import("std");

    pub fn main(init: std.process.Init) !void {
        const io = init.io;

        // 定义两个缓冲区
        var stdout_buffer: [1024]u8 = undefined; // [!code focus]
        var stderr_buffer: [1024]u8 = undefined; // [!code focus]

        // 获取 writer 句柄
        var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer); // [!code focus]
        const stdout = &stdout_writer.interface;

        var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer); // [!code focus]
        const stderr = &stderr_writer.interface;

        // 通过句柄写入 buffer
        try stdout.print("Hello {s}!\n", .{"out"});
        try stderr.print("Hello {s}!\n", .{"err"});

        // 把 buffer 中的内容真正刷出去
        try stdout.flush(); // [!code focus]
        try stderr.flush(); // [!code focus]
    }
    // #endregion three
};
