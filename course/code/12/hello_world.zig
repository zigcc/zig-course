pub fn main() !void {
    One.main();
    try Two.main();
    try Three.main();
}

const One = struct {
    // #region one
    const std = @import("std");

    pub fn main() void {
        std.debug.print("Hello, World!\n", .{});
    }
    // #endregion one
};

const Two = struct {
    // #region two
    const std = @import("std");

    pub fn main() !void {
        var out = std.io.getStdOut().writer();
        var err = std.io.getStdErr().writer();

        try out.print("Hello {s}!\n", .{"out"});
        try err.print("Hello {s}!\n", .{"err"});
    }
    // #endregion two
};

const Three = struct {
    // #region three
    const std = @import("std");

    pub fn main() !void {
        const out = std.io.getStdOut().writer(); // [!code focus]
        const err = std.io.getStdErr().writer(); // [!code focus]

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
