pub fn main() !void {
    try EnumSize.main();
    try EnumReference.main();
}

// #region basic_enum
const Type = enum {
    ok,
    not_ok,
};

const c = Type.ok;
// #endregion basic_enum

// #region enum_with_value
// 指定枚举的标记类型
// 现在我们可以在 u2 和 Value 这个枚举类型之中任意切换了
const Value = enum(u2) {
    zero,
    one,
    two,
};
// #endregion enum_with_value

// #region enum_with_value2
const Value2 = enum(u32) {
    hundred = 100,
    thousand = 1000,
    million = 1000000,
};

// 覆盖部分值
const Value3 = enum(u4) {
    a,
    b = 8,
    c,
    d = 4,
    e,
};
// #endregion enum_with_value2

// #region enum_with_method
const Suit = enum {
    clubs,
    spades,
    diamonds,
    hearts,

    pub fn isClubs(self: Suit) bool {
        return self == Suit.clubs;
    }
};
// #endregion enum_with_method

const EnumSize = struct {

    // #region enum_size
    const std = @import("std");
    const expect = std.testing.expect;
    const mem = std.mem;

    const Small = enum {
        one,
        two,
        three,
        four,
    };

    pub fn main() !void {
        try expect(@typeInfo(Small).Enum.tag_type == u2);
        try expect(@typeInfo(Small).Enum.fields.len == 4);
        try expect(mem.eql(u8, @typeInfo(Small).Enum.fields[1].name, "two"));
        try expect(mem.eql(u8, @tagName(Small.three), "three"));
    }
    // #endregion enum_size
};

const EnumReference = struct {
    // #region enum_reference
    const Color = enum {
        auto,
        off,
        on,
    };

    pub fn main() !void {
        const color1: Color = .auto; // 此处枚举进行了自动推断
        const color2 = Color.auto;
        _ = (color1 == color2); // 这里比较的结果是 true
    }
    // #endregion enum_reference
};

const Non_exhaustiveEnum = struct {
    // #region non_exhaustive_enum
    const Number = enum(u8) {
        one,
        two,
        three,
        _,
    };

    const number = Number.one;
    const result = switch (number) {
        .one => true,
        .two, .three => false,
        _ => false,
    };
    // result 是 true

    const is_one = switch (number) {
        .one => true,
        else => false,
    };
    // is_one 也是true
    // #endregion non_exhaustive_enum
};

const EnumLiteral_ = struct {
    const std = @import("std");
    pub fn main() !void {
        // #region enum_literal
        // 使用内建函数 @Type 构造出一个 EnumLiteral 类型
        // 这是目前官方文档中的使用方案
        const EnumLiteral: type = @Type(.EnumLiteral);

        // 定义一个常量 enum_literal，它的类型为 EnumLiteral，并赋值为 “.kkk”
        const enum_literal: EnumLiteral = .kkk;

        // 使用内建函数 @tagName 获取 enum_literal 的 tag name，并进行打印
        std.debug.print("enum_literal is {s}", .{@tagName(enum_literal)});
        // #endregion enum_literal
    }
};
