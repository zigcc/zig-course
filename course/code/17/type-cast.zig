pub fn main() !void {
    try tag_union_enum.main();
    try peer_resolution_2.main();
    try peer_resolution_3.main();
    try peer_resolution_4.main();
    try peer_resolution_5.main();
    try peer_resolution_7.main();
}

const widen = struct {
    // #region widen
    const a: u8 = 250;
    const b: u16 = a;
    const c: u32 = b;
    const d: u64 = c;
    const e: u64 = d;
    const f: u128 = e;
    // f 和 a 是相等的

    const g: u8 = 250;
    const h: i16 = h;
    // g 和 h 相等

    const i: f16 = 12.34;
    const j: f32 = i;
    const k: f64 = j;
    const l: f128 = k;
    // i 和 l 相等
    // #endregion widen
};

const pointer_arr_slice_1 = struct {
    // #region pointer_arr_slice_1
    const x1: []const u8 = "hello";
    const x2: []const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
    // x1 和 x2 相等

    const y1: anyerror![]const u8 = "hello";
    const y2: anyerror![]const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
    // 是错误联合类型时，也有效

    const z1: ?[]const u8 = "hello";
    const z2: ?[]const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
    // 可选类型也有效果

    const a1: anyerror!?[]const u8 = "hello";
    const a2: anyerror!?[]const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
    // 错误联合可选类型也有效
    // #endregion pointer_arr_slice_1
};

const pointer_arr_slice_2 = struct {
    // #region pointer_arr_slice_2
    var buf: [5]u8 = "hello".*;
    const x: []u8 = &buf;

    const buf2 = [2]f32{ 1.2, 3.4 };
    const x2: []const f32 = &buf2;
    // #endregion pointer_arr_slice_2
};

const pointer_arr_slice_3 = struct {
    // #region pointer_arr_slice_3
    var buf: [5]u8 = "hello".*;
    const x: [*]u8 = &buf;

    var buf2: [5]u8 = "hello".*;
    const x2: ?[*]u8 = &buf2;
    // 可选类型也有效

    var buf3: [5]u8 = "hello".*;
    const x3: anyerror![*]u8 = &buf3;
    // 联合错误类型也有效

    var buf4: [5]u8 = "hello".*;
    const x4: anyerror!?[*]u8 = &buf4;
    // 联合错误可选类型也有效
    // #endregion pointer_arr_slice_3
};

const pointer_arr_slice_4 = struct {
    // #region pointer_arr_slice_4
    var x: i32 = 1234;
    const y: *[1]i32 = &x;
    const z: [*]i32 = y;
    // 先转为长度为 1 的数组指针，再转换为多项指针。
    // 如果 x 直接赋值给 z，则编译器会报错
    // #endregion pointer_arr_slice_4
};

const optional_payload = struct {
    // #region optional_payload
    const y: ?i32 = null;
    const y1: anyerror!?i32 = null;
    // 错误联合可选类型也可以
    // #endregion optional_payload

    // #region error_union
    const z: anyerror!i32 = error.Failure;
    // #endregion error_union
};

const comptime_integer = struct {
    // #region comptime_integer
    const x: u64 = 255;
    const y: u8 = x;
    // 自动转换到 u8
    // #endregion comptime_integer
};

const tag_union_enum = struct {
    // #region tag_union_enum
    const std = @import("std");
    const expect = std.testing.expect;

    const E = enum {
        one,
        two,
        three,
    };

    const U = union(E) {
        one: i32,
        two: f32,
        three,
    };

    const U2 = union(enum) {
        a: void,
        b: f32,

        fn tag(self: U2) usize {
            switch (self) {
                .a => return 1,
                .b => return 2,
            }
        }
    };

    pub fn main() !void {
        const u = U{ .two = 12.34 };
        const e: E = u; // 将联合类型转换为枚举
        try expect(e == E.two);

        const three = E.three;
        // 将枚举转换为联合类型，注意这里 three 并没有对应的类型，故可以直接转换
        const u_2: U = three;
        try expect(u_2 == E.three);

        const u_3: U = .three; // 字面量供 zig 编译器来自动推导
        try expect(u_3 == E.three);

        const u_4: U2 = .a; // 字面量供 zig 编译器来推导，a 也是没有对应的类型（void）
        try expect(u_4.tag() == 1);

        // 下面的 b 字面量推导是错误的，因为它有对应的类型 f32
        //var u_5: U2 = .b;
        //try expect(u_5.tag() == 2);
    }
    // #endregion tag_union_enum
};

const tuple_arr = struct {
    // #region tuple_arr
    const Tuple = struct { u8, u8 };

    const tuple: Tuple = .{ 5, 6 };
    // 一切都是自动完成的
    const array: [2]u8 = tuple;
    // #endregion tuple_arr
};

const peer_resolution_1 = struct {
    // #region peer_resolution_1
    const a: i8 = 12;
    const b: i16 = 34;
    const c = a + b;
    // c 的类型是 u16
    // #endregion peer_resolution_1
};

const peer_resolution_2 = struct {
    // #region peer_resolution_2
    const std = @import("std");
    const expect = std.testing.expect;
    const mem = std.mem;

    pub fn main() !void {
        // mem.eql 执行检查内存是否相等
        try expect(mem.eql(u8, boolToStr(true), "true"));
        try expect(mem.eql(u8, boolToStr(false), "false"));
        try comptime expect(mem.eql(u8, boolToStr(true), "true"));
        try comptime expect(mem.eql(u8, boolToStr(false), "false"));
    }

    fn boolToStr(b: bool) []const u8 {
        return if (b) "true" else "false";
    }
    // #endregion peer_resolution_2
};

const peer_resolution_3 = struct {
    // #region peer_resolution_3
    const std = @import("std");
    const expect = std.testing.expect;
    const mem = std.mem;

    pub fn main() !void {
        try testPeerResolveArrayConstSlice(true);
        // 上面这个语句执行会成功
    }

    fn testPeerResolveArrayConstSlice(b: bool) !void {
        const value1 = if (b) "aoeu" else @as([]const u8, "zz");
        const value2 = if (b) @as([]const u8, "zz") else "aoeu";
        try expect(mem.eql(u8, value1, "aoeu"));
        try expect(mem.eql(u8, value2, "zz"));
    }
    // #endregion peer_resolution_3
};

const peer_resolution_4 = struct {
    // #region peer_resolution_4
    pub fn main() !void {
        // 下面语句执行为 true
        _ = peerTypeTAndOptionalT(true, false).? == 0;
    }
    fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
        if (c) {
            return if (b) null else @as(usize, 0);
        }

        return @as(usize, 3);
    }
    // #endregion peer_resolution_4
};

const peer_resolution_5 = struct {
    // #region peer_resolution_5
    fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
        if (a) {
            return &[_]u8{};
        }

        return slice[0..1];
    }

    pub fn main() !void {
        // 以下两句均为true
        _ = peerTypeEmptyArrayAndSlice(true, "hi").len == 0;
        _ = peerTypeEmptyArrayAndSlice(false, "hi").len == 1;
    }
    // #endregion peer_resolution_5
};

const peer_resolution_6 = struct {
    // #region peer_resolution_6
    fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
        if (a) {
            return &[_]u8{};
        }

        return slice[0..1];
    }
    // #endregion peer_resolution_6
};

const peer_resolution_7 = struct {
    pub fn main() !void {
        // #region peer_resolution_7
        const a: *const usize = @ptrFromInt(0x123456780);
        const b: ?*usize = @ptrFromInt(0x123456780);
        _ = a == b; // 这个表达式的值为 true
        // #endregion peer_resolution_7
    }
};
