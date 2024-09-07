pub fn main() !void {
    Basic.main();
    try Advanced.main();
    Expression.main();
    Catch_tagUnion.main();
    AutoRefer.main();
}

const Basic = struct {
    // #region basic_more
    const std = @import("std");
    const print = std.debug.print;

    pub fn main() void {
        // #region basic
        const num: u8 = 5;
        switch (num) {
            5 => {
                print("this is 5\n", .{});
            },
            else => {
                print("this is not 5\n", .{});
            },
        }
        // #endregion basic
    }
    // #endregion basic_more
};

const Advanced = struct {
    const std = @import("std");
    const expect = std.testing.expect;
    pub fn main() !void {
        // #region advanced
        const a: u64 = 10;
        const zz: u64 = 103;

        // 作为表达式使用
        const b = switch (a) {
            // 多匹配项
            1, 2, 3 => 0,

            // 范围匹配
            5...100 => 1,

            // tag形式的分配匹配，可以任意复杂
            101 => blk: {
                const c: u64 = 5;
                // 下一行代表返回到blk这个tag处
                break :blk c * 2 + 1;
            },

            zz => zz,
            // 支持编译期运算
            blk: {
                const d: u32 = 5;
                const e: u32 = 100;
                break :blk d + e;
            } => 107,

            // else 匹配剩余的分支
            else => 9,
        };

        try expect(b == 1);
        // #endregion advanced
    }
};

const Expression = struct {
    // #region expression_more
    const builtin = @import("builtin");

    pub fn main() void {
        // #region expression
        const os_msg = switch (builtin.target.os.tag) {
            .linux => "we found a linux user",
            else => "not a linux user",
        };
        // #endregion expression
        _ = os_msg;
    }
    // #endregion expression_more
};

const Catch_tagUnion = struct {
    const std = @import("std");
    pub fn main() void {
        // #region catch_tag_union
        // 定义两个结构体
        const Point = struct {
            x: u8,
            y: u8,
        };
        const Item = union(enum) {
            a: u32,
            c: Point,
            d,
            e: u32,
        };

        var a = Item{ .c = Point{ .x = 1, .y = 2 } };

        const b = switch (a) {
            // 多个匹配
            Item.a, Item.e => |item| item,

            // 可以使用 * 语法来捕获对应的指针进行修改操作
            Item.c => |*item| blk: {
                item.*.x += 1;
                break :blk 6;
            },

            // 这里最后一个联合类型,匹配已经穷尽了，我们就不需要使用else了
            Item.d => 8,
        };

        std.debug.print("{any}\n", .{b});
        // #endregion catch_tag_union
    }
};

const AutoRefer = struct {
    pub fn main() void {
        // #region auto_refer
        const Color = enum {
            auto,
            off,
            on,
        };
        const color = Color.off;
        // 编译器会帮我们完成其余的工作
        const result = switch (color) {
            .auto => false,
            .on => false,
            .off => true,
        };
        // #endregion auto_refer

        _ = result;
    }
};

// #region isFieldOptional
// 这段函数用来判断一个结构体的字段是否是 optional，同时它也是 comptime 的
// 故我们可以在下面使用inline 来要求编译器帮我们展开这个switch
fn isFieldOptional(comptime T: type, field_index: usize) !bool {
    const fields = @typeInfo(T).Struct.fields;
    return switch (field_index) {
        // 这里每次都是不同的值
        inline 0...fields.len - 1 => |idx| {
            return @typeInfo(fields[idx].type) == .Optional;
        },
        else => return error.IndexOutOfBounds,
    };
}
// #endregion isFieldOptional

// #region withSwitch
const AnySlice = union(enum) {
    a: u8,
    b: i8,
    c: bool,
    d: []u8,
};

fn withSwitch(any: AnySlice) usize {
    return switch (any) {
        // 这里的 slice 可以匹配所有的 Anyslice 类型
        inline else => |slice| _ = slice,
    };
}
// #endregion withSwitch

// #region catch_tag_union_value
const U = union(enum) {
    a: u32,
    b: f32,
};

fn getNum(u: U) u32 {
    switch (u) {
        // 这里 num 是一个运行时可知的值
        // 而 tag 则是对应的标签名，这是编译期可知的
        inline else => |num, tag| {
            if (tag == .b) {
                return @intFromFloat(num);
            }
            return num;
        },
    }
}
// #endregion catch_tag_union_value
