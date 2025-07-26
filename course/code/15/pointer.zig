pub fn main() !void {
    try SinglePointer.main();
    try MultiPointer.main();
    try ArrayAndSlice.main();
    try Slice.main();
    try STPointer.main();
    try Volatile.main();
    try Align.main();
    try AlignCast.main();
    try ZeroPointer.main();
    ComptimePointer.main();
    ptr2int.main();
    try compPointer.main();
}

const SinglePointer = struct {
    // #region single_pointer
    const print = @import("std").debug.print;

    pub fn main() !void {
        var integer: i16 = 666;
        const ptr = &integer;
        ptr.* = ptr.* + 1;

        print("{}\n", .{integer});
    }
    // #endregion single_pointer
};

const fnPointer = struct {
    // #region fn_pointer
    const Call2Op = *const fn (a: i8, b: i8) i8;
    // Call20p 是一个函数指针类型，指向一个接受两个 i8 类型参数并返回 i8 类型的函数
    // #endregion fn_pointer
};

const ptr2int = struct {
    pub fn main() void {
        // #region ptr2int
        const std = @import("std");

        // ptrFromInt 将整数转换为指针
        const ptr: *i32 = @ptrFromInt(0xdeadbee0);
        // intFromPtr 将指针转换为整数
        const addr = @intFromPtr(ptr);

        if (@TypeOf(addr) == usize) {
            std.debug.print("success\n", .{});
        }
        if (addr == 0xdeadbee0) {
            std.debug.print("success\n", .{});
        }
        // #endregion ptr2int
    }
};

const MultiPointer = struct {
    // #region multi_pointer
    const print = @import("std").debug.print;

    pub fn main() !void {
        const array = [_]i32{ 1, 2, 3, 4 };
        const ptr: [*]const i32 = &array;

        print("第一个元素：{}\n", .{ptr[0]});
    }
    // #endregion multi_pointer
};
const ArrayAndSlice = struct {
    // #region array_and_slice
    const expect = @import("std").testing.expect;

    pub fn main() !void {
        var array: [5]u8 = "hello".*;

        const array_pointer = &array;
        try expect(array_pointer.len == 5);

        const slice: []u8 = array[1..3];
        try expect(slice.len == 2);
    }
    // #endregion array_and_slice
};

const Slice = struct {
    // #region slice
    const print = @import("std").debug.print;

    pub fn main() !void {
        var array = [_]i32{ 1, 2, 3, 4 };
        const arr_ptr: *const [4]i32 = &array;

        print("数组第一个元素为：{}\n", .{arr_ptr[0]});
        print("数组长度为：{}\n", .{arr_ptr.len});

        const slice = array[1 .. array.len - 1];
        const slice_ptr: []i32 = slice;

        print("切片第一个元素为：{}\n", .{slice_ptr[0]});
        print("切片长度为：{}\n", .{slice_ptr.len});
    }
    // #endregion slice
};

const STPointer = struct {
    // #region st_pointer
    const std = @import("std");

    // 我们也可以用 std.c.printf 代替
    pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;

    pub fn main() anyerror!void {
        _ = printf("Hello, world!\n"); // OK
    }
    // #endregion st_pointer
};

const Volatile = struct {
    // #region volatile
    // expect 是单元测试的断言函数
    const expect = @import("std").testing.expect;

    pub fn main() !void {
        const mmio_ptr: *volatile u8 = @ptrFromInt(0x12345678);
        try expect(@TypeOf(mmio_ptr) == *volatile u8);
    }
    // #endregion volatile
};

const Align = struct {
    // #region align
    const std = @import("std");
    const builtin = @import("builtin");
    const expect = std.testing.expect;

    pub fn main() !void {
        var x: i32 = 1234;
        // 获取内存对齐信息
        const align_of_i32 = @alignOf(@TypeOf(x));
        // 尝试比较类型
        try expect(@TypeOf(&x) == *i32);
        // 尝试在设置内存对齐后再进行类型比较
        try expect(*i32 == *align(align_of_i32) i32);

        if (builtin.target.cpu.arch == .x86_64) {
            // 获取了 x86_64 架构的指针对齐大小
            try expect(@typeInfo(*i32).pointer.alignment == 4);
        }
    }
    // #endregion align
};

