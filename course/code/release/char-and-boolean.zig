pub fn main() !void {
    CHAR.main();
    CHAR_ASCII.main();
}

const CHAR = struct {
    // #region char
    const print = @import("std").debug.print;

    pub fn main() void {
        const char: u8 = 'h';
        print("{c}\n", .{char});
    }
    // #endregion char
};

const CHAR_ASCII = struct {
    // #region char_ascii
    const print = @import("std").debug.print;

    pub fn main() void {
        const char: u8 = 'h';
        const char_num: u8 = 104;
        print("{c}\n", .{char});
        print("{c}\n", .{char_num});
    }
    // #endregion char_ascii
};
