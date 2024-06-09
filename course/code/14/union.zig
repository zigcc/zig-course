pub fn main() !void {
    try Basic.main();
    try Tag.main();
    try CapturePayload.main();
    TagName.main();
}

const Basic = struct {
    // #region more_basic
    const print = @import("std").debug.print;

    // #region default_basic
    const Payload = union {
        int: i64,
        float: f64,
        boolean: bool,
    };

    pub fn main() !void {
        var payload = Payload{ .int = 1234 };
        payload = Payload{ .int = 9 };
        // var payload_1: Payload = .{ .int = 1234 };

        print("{}\n", .{payload.int});
    }
    // #endregion default_basic
    // #endregion more_basic
};

const UnionInit = struct {
    // #region union_init
    const Payload = union {
        int: i64,
        float: f64,
        boolean: bool,
    };
    // 通过 @unionInit 初始化一个联合类型
    const payload = @unionInit(Payload, "int", 666);
    // #endregion union_init
};

const Tag = struct {
    // #region more_tag
    const std = @import("std");
    const expect = std.testing.expect;

    pub fn main() !void {
        // #region default_tag
        // 一个枚举，用于给联合类型挂上标记
        const ComplexTypeTag = enum {
            ok,
            not_ok,
        };

        // 带标记的联合类型
        const ComplexType = union(ComplexTypeTag) {
            ok: u8,
            not_ok: void,
        };

        const c = ComplexType{ .ok = 42 };
        // 可以直接将标记联合类型作为枚举来使用，这是合法的
        try expect(@as(ComplexTypeTag, c) == ComplexTypeTag.ok);

        // 使用 switch 进行匹配
        switch (c) {
            ComplexTypeTag.ok => |value| try expect(value == 42),
            ComplexTypeTag.not_ok => unreachable,
        }

        // 使用 zig 的 meta 库获取对应的 tag
        try expect(std.meta.Tag(ComplexType) == ComplexTypeTag);
        // #endregion default_tag
    }
    // #endregion more_tag
};

const CapturePayload = struct {
    // #region more_capture_payload
    const std = @import("std");
    const expect = std.testing.expect;

    pub fn main() !void {
        // #region default_capture_payload
        // 枚举，用于给联合类型打上标记
        const ComplexTypeTag = enum {
            ok,
            not_ok,
        };

        // 带标记的联合类型
        const ComplexType = union(ComplexTypeTag) {
            ok: u8,
            not_ok: void,
        };

        var c = ComplexType{ .ok = 42 };

        // 使用 switch 进行匹配
        switch (c) {
            // 捕获了标记联合值的指针，用于修改值
            ComplexTypeTag.ok => |*value| value.* += 1,
            ComplexTypeTag.not_ok => unreachable,
        }

        try expect(c.ok == 43);
        // #endregion default_capture_payload
    }
    // #endregion more_capture_payload
};

const TagName = struct {
    pub fn main() void {
        // #region tag_name
        const Small2 = union(enum) {
            a: i32,
            b: bool,
            c: u8,
        };

        const name = @tagName(Small2.a);
        // 这个返回值将会是 a
        // #endregion tag_name
        _ = name;
    }
};

// #region auto_infer
const Number = union {
    int: i32,
    float: f64,
};

// 自动推断
const i: Number = .{ .int = 42 };
// #endregion auto_infer