const AlignCast = struct {
    // #region align_cast
    const expect = @import("std").testing.expect;

    // 全局变量
    var foo: u8 align(4) = 100;

    fn derp() align(@sizeOf(usize) * 2) i32 {
        return 1234;
    }

    // 以下是两个函数
    fn noop1() align(1) void {}
    fn noop4() align(4) void {}

    pub fn main() !void {
        // 全局变量对齐
        try expect(@typeInfo(@TypeOf(&foo)).pointer.alignment == 4);
        try expect(@TypeOf(&foo) == *align(4) u8);
        const as_pointer_to_array: *align(4) [1]u8 = &foo;
        const as_slice: []align(4) u8 = as_pointer_to_array;
        const as_unaligned_slice: []u8 = as_slice;
        try expect(as_unaligned_slice[0] == 100);

        // 函数对齐
        try expect(derp() == 1234);
        try expect(@TypeOf(derp) == fn () i32);
        try expect(@TypeOf(&derp) == *align(@sizeOf(usize) * 2) const fn () i32);

        noop1();
        try expect(@TypeOf(noop1) == fn () void);
        try expect(@TypeOf(&noop1) == *align(1) const fn () void);

        noop4();
        try expect(@TypeOf(noop4) == fn () void);
        try expect(@TypeOf(&noop4) == *align(4) const fn () void);
    }
    // #endregion align_cast
};

const ZeroPointer = struct {
    // #region zero_pointer
    // 本示例中仅仅是构建了一个零指针
    // 并未使用，故可以在所有平台运行
    const std = @import("std");
    const expect = std.testing.expect;

    pub fn main() !void {
        const zero: usize = 0;
        const ptr: *allowzero i32 = @ptrFromInt(zero);
        try expect(@intFromPtr(ptr) == 0);
    }
    // #endregion zero_pointer
};

const ComptimePointer = struct {
    // #region comptime_pointer
    const expect = @import("std").testing.expect;

    pub fn main() void {
        comptime {
            // 在这个 comptime 块中，可以正常使用pointer
            // 不依赖于编译结果的内存布局，即在编译期时不依赖于未定义的内存布局
            var x: i32 = 1;
            const ptr = &x;
            ptr.* += 1;
            x += 1;
            try expect(ptr.* == 3);
        }
    }
    // #endregion comptime_pointer
};

const compPointer = struct {
    pub fn main() !void {
        // #region comp_pointer
        comptime {
            const expect = @import("std").testing.expect;
            // 只要指针不被解引用，那么就可以这么做
            const ptr: *i32 = @ptrFromInt(0xdeadbee0);
            const addr = @intFromPtr(ptr);
            try expect(@TypeOf(addr) == usize);
            try expect(addr == 0xdeadbee0);
        }
        // #endregion comp_pointer
    }
};

const ptrCast = struct {
    const std = @import("std");
    pub fn main() !void {
        // #region ptr_cast
        const bytes align(@alignOf(u32)) = [_]u8{ 0x12, 0x12, 0x12, 0x12 };
        // 将 u8数组指针 转换为 u32 类型的指针
        const u32_ptr: *const u32 = @ptrCast(&bytes);

        if (u32_ptr.* == 0x12121212) {
            std.debug.print("success\n", .{});
        }

        // 通过标准库转为 u32
        const u32_value = std.mem.bytesAsSlice(u32, bytes[0..])[0];

        if (u32_value == 0x12121212) {
            std.debug.print("success\n", .{});
        }

        // 通过内置函数转换
        if (@as(u32, @bitCast(bytes)) == 0x12121212) {
            std.debug.print("success\n", .{});
        }
        // #endregion ptr_cast
    }
};
