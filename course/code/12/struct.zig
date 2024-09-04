pub fn main() !void {
    Struct.main();
    SelfReference1.main();
    SelfReference2.main();
    try SelfReference3.main();
    AutoReference.main();
    DefaultField.main();
    EmptyStruct.main();
    Tuple_.main();
    NamePrinciple.main();
    try PackedBitOffset.main();
    try PackedCast.main();
}

const Struct = struct {
    // #region more_struct
    const std = @import("std");

    // #region default_struct
    const Circle = struct {
        radius: u8,

        const PI: f16 = 3.14;

        pub fn init(radius: u8) Circle {
            return Circle{ .radius = radius };
        }

        fn area(self: *Circle) f16 {
            return @as(f16, @floatFromInt(self.radius * self.radius)) * PI;
        }
    };
    // #endregion default_struct

    pub fn main() void {
        const radius: u8 = 5;
        var circle = Circle.init(radius);
        std.debug.print("The area of a circle with radius {} is {d:.2}\n", .{ radius, circle.area() });
    }
    // #endregion more_struct
};

const SelfReference1 = struct {
    // #region more_self_reference1
    const std = @import("std");

    // #region deault_self_reference1
    const TT = struct {
        pub fn print(self: *TT) void {
            _ = self; // _ 表示不使用变量
            std.debug.print("Hello, world!\n", .{});
        }
    };
    // #endregion deault_self_reference1

    pub fn main() void {
        var tmp: TT = .{};
        tmp.print();
    }
    // #endregion more_self_reference1
};

const SelfReference2 = struct {
    // #region more_self_reference2
    const std = @import("std");

    // #region deault_self_reference2
    fn List(comptime T: type) type {
        return struct {
            const Self = @This();

            items: []T,

            fn length(self: Self) usize {
                return self.items.len;
            }
        };
    }
    // #endregion deault_self_reference2

    pub fn main() void {
        const int_list = List(u8);
        var arr: [5]u8 = .{
            1, 2, 3, 4, 5,
        };

        var list: int_list = .{
            .items = &arr,
        };

        std.debug.print("list len is {}\n", .{list.length()});
    }
    // #endregion more_self_reference2
};

const SelfReference3 = struct {
    // #region more_self_reference3
    const std = @import("std");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    // #region deault_self_reference3
    const User = struct {
        userName: []u8,
        password: []u8,
        email: []u8,
        active: bool,

        pub const writer = "zig-course";

        pub fn init(userName: []u8, password: []u8, email: []u8, active: bool) User {
            return User{
                .userName = userName,
                .password = password,
                .email = email,
                .active = active,
            };
        }

        pub fn print(self: *User) void {
            std.debug.print(
                \\username: {s}
                \\password: {s}
                \\email: {s}
                \\active: {}
                \\
            , .{
                self.userName,
                self.password,
                self.email,
                self.active,
            });
        }
    };
    // #endregion deault_self_reference3

    const name = "xiaoming";
    const passwd = "123456";
    const mail = "123456@qq.com";

    pub fn main() !void {
        // 我们在这里使用了内存分配器的知识，如果你需要的话，可以提前跳到内存管理进行学习！
        const allocator = gpa.allocator();
        defer {
            const deinit_status = gpa.deinit();
            if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
        }

        const username = try allocator.alloc(u8, 20);
        defer allocator.free(username);

        // @memset 是一个内存初始化函数，它会将一段内存初始化为 0
        @memset(username, 0);
        // @memcpy 是一个内存拷贝函数，它会将一个内存区域的内容拷贝到另一个内存区域
        @memcpy(username[0..name.len], name);

        const password = try allocator.alloc(u8, 20);
        defer allocator.free(password);

        @memset(password, 0);
        @memcpy(password[0..passwd.len], passwd);

        const email = try allocator.alloc(u8, 20);
        defer allocator.free(email);

        @memset(email, 0);
        @memcpy(email[0..mail.len], mail);

        var user = User.init(username, password, email, true);
        user.print();
    }
    // #endregion more_self_reference3
};

const AutoReference = struct {
    pub fn main() void {
        // #region auto_reference
        const Point = struct { x: i32, y: i32 };

        const pt: Point = .{
            .x = 13,
            .y = 67,
        };
        // #endregion auto_reference

        _ = pt;
    }
};

// #region linked_list
fn LinkedList(comptime T: type) type {
    return struct {
        pub const Node = struct {
            // 这里我们提前使用了可选类型，如有需要可以提前跳到可选类型部分学习！
            prev: ?*Node,
            next: ?*Node,
            data: T,
        };

        first: ?*Node,
        last: ?*Node,
        len: usize,
    };
}
// #endregion linked_list

const DefaultField = struct {
    pub fn main() void {
        // #region default_field
        const Foo = struct {
            a: i32 = 1234,
            b: i32,
        };

        const x = Foo{
            .b = 5,
        };
        // #endregion default_field
        _ = x;
    }
};

