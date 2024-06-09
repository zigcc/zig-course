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

// #region indentifier
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
// #endregion indentifier

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
