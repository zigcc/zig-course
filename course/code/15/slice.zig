pub fn main() !void {
    Basic.main();
    PointerSlice.main();
    TerminatedSlice.main();
}

const Basic = struct {
    // #region basic_more
    const print = @import("std").debug.print;

    pub fn main() void {
        // #region basic
        var array = [_]i32{ 1, 2, 3, 4 };

        const len: usize = 3;
        const slice: []i32 = array[0..len];

        for (slice, 0..) |ele, index| {
            print("第{}个元素为：{}\n", .{ index + 1, ele });
        }
        print("slice 类型为{}\n", .{@TypeOf(slice)});

        const slice_2: []i32 = array[0..array.len];
        print("slice_2 类型为{}\n", .{@TypeOf(slice_2)});
        // #endregion basic
    }
    // #endregion basic_more
};

const PointerSlice = struct {
    // #region pointer_slice_more
    const print = @import("std").debug.print;

    pub fn main() void {
        // #region pointer_slice
        var array = [_]i32{ 1, 2, 3, 4 };

        // 边界使用变量，保证切片不会被优化为数组指针
        var len: usize = 3;
        _ = &len;

        var slice = array[0..len];

        print("slice 类型为{}\n", .{@TypeOf(slice)});
        print("slice.ptr 类型为{}\n", .{@TypeOf(slice.ptr)});
        print("slice 的索引 0 取地址，得到指针类型为{}\n", .{@TypeOf(&slice[0])});
        // #endregion pointer_slice
    }
    // #endregion pointer_slice_more
};

const TerminatedSlice = struct {
    // #region terminated_slice_more
    const print = @import("std").debug.print;

    pub fn main() void {
        // #region terminated_slice
        // 显式声明切片类型
        const str_slice: [:0]const u8 = "hello";
        print("str_slice类型：{}\n", .{@TypeOf(str_slice)});

        var array = [_]u8{ 3, 2, 1, 0, 3, 2, 1, 0 };
        const runtime_length: usize = 3;
        const slice: [:0]u8 = array[0..runtime_length :0];
        print("slice类型：{}\n", .{@TypeOf(slice)});
        // #endregion terminated_slice
    }
    // #endregion terminated_slice_more
};
