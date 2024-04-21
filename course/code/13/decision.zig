pub fn main() !void {
    try Basic.main();
    try MatchEnum.main();
    try TernayExpress.main();
    try DestructOptional.main();
    try DestructErrorUnion.main();
    try DestructErrorOptionalUnion.main();
}

const Basic = struct {
    // #region more_if
    const print = @import("std").debug.print;

    pub fn main() !void {
        // #region default_if
        const num: u8 = 1;
        if (num == 1) {
            print("num is 1\n", .{});
        } else if (num == 2) {
            print("num is 2\n", .{});
        } else {
            print("num is other\n", .{});
        }
        // #endregion default_if
    }
    // #endregion more_if
};

const MatchEnum = struct {
    // #region more_match_enum
    const std = @import("std");

    pub fn main() !void {
        // #region default_match_enum
        const Small = enum {
            one,
            two,
            three,
            four,
        };

        const demo = Small.one;
        if (demo == Small.one) {
            std.debug.print("{}\n", .{demo});
        }
        // #endregion default_match_enum
    }
    // #endregion more_match_enum
};

const TernayExpress = struct {
    // #region more_ternary
    const print = @import("std").debug.print;

    pub fn main() !void {
        // #region default_ternary
        const a: u32 = 5;
        const b: u32 = 4;
        // 下方 result 的值应该是47
        const result = if (a != b) 47 else 3089;

        print("result is {}\n", .{result});
        // #endregion default_ternary
    }
    // #endregion more_ternary
};

const DestructOptional = struct {
    const std = @import("std");
    const expect = std.testing.expect;

    fn a() !void {
        // #region destruct_optional
        const val: ?u32 = null;
        if (val) |real_b| {
            _ = real_b;
        } else {
            try expect(true);
        }
        // #endregion destruct_optional
    }

    fn b() !void {
        // #region capture_optional_pointer
        var c: ?u32 = 3;
        if (c) |*value| {
            value.* = 2;
        }
        // #endregion capture_optional_pointer
    }

    pub fn main() !void {
        try a();
        try b();
    }
};

const DestructErrorUnion = struct {
    const std = @import("std");
    const expect = std.testing.expect;

    fn a() !void {
        // #region destruct_error_union
        const val: anyerror!u32 = 0;
        if (val) |value| {
            try expect(value == 0);
        } else |err| {
            _ = err;
            unreachable;
        }
        // #endregion destruct_error_union
    }

    fn b() !void {
        const val: anyerror!u32 = error.BadValue;
        // #region only_catch_error
        if (val) |_| {} else |err| {
            try expect(err == error.BadValue);
        }
        // #endregion only_catch_error
    }

    fn c() !void {
        // #region catch_pointer
        var val: anyerror!u32 = 3;
        if (val) |*value| {
            value.* = 9;
        } else |_| {
            unreachable;
        }
        // #endregion catch_pointer
    }

    pub fn main() !void {
        try a();
        try b();
        try c();
    }
};

const DestructErrorOptionalUnion = struct {
    const std = @import("std");
    const expect = std.testing.expect;
    pub fn main() !void {
        // #region destruct_error_optional_union
        const a: anyerror!?u32 = 0;
        if (a) |optional_value| {
            try expect(optional_value.? == 0);
        } else |err| {
            _ = err;
        }
        // #endregion destruct_error_optional_union
        // #region destruct_error_optional_union_pointer
        var d: anyerror!?u32 = 3;
        if (d) |*optional_value| {
            if (optional_value.*) |*value| {
                value.* = 9;
            }
        } else |_| {
            // nothing
        }
        // #endregion destruct_error_optional_union_pointer
    }
};
