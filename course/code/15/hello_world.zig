pub fn main() !void {
    One.main();
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
        var stderr_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
        const stderr = &stderr_writer.interface;

        try stdout.print("Hello {s}!\n", .{"out"});
        try stderr.print("Hello {s}!\n", .{"err"});
        try stdout.flush();
        try stderr.flush();
    }
    // #endregion two
};

const Three = struct {
    // #region three
    const std = @import("std");

    pub fn main() !void {
        var stdout_buffer: [1024]u8 = undefined;
        var stderr_buffer: [1024]u8 = undefined;
        const out = std.fs.File.stdout().writer(&stdout_buffer); // [!code focus]
        const err = std.fs.File.stderr().writer(&stderr_buffer); // [!code focus]

        // 获取buffer// [!code focus]
        var out_buffer = std.io.bufferedWriter(out); // [!code focus]
        var err_buffer = std.io.bufferedWriter(err); // [!code focus]

        // 获取writer句柄// [!code focus]
        var out_writer = out_buffer.writer(); // [!code focus]
        var err_writer = err_buffer.writer(); // [!code focus]

        // 通过句柄写入buffer// [!code focus]
        try out_writer.print("Hello {s}!\n", .{"out"}); // [!code focus]
        try err_writer.print("Hello {s}!\n", .{"err"}); // [!code focus]

        // 尝试刷新buffer// [!code focus]
        try out_buffer.flush(); // [!code focus]
        try err_buffer.flush(); // [!code focus]
    }
    // #endregion three
};
