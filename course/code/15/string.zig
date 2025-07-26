pub fn main() !void {
    StringType.main();
    String.main();
    MultilineString.main();
}

const StringType = struct {
    // #region string_type
    const print = @import("std").debug.print;
    pub fn main() void {
        const foo = "banana";
        print("{}\n", .{@TypeOf(foo)});
    }
    // #endregion string_type
};

const String = struct {
    // #region string
    const print = @import("std").debug.print;
    const mem = @import("std").mem; // 用于比较字节

    pub fn main() void {
        const bytes = "hello";
        print("{}\n", .{@TypeOf(bytes)}); // *const [5:0]u8
        print("{d}\n", .{bytes.len}); // 5
        print("{c}\n", .{bytes[1]}); // 'e'
        print("{d}\n", .{bytes[5]}); // 0
        print("{}\n", .{'e' == '\x65'}); // true
        print("{d}\n", .{'\u{1f4a9}'}); // 128169
        print("{d}\n", .{'💯'}); // 128175
        print("{u}\n", .{'⚡'});
        print("{}\n", .{mem.eql(u8, "hello", "h\x65llo")}); // true
        print("{}\n", .{mem.eql(u8, "💯", "\xf0\x9f\x92\xaf")}); // true
        const invalid_utf8 = "\xff\xfe"; // 非UTF-8 字符串可以使用\xNN.
        print("0x{x}\n", .{invalid_utf8[1]}); // 索引它们会返回独立的字节
        print("0x{x}\n", .{"💯"[1]});
    }
    // #endregion string
};

const MultilineString = struct {
    // #region multiline_string
    const print = @import("std").debug.print;

    pub fn main() void {
        const hello_world_in_c =
            \\#include <stdio.h>
            \\
            \\int main(int argc, char **argv) {
            \\    printf("hello world\n");
            \\    return 0;
            \\}
        ;
        print("{s}\n", .{hello_world_in_c});
    }
    // #endregion multiline_string
};

const PrintString = struct {
    // 注意：这个不用测试，因为它本来就是错误示例
    // #region print_string_err
    const std = @import("std");

    pub fn main() void {
        funnyPrint("banana");
    }

    fn funnyPrint(msg: []u8) void {
        std.debug.print("*farts*, {s}", .{msg});
    }
    // #endregion print_string_err
};

const DefineString = struct {
    // #region define_string
    const message_1 = "hello";
    const message_2 = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const message_3: []const u8 = &.{ 'h', 'e', 'l', 'l', 'o' };
    // #endregion define_string
};
