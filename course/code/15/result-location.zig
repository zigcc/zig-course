const std = @import("std");

pub fn main() !void {
    BasicInference.main();
    ResultTypeVariable.main();
    ResultTypeReturn.main();
    ResultTypeParam.main();
    ResultTypeFieldDefault.main();
    ResultLocationNested.main();
    DeclLiteralBasic.main();
    DeclLiteralFieldDefault.main();
    DeclLiteralFunction.main();
    // 以下示例需要 allocator，仅在测试中运行
    // try DeclLiteralErrorUnion.main();
    // try StdLibArrayList.main();
    try StdLibGPA.main();
}

const BasicInference = struct {
    // #region basic_inference
    const Point = struct {
        x: i32,
        y: i32,
    };

    pub fn main() void {
        // 编译器从变量类型推断出 .{} 的具体类型
        const pt: Point = .{ .x = 10, .y = 20 };

        // 等价于
        const pt2: Point = Point{ .x = 10, .y = 20 };

        std.debug.print("pt: ({}, {}), pt2: ({}, {})\n", .{ pt.x, pt.y, pt2.x, pt2.y });
    }
    // #endregion basic_inference
};

const ResultTypeVariable = struct {
    // #region result_type_variable
    const Color = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    pub fn main() void {
        // 结果类型是 Color
        const red: Color = .{ .r = 255, .g = 0, .b = 0 };
        std.debug.print("red: ({}, {}, {})\n", .{ red.r, red.g, red.b });
    }
    // #endregion result_type_variable
};

const ResultTypeReturn = struct {
    // #region result_type_return
    const Vec2 = struct {
        x: f32,
        y: f32,
    };

    fn origin() Vec2 {
        // 结果类型是 Vec2
        return .{ .x = 0, .y = 0 };
    }

    pub fn main() void {
        const o = origin();
        std.debug.print("origin: ({d}, {d})\n", .{ o.x, o.y });
    }
    // #endregion result_type_return
};

const ResultTypeParam = struct {
    // #region result_type_param
    const Size = struct {
        width: u32,
        height: u32,
    };

    fn calculateArea(size: Size) u64 {
        return @as(u64, size.width) * size.height;
    }

    pub fn main() void {
        // 调用时，.{} 的结果类型是 Size
        const area = calculateArea(.{ .width = 100, .height = 50 });
        std.debug.print("area: {}\n", .{area});
    }
    // #endregion result_type_param
};

const ResultTypeFieldDefault = struct {
    // #region result_type_field_default
    const Config = struct {
        timeout: u32 = 30,
        retries: u8 = 3,
    };

    const Wrapper = struct {
        // 字段类型是 Config，所以 .{} 的结果类型是 Config
        config: Config = .{},
    };

    pub fn main() void {
        const w: Wrapper = .{};
        std.debug.print("timeout: {}, retries: {}\n", .{ w.config.timeout, w.config.retries });
    }
    // #endregion result_type_field_default
};

const ResultLocationNested = struct {
    // #region result_location_nested
    const Inner = struct {
        value: i32,
    };

    const Outer = struct {
        inner: Inner,
        name: []const u8,
    };

    pub fn main() void {
        // 结果位置 Outer 传播到 inner 字段，使其结果类型为 Inner
        const obj: Outer = .{
            .inner = .{ .value = 42 }, // 这里 .{} 的结果类型是 Inner
            .name = "example",
        };
        std.debug.print("inner.value: {}, name: {s}\n", .{ obj.inner.value, obj.name });
    }
    // #endregion result_location_nested
};

const DeclLiteralBasic = struct {
    // #region decl_literal_basic
    const S = struct {
        x: u32,

        // 类型内的常量声明
        const default: S = .{ .x = 123 };
    };

    pub fn main() void {
        // .default 会被解析为 S.default
        const val: S = .default;
        std.debug.print("val.x: {}\n", .{val.x});
    }

    test "decl literal" {
        const val: S = .default;
        try std.testing.expectEqual(123, val.x);
    }
    // #endregion decl_literal_basic
};

const DeclLiteralFieldDefault = struct {
    // #region decl_literal_field_default
    const Settings = struct {
        x: u32,
        y: u32,

        const default: Settings = .{ .x = 1, .y = 2 };
        const high_performance: Settings = .{ .x = 100, .y = 200 };
    };

    const Application = struct {
        // 使用声明字面量设置默认值
        settings: Settings = .default,
    };

    pub fn main() void {
        const app1: Application = .{};
        std.debug.print("app1.settings: ({}, {})\n", .{ app1.settings.x, app1.settings.y });

        // 也可以覆盖为其他预定义值
        const app2: Application = .{ .settings = .high_performance };
        std.debug.print("app2.settings: ({}, {})\n", .{ app2.settings.x, app2.settings.y });
    }

    test "decl literal in field default" {
        const app1: Application = .{};
        try std.testing.expectEqual(1, app1.settings.x);

        const app2: Application = .{ .settings = .high_performance };
        try std.testing.expectEqual(100, app2.settings.x);
    }
    // #endregion decl_literal_field_default
};

