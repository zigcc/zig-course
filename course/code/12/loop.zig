pub fn main() !void {
    ForArray.main();
    ForHandleArray.main();
    IndexFor.main();
    MultiFor.main();
    ForAsExpression.main();
    LabelFor.main();
    try InlineFor.main();
    WhileBasic.main();
    WhileContinue.main();
    LabelWhile.main();
    try InlineWhile.main();
    WhileOptional.main();

    WhileErrorUnion.main();
}

const ForArray = struct {
    pub fn main() void {
        // #region for_array
        const items = [_]i32{ 4, 5, 3, 4, 0 };
        var sum: i32 = 0;

        for (items) |value| {
            if (value == 0) {
                continue;
            }
            sum += value;
        }
        // #endregion for_array

        // #region for_integer
        for (0..5) |i| {
            _ = i;
            // do something
        }
        // #endregion for_integer
    }
};

const ForHandleArray = struct {
    pub fn main() void {
        // #region for_handle_array
        var items = [_]i32{ 3, 4, 2 };

        for (&items) |*value| {
            value.* += 1;
        }
        // #endregion for_handle_array
    }
};

const IndexFor = struct {
    pub fn main() void {
        // #region index_for
        const items = [_]i32{ 4, 5, 3, 4, 0 };
        for (items, 0..) |value, i| {
            _ = value;
            _ = i;
            // do something
        }
        // #endregion index_for
    }
};

const MultiFor = struct {
    pub fn main() void {
        // #region multi_for
        const items = [_]usize{ 1, 2, 3 };
        const items2 = [_]usize{ 4, 5, 6 };

        for (items, items2) |i, j| {
            _ = i;
            _ = j;
            // do something
        }
        // #endregion multi_for
    }
};

const ForAsExpression = struct {
    pub fn main() void {
        // #region for_as_expression
        const items = [_]?i32{ 3, 4, null, 5 };

        const result = for (items) |value| {
            if (value == 5) {
                break value;
            }
        } else 0;
        // #endregion for_as_expression

        _ = result;
    }
};

const LabelFor = struct {
    pub fn main() void {
        {
            // #region label_for_1
            var count: usize = 0;
            outer: for (1..6) |_| {
                for (1..6) |_| {
                    count += 1;
                    break :outer;
                }
            }
            // #endregion label_for_1
        }

        {
            // #region label_for_2
            var count: usize = 0;
            outer: for (1..9) |_| {
                for (1..6) |_| {
                    count += 1;
                    continue :outer;
                }
            }
            // #endregion label_for_2
        }
    }
};

const InlineFor = struct {
    // #region inline_for_more
    const std = @import("std");
    const expect = std.testing.expect;

    // #region inline_for
    pub fn main() !void {
        const nums = [_]i32{ 2, 4, 6 };
        var sum: usize = 0;
        inline for (nums) |i| {
            const T = switch (i) {
                2 => f32,
                4 => i8,
                6 => bool,
                else => unreachable,
            };
            sum += typeNameLength(T);
        }
        try expect(sum == 9);
    }

    fn typeNameLength(comptime T: type) usize {
        return @typeName(T).len;
    }

    // #endregion inline_for
    // #endregion inline_for_more
};

const WhileBasic = struct {
    // #region while_more
    const std = @import("std");

    pub fn main() void {
        // #region while_basic
        var i: usize = 0;
        while (i < 10) {
            if (i == 5) {
                continue;
            }
            std.debug.print("i is {}\n", .{i});
            i += 1;
        }
        // #endregion while_basic
        // #endregion while_more
    }
};

const WhileContinue = struct {
    pub fn main() void {
        {
            // #region while_continue_1
            var i: usize = 0;
            while (i < 10) : (i += 1) {}
            // #endregion while_continue_1
        }

        {
            // #region while_continue_2
            var i: usize = 1;
            var j: usize = 1;
            while (i * j < 2000) : ({
                i *= 2;
                j *= 3;
            }) {}
            // #endregion while_continue_2
        }
    }
};

// #region while_as_expression
fn rangeHasNumber(begin: usize, end: usize, number: usize) bool {
    var i = begin;
    return while (i < end) : (i += 1) {
        if (i == number) {
            break true;
        }
    } else false;
}
// #endregion while_as_expression

const LabelWhile = struct {
    pub fn main() void {
        {
            // #region label_while_continue
            var i: usize = 0;
            outer: while (i < 10) : (i += 1) {
                while (true) {
                    continue :outer;
                }
            }
            // #endregion label_while_continue
        }
        {
            // #region label_while_break
            outer: while (true) {
                while (true) {
                    break :outer;
                }
            }
            // #endregion label_while_break
        }
    }
};

const InlineWhile = struct {
    // #region inline_while_more
    const std = @import("std");
    const expect = std.testing.expect;

    // #region inline_while
    pub fn main() !void {
        comptime var i = 0;
        var sum: usize = 0;
        inline while (i < 3) : (i += 1) {
            const T = switch (i) {
                0 => f32,
                1 => i8,
                2 => bool,
                else => unreachable,
            };
            sum += typeNameLength(T);
        }
        try expect(sum == 9);
    }

    fn typeNameLength(comptime T: type) usize {
        return @typeName(T).len;
    }
    // #endregion inline_while
    // #endregion inline_while_more
};

const WhileOptional = struct {
    // #region while_optional_more
    const std = @import("std");

    var numbers_left: u32 = undefined;
    fn eventuallyNullSequence() ?u32 {
        return if (numbers_left == 0) null else blk: {
            numbers_left -= 1;
            break :blk numbers_left;
        };
    }

    pub fn main() void {
        var sum2: u32 = 0;
        numbers_left = 3;
        // #region while_optional
        while (eventuallyNullSequence()) |value| {
            sum2 += value;
        } else {
            std.debug.print("meet a null\n", .{});
        }
        // 还可以使用else分支，碰到第一个 null 时触发并退出循环
        // #endregion while_optional
    }
    // #endregion while_optional_more
};

const WhileErrorUnion = struct {
    // #region while_error_union_more
    const std = @import("std");
    var numbers_left: u32 = undefined;

    fn eventuallyErrorSequence() anyerror!u32 {
        return if (numbers_left == 0) error.ReachedZero else blk: {
            numbers_left -= 1;
            break :blk numbers_left;
        };
    }

    pub fn main() void {
        var sum1: u32 = 0;
        numbers_left = 3;
        // #region while_error_union
        while (eventuallyErrorSequence()) |value| {
            sum1 += value;
        } else |err| {
            std.debug.print("meet a err: {}\n", .{err});
        }
        // #endregion while_error_union
    }
    // #endregion while_error_union_more
};
