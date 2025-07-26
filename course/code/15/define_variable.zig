// #region top-level
//! 顶层文档注释
//! 顶层文档注释

const S = struct {
    //! 顶层文档注释
};
// #endregion top-level

pub fn main() !void {
    _ = Timestamp{
        .seconds = 0,
        .nanos = 0,
    };
    DefineVar.main();
    Const.main();
    Undefined.main();
    UseUndefined.main();
    Block.main();
}

// #region doc-comment
/// 存储时间戳的结构体，精度为纳秒
/// (像这里就是多行文档注释)
const Timestamp = struct {
    /// 自纪元开始后的秒数 (此处也是一个文档注释).
    seconds: i64, // 我们可以以此代表1970年前 (此处是普通注释)

    /// 纳秒数 (文档注释).
    nanos: u32,

    /// 返回一个 Timestamp 结构体代表 unix 纪元;
    /// 1970年 1月1日 00:00:00 UTC (文档注释).
    pub fn unixEpoch() Timestamp {
        return Timestamp{
            .seconds = 0,
            .nanos = 0,
        };
    }
};
// #endregion doc-comment

const DefineVar = struct {
    // #region define
    const std = @import("std");

    pub fn main() void {
        // 声明变量 variable 类型为u16, 并指定值为 666
        var variable: u16 = 0;
        variable = 666;

        std.debug.print("变量 variable 是{}\n", .{variable});
    }
    // #endregion define
};

const Const = struct {
    // #region const
    const std = @import("std");

    pub fn main() void {
        const constant: u16 = 666;

        std.debug.print("常量 constant 是{}\n", .{constant});
    }
    // #endregion const
};

const Undefined = struct {
    // #region undefined
    const std = @import("std");

    pub fn main() void {
        var variable: u16 = undefined;

        variable = 666;

        std.debug.print("变量 variable 是{}\n", .{variable});
    }
    // #endregion undefined
};

const UseUndefined = struct {
    // #region use-undefined
    const std = @import("std");

    // 填充连续递增的数字
    // 注意该函数中并没有对 output 进行读操作，所以 output 的初始值不重要
    fn iota(init: u8, output: []u8) void {
        for (output, init..) |*e, v| {
            e.* = @intCast(v);
        }
    }

    pub fn main() void {
        // buffer 定义时不需要初始化
        var buffer: [8]u8 = undefined;

        // 因为 iota() 会为 buffer 里的元素赋值
        iota(7, &buffer);

        // 输出 { 7, 8, 9, 10, 11, 12, 13, 14 }
        std.debug.print("{any}\n", .{buffer});
    }
    // #endregion use-undefined
};

// #region identifier
const @"identifier with spaces in it" = 0xff;
const @"1SmallStep4Man" = 112358;

const c = @import("std").c;
pub extern "c" fn @"error"() void;
pub extern "c" fn @"fstat$INODE64"(fd: c.fd_t, buf: *c.Stat) c_int;

const Color = enum {
    red,
    @"really red",
};
const color: Color = .@"really red";
// #endregion identifier

const Block = struct {
    pub fn main() void {
        // #region block
        var y: i32 = 123;

        const x = blk: {
            y += 1;
            break :blk y;
        };
        // #endregion block
        _ = x;
    }
};

const Deconstruct = struct {
    fn main() void {
        // #region deconstruct
        const print = @import("std").debug.print;
        var x: u32 = undefined;
        var y: u32 = undefined;
        var z: u32 = undefined;
        // 元组
        const tuple = .{ 1, 2, 3 };
        // 解构元组
        x, y, z = tuple;

        print("tuple: x = {}, y = {}, z = {}\n", .{ x, y, z });
        // 数组
        const array = [_]u32{ 4, 5, 6 };
        // 解构数组
        x, y, z = array;

        print("array: x = {}, y = {}, z = {}\n", .{ x, y, z });
        // 向量定义
        const vector: @Vector(3, u32) = .{ 7, 8, 9 };
        // 解构向量
        x, y, z = vector;

        print("vector: x = {}, y = {}, z = {}\n", .{ x, y, z });
        // #endregion deconstruct

    }
};

const Deconstruct_2 = struct {
    pub fn main() !void {
        // #region deconstruct_2
        const print = @import("std").debug.print;
        var x: u32 = undefined;

        const tuple = .{ 1, 2, 3 };

        x, var y: u32, const z = tuple;

        print("x = {}, y = {}, z = {}\n", .{ x, y, z });

        // y 可变
        y = 100;

        // 可以用 _ 丢弃不想要的值
        _, x, _ = tuple;

        print("x = {}", .{x});
        // #endregion deconstruct_2
    }
};

const ThreadLocal = struct {
    // #region threadlocal
    const std = @import("std");
    threadlocal var x: i32 = 1234;

    fn main() !void {
        const thread1 = try std.Thread.spawn(.{}, testTls, .{});
        const thread2 = try std.Thread.spawn(.{}, testTls, .{});
        testTls();
        thread1.join();
        thread2.join();
    }

    fn testTls() void {
        // 1234
        std.debug.print("x is {}\n", .{x});
        x += 1;
        // 1235
        std.debug.print("x is {}\n", .{x});
    }
    // #endregion threadlocal
};
