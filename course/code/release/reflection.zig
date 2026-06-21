pub fn main() !void {
    typeName.main();
    typeInfo.main();
    hasDecl.main();
    hasField.main();

    Field.main();
    fieldParentPtr.main();
    call.main();
    Type.main();
}

test "all" {
    _ = NoEffects;
    _ = TypeInfo2;
    _ = TypeInfo3;
}

const NoEffects = struct {
    // #region no_effects
    const std = @import("std");
    const expect = std.testing.expect;

    test "no runtime side effects" {
        var data: i32 = 0;
        const T = @TypeOf(foo(i32, &data));
        try comptime expect(T == i32);
        try expect(data == 0);
    }

    fn foo(comptime T: type, ptr: *T) T {
        ptr.* += 1;
        return ptr.*;
    }
    // #endregion no_effects
};

const typeName = struct {
    // #region typeName
    const std = @import("std");

    const T = struct {
        const Y = struct {};
    };

    pub fn main() void {
        std.debug.print("{s}\n", .{@typeName(T)});
        std.debug.print("{s}\n", .{@typeName(T.Y)});
    }
    // #endregion typeName
};

const typeInfo = struct {
    // #region typeInfo
    const std = @import("std");

    const T = struct {
        a: u8,
        b: u8,
    };

    pub fn main() void {
        // 通过 @typeInfo 获取类型信息
        const type_info = @typeInfo(T);
        // 断言它为 struct
        const struct_info = type_info.@"struct";

        // inline for 打印该结构体内部字段的信息
        inline for (struct_info.fields) |field| {
            std.debug.print("field name is {s}, field type is {}\n", .{
                field.name,
                field.type,
            });
        }
    }
    // #endregion typeInfo
};

const TypeInfo2 = struct {
    // #region TypeInfo2
    const std = @import("std");

    fn IntToArray(comptime T: type) type {
        // 获得类型信息，并断言为Int
        const int_info = @typeInfo(T).int;
        // 获得Int位数
        const bits = int_info.bits;
        // 检查位数是否被8整除
        if (bits % 8 != 0) @compileError("bit count not a multiple of 8");
        // 生成新类型
        return [bits / 8]u8;
    }

    test {
        try std.testing.expectEqual([1]u8, IntToArray(u8));
        try std.testing.expectEqual([2]u8, IntToArray(u16));
        try std.testing.expectEqual([3]u8, IntToArray(u24));
        try std.testing.expectEqual([4]u8, IntToArray(u32));
    }
    // #endregion TypeInfo2
};

const TypeInfo3 = struct {
    // #region TypeInfo3
    const std = @import("std");

    fn ExternAlignOne(comptime T: type) type {
        // 获得类型信息，并断言为Struct.
        const struct_info = @typeInfo(T).@"struct";
        // 准备字段名称
        comptime var field_names: [struct_info.fields.len][]const u8 = undefined;
        comptime var field_types: [struct_info.fields.len]type = undefined;
        comptime var field_attrs: [struct_info.fields.len]std.builtin.Type.StructField.Attributes = undefined;

        inline for (struct_info.fields, 0..) |field, i| {
            field_names[i] = field.name;
            field_types[i] = field.type;
            // 设置对齐为 1，其他属性使用默认值
            field_attrs[i] = .{
                .@"align" = 1,
            };
        }

        // 使用 @Struct 构造新类型（extern 布局，对齐为 1）
        return @Struct(.@"extern", null, &field_names, &field_types, &field_attrs);
    }

    const MyStruct = struct {
        a: u32,
        b: u32,
    };

    test {
        const NewType = ExternAlignOne(MyStruct);
        try std.testing.expectEqual(4, @alignOf(MyStruct));
        try std.testing.expectEqual(1, @alignOf(NewType));
    }
    // #endregion TypeInfo3
};

const hasDecl = struct {
    // #region hasDecl
    const std = @import("std");

    const Foo = struct {
        nope: i32,

        pub var blah = "xxx";
        const hi = 1;
    };

    pub fn main() void {
        // true
        std.debug.print("blah:{}\n", .{@hasDecl(Foo, "blah")});
        // true
        // hi 此声明可以被检测到是因为类型和代码处于同一个文件中，这导致他们之间可以互相访问
        // 换另一个文件就不行了
        std.debug.print("hi:{}\n", .{@hasDecl(Foo, "hi")});
        // false 不检查字段
        std.debug.print("nope:{}\n", .{@hasDecl(Foo, "nope")});
        // false 没有对应的声明
        std.debug.print("nope1234:{}\n", .{@hasDecl(Foo, "nope1234")});
    }
    // #endregion hasDecl
};

const hasField = struct {
    // #region hasField
    const std = @import("std");

    const Foo = struct {
        nope: i32,

        pub var blah = "xxx";
        const hi = 1;
    };

    pub fn main() void {
        // false
        std.debug.print("blah:{}\n", .{@hasField(Foo, "blah")});
        // false
        std.debug.print("hi:{}\n", .{@hasField(Foo, "hi")});
        // true
        std.debug.print("nope:{}\n", .{@hasField(Foo, "nope")});
        // false
        std.debug.print("nope1234:{}\n", .{@hasField(Foo, "nope1234")});
    }
    // #endregion hasField
};

const Field = struct {
    // #region Field
    const std = @import("std");

    const Point = struct {
        x: u32,
        y: u32,

        pub var z: u32 = 1;
    };

    pub fn main() void {
        var p = Point{ .x = 0, .y = 0 };

        @field(p, "x") = 4;
        @field(p, "y") = @field(p, "x") + 1;
        // x is 4, y is 5
        std.debug.print("x is {}, y is {}\n", .{ p.x, p.y });

        // Point's z is 1
        std.debug.print("Point's z is {}\n", .{@field(Point, "z")});
    }
    // #endregion Field
};

const fieldParentPtr = struct {
    // #region fieldParentPtr
    const std = @import("std");

    const Point = struct {
        x: u32,
    };

    pub fn main() void {
        var p = Point{ .x = 0 };

        const res = &p == @as(*Point, @fieldParentPtr("x", &p.x));

        // test is true
        std.debug.print("test is {}\n", .{res});
    }
    // #endregion fieldParentPtr
};

const call = struct {
    // #region call
    const std = @import("std");

    fn add(a: i32, b: i32) i32 {
        return a + b;
    }

    pub fn main() void {
        std.debug.print("call function add, the result is {}\n", .{@call(.auto, add, .{ 1, 2 })});
    }
    // #endregion call
};

const Type = struct {
    // #region Type
    const std = @import("std");

    // Zig 0.16 使用 @Struct 替代 @Type
    const T = @Struct(
        .auto, // layout
        null, // BackingInt
        &.{"b"}, // field_names
        &.{u32}, // field_types
        &.{.{ .@"align" = 8 }}, // field_attrs
    );

    pub fn main() void {
        const D = T{
            .b = 666,
        };

        std.debug.print("{}\n", .{D.b});
    }
    // #endregion Type
};
