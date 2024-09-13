pub fn main() !void {
    CreateArray.main();
    Matrix.main();
    TerminatedArray.main();
    Multiply.main();
    Connect.main();
    FuncInitArray.main();
    ComptimeInitArray.main();
}

const CreateArray = struct {
    // #region create_array
    const print = @import("std").debug.print;

    pub fn main() void {
        const message = [5]u8{ 'h', 'e', 'l', 'l', 'o' };
        // const message = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
        print("{s}\n", .{message}); // hello
        print("{c}\n", .{message[0]}); // h
    }
    // #endregion create_array
};

const Matrix = struct {
    // #region matrix
    const print = @import("std").debug.print;

    pub fn main() void {
        const matrix_4x4 = [4][4]f32{
            [_]f32{ 1.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 1.0, 0.0, 1.0 },
            [_]f32{ 0.0, 0.0, 1.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 1.0 },
        };

        for (matrix_4x4, 0..) |arr_val, arr_index| {
            for (arr_val, 0..) |val, index| {
                print("元素{}-{}是: {}\n", .{ arr_index, index, val });
            }
        }
    }
    // #endregion matrix
};

const TerminatedArray = struct {
    // #region terminated_array
    const print = @import("std").debug.print;

    pub fn main() void {
        const array = [_:0]u8{ 1, 2, 3, 4 };
        print("数组长度为: {}\n", .{array.len}); // 4
        print("数组最后一个元素值: {}\n", .{array[array.len - 1]}); // 4
        print("哨兵值为: {}\n", .{array[array.len]}); // 0
    }
    // #endregion terminated_array
};

const Multiply = struct {
    // #region multiply
    const print = @import("std").debug.print;

    pub fn main() void {
        const small = [3]i8{ 1, 2, 3 };
        const big: [9]i8 = small ** 3;
        print("{any}\n", .{big}); // [9]i8{ 1, 2, 3, 1, 2, 3, 1, 2, 3 }
    }
    // #endregion multiply
};

const Connect = struct {
    // #region connect
    const print = @import("std").debug.print;

    pub fn main() void {
        const part_one = [_]i32{ 1, 2, 3, 4 };
        const part_two = [_]i32{ 5, 6, 7, 8 };
        const all_of_it = part_one ++ part_two; // [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 }

        _ = all_of_it;
    }
    // #endregion connect
};

const FuncInitArray = struct {
    // #region func_init_array
    const print = @import("std").debug.print;

    pub fn main() void {
        const array = [_]i32{make(3)} ** 10;
        print("{any}\n", .{array});
    }

    fn make(x: i32) i32 {
        return x + 1;
    }
    // #endregion func_init_array
};

const ComptimeInitArray = struct {
    // #region comptime_init_array
    const print = @import("std").debug.print;

    pub fn main() void {
        const fancy_array = init: {
            var initial_value: [10]usize = undefined;
            for (&initial_value, 0..) |*pt, i| {
                pt.* = i;
            }
            break :init initial_value;
        };
        print("{any}\n", .{fancy_array});
    }
    // #endregion comptime_init_array
};
