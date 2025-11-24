pub fn main() !void {
    try One.main();
    try Two.main();
    try Three.main();
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
    pub fn main() !void {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;

        var stderr_buffer: [1024]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        const stderr = &stderr_writer.interface;

        try stdout.print("Hello {s}!\n", .{"out"});
        try stderr.print("Hello {s}!\n", .{"err"});

        try stdout.flush();
        try stderr.flush();
    } // #endregion two
};

const Three = struct {
    // #region three
    const std = @import("std");
    pub fn main() !void {
        // 定义两个缓冲区
        var stdout_buffer: [1024]u8 = undefined; // [!code focus]
        var stderr_buffer: [1024]u8 = undefined; // [!code focus]

        // 获取writer句柄// [!code focus]
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;

        // 获取writer句柄// [!code focus]
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        const stderr = &stderr_writer.interface;

        // 通过句柄写入buffer// [!code focus]
        try stdout.print("Hello {s}!\n", .{"out"}); // [!code focus]
        try stderr.print("Hello {s}!\n", .{"err"}); // [!code focus]

        try stdout.flush();
        try stderr.flush();

        // 尝试刷新buffer// [!code focus]
        try stdout.flush(); // [!code focus]
        try stderr.flush(); // [!code focus]
    }
    // #endregion three
};