const EmptyStruct = struct {
    // #region more_empty_struct
    const std = @import("std");

    // #region default_empty_struct
    const Empty = struct {};
    // #endregion default_empty_struct

    pub fn main() void {
        std.debug.print("{}\n", .{@sizeOf(Empty)});
    }
    // #endregion more_empty_struct
};

const BasePtr = struct {
    // #region base_ptr
    const Point = struct {
        x: f32,
        y: f32,
    };

    fn setYBasedOnX(x: *f32, y: f32) void {
        const point: Point = @fieldParentPtr("x", x);
        point.y = y;
    }
    // #endregion base_ptr
};

const Tuple_ = struct {
    pub fn main() void {
        // #region tuple
        // 我们定义了一个元组类型
        const Tuple = struct { u8, u8 };

        // 直接使用字面量来定义一个元组
        const values = .{
            @as(u32, 1234),
            @as(f64, 12.34),
            true,
            "hi",
        };
        // 值得注意的是，values的类型和Tuple仅仅是结构相似，但不是同一类型！
        // 因为values的类型是由编译器在编译期间自行推导出来的。

        const hi = values.@"3"; // "hi"
        // #endregion tuple
        _ = hi;
        _ = Tuple;
    }
};

const NamePrinciple = struct {
    // #region name_principle
    const std = @import("std");

    pub fn main() void {
        const Foo = struct {};
        std.debug.print("variable: {s}\n", .{@typeName(Foo)});
        std.debug.print("anonymous: {s}\n", .{@typeName(struct {})});
        std.debug.print("function: {s}\n", .{@typeName(List(i32))});
    }

    fn List(comptime T: type) type {
        return struct {
            x: T,
        };
    }
    // #endregion name_principle
};

const PackedBitOffset = struct {
    // #region packed_bit_offset
    const std = @import("std");
    const expect = std.testing.expect;

    const BitField = packed struct {
        a: u3,
        b: u3,
        c: u2,
    };

    pub fn main() !void {
        // @bitOffsetOf 用于获取位域的偏移量（即偏移几位）
        try expect(@bitOffsetOf(BitField, "a") == 0);
        try expect(@bitOffsetOf(BitField, "b") == 3);
        try expect(@bitOffsetOf(BitField, "c") == 6);

        // @offsetOf 用于获取字段的偏移量（即偏移几个字节）
        try expect(@offsetOf(BitField, "a") == 0);
        try expect(@offsetOf(BitField, "b") == 0);
        try expect(@offsetOf(BitField, "c") == 0);
    }
    // #endregion packed_bit_offset
};

const PackedCast = struct {
    // #region packed_cast
    const std = @import("std");
    // 这里获取目标架构是字节排序方式，大端和小端
    const native_endian = @import("builtin").target.cpu.arch.endian();
    const expect = std.testing.expect;

    const Full = packed struct {
        number: u16,
    };

    const Divided = packed struct {
        half1: u8,
        quarter3: u4,
        quarter4: u4,
    };

    fn doTheTest() !void {
        try expect(@sizeOf(Full) == 2);
        try expect(@sizeOf(Divided) == 2);

        const full = Full{ .number = 0x1234 };
        const divided: Divided = @bitCast(full);

        try expect(divided.half1 == 0x34);
        try expect(divided.quarter3 == 0x2);
        try expect(divided.quarter4 == 0x1);

        const ordered: [2]u8 = @bitCast(full);

        switch (native_endian) {
            .big => {
                try expect(ordered[0] == 0x12);
                try expect(ordered[1] == 0x34);
            },
            .little => {
                try expect(ordered[0] == 0x34);
                try expect(ordered[1] == 0x12);
            },
        }
    }

    pub fn main() !void {
        try doTheTest();
        try comptime doTheTest();
    }
    // #endregion packed_cast
};

const aligned_struct = struct {
    // #region aligned_struct
    const std = @import("std");
    const expect = std.testing.expect;

    const S = packed struct {
        a: u32,
        b: u32,
    };
    test "overaligned pointer to packed struct" {
        var foo: S align(4) = .{ .a = 1, .b = 2 };
        const ptr: *align(4) S = &foo;
        const ptr_to_b: *u32 = &ptr.b;
        try expect(ptr_to_b.* == 2);
    }
    // #endregion aligned_struct
};

const reorder_struct = struct {
    // #region reorder_struct
    const std = @import("std");

    const Foo = packed struct {
        x: i32,
        y: [*]i32, // 一个多项指针
    };

    pub fn main() !void {
        std.debug.print("{any}\n", .{@sizeOf(Foo)});
        std.debug.print("{any}\n", .{@bitSizeOf(Foo) / 8});

        std.debug.print("{any}\n", .{@bitOffsetOf(Foo, "x") / 8});
        std.debug.print("{any}\n", .{@bitOffsetOf(Foo, "y") / 8});
    }
    // #endregion reorder_struct
};