const DeclLiteralFunction = struct {
    // #region decl_literal_function
    const Point = struct {
        x: i32,
        y: i32,

        fn init(val: i32) Point {
            return .{ .x = val, .y = val };
        }

        fn offset(val: i32, dx: i32, dy: i32) Point {
            return .{ .x = val + dx, .y = val + dy };
        }
    };

    pub fn main() void {
        // .init(5) 等价于 Point.init(5)
        const p1: Point = .init(5);
        std.debug.print("p1: ({}, {})\n", .{ p1.x, p1.y });

        const p2: Point = .offset(0, 10, 20);
        std.debug.print("p2: ({}, {})\n", .{ p2.x, p2.y });
    }

    test "call function via decl literal" {
        const p1: Point = .init(5);
        try std.testing.expectEqual(5, p1.x);
        try std.testing.expectEqual(5, p1.y);

        const p2: Point = .offset(0, 10, 20);
        try std.testing.expectEqual(10, p2.x);
        try std.testing.expectEqual(20, p2.y);
    }
    // #endregion decl_literal_function
};

const DeclLiteralErrorUnion = struct {
    // #region decl_literal_error_union
    const Buffer = struct {
        data: std.ArrayListUnmanaged(u32),

        fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !Buffer {
            return .{ .data = try .initCapacity(allocator, capacity) };
        }
    };

    test "decl literal with error union" {
        var buf: Buffer = try .initCapacity(std.testing.allocator, 10);
        defer buf.data.deinit(std.testing.allocator);

        buf.data.appendAssumeCapacity(42);
        try std.testing.expectEqual(42, buf.data.items[0]);
    }
    // #endregion decl_literal_error_union
};

const FaultyDefaultValues = struct {
    // #region faulty_default_problem
    /// `ptr` 指向 `[len]u32`
    pub const BufferA = extern struct {
        ptr: ?[*]u32 = null,
        len: usize = 0,
    };

    // 看起来是空 buffer
    var empty_buf: BufferA = .{};

    // 但用户可以只覆盖部分字段，导致不一致的状态！
    var bad_buf: BufferA = .{ .len = 10 }; // ptr 是 null，但 len 是 10
    // #endregion faulty_default_problem
};

const FaultyDefaultSolution = struct {
    // #region faulty_default_solution
    /// `ptr` 指向 `[len]u32`
    pub const BufferB = extern struct {
        ptr: ?[*]u32,
        len: usize,

        // 通过声明提供预定义的有效状态
        pub const empty: BufferB = .{ .ptr = null, .len = 0 };
    };

    // 安全地创建空 buffer
    var empty_buf: BufferB = .empty;

    // 如果要手动指定值，必须同时指定所有字段
    // var custom_buf: BufferB = .{ .ptr = some_ptr, .len = 10 };
    // #endregion faulty_default_solution
};

const StdLibArrayList = struct {
    // #region stdlib_arraylist
    const Container = struct {
        // 使用 .empty 而不是 .{}
        list: std.ArrayListUnmanaged(i32) = .empty,
    };

    test "ArrayListUnmanaged with decl literal" {
        var c: Container = .{};
        defer c.list.deinit(std.testing.allocator);

        try c.list.append(std.testing.allocator, 1);
        try c.list.append(std.testing.allocator, 2);

        try std.testing.expectEqual(2, c.list.items.len);
    }
    // #endregion stdlib_arraylist
};

const StdLibGPA = struct {
    // #region stdlib_gpa
    pub fn main() !void {
        // 使用 .init 进行初始化
        var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const ptr = try allocator.alloc(u8, 100);
        defer allocator.free(ptr);

        std.debug.print("allocated {} bytes\n", .{ptr.len});
    }

    test "GPA with decl literal" {
        var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const ptr = try allocator.alloc(u8, 100);
        defer allocator.free(ptr);

        try std.testing.expectEqual(100, ptr.len);
    }
    // #endregion stdlib_gpa
};

const NamingConflict = struct {
    // #region naming_conflict
    // 错误：字段和声明同名（此代码无法编译）
    // const Bad = struct {
    //     Value: u32,           // 字段
    //     const Value = 100;    // 声明 - 编译错误！
    // };

    // 正确：遵循命名约定
    const Good = struct {
        value: u32, // 字段使用 snake_case
        const Value = 100; // 声明使用 PascalCase
    };
    // #endregion naming_conflict
};

test "basic inference" {
    const Point = BasicInference.Point;
    const pt: Point = .{ .x = 10, .y = 20 };
    try std.testing.expectEqual(10, pt.x);
    try std.testing.expectEqual(20, pt.y);
}

test "decl literal basic" {
    const S = DeclLiteralBasic.S;
    const val: S = .default;
    try std.testing.expectEqual(123, val.x);
}

test "decl literal field default" {
    const Application = DeclLiteralFieldDefault.Application;
    const app1: Application = .{};
    try std.testing.expectEqual(1, app1.settings.x);
}

test "decl literal function" {
    const Point = DeclLiteralFunction.Point;
    const p1: Point = .init(5);
    try std.testing.expectEqual(5, p1.x);
}

test "decl literal error union" {
    const Buffer = DeclLiteralErrorUnion.Buffer;
    var buf: Buffer = try .initCapacity(std.testing.allocator, 10);
    defer buf.data.deinit(std.testing.allocator);
    buf.data.appendAssumeCapacity(42);
    try std.testing.expectEqual(42, buf.data.items[0]);
}

test "stdlib arraylist" {
    const Container = StdLibArrayList.Container;
    var c: Container = .{};
    defer c.list.deinit(std.testing.allocator);
    try c.list.append(std.testing.allocator, 1);
    try std.testing.expectEqual(1, c.list.items.len);
}

test "stdlib gpa" {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ptr = try allocator.alloc(u8, 100);
    defer allocator.free(ptr);
    try std.testing.expectEqual(100, ptr.len);
}
