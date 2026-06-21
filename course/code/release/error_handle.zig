pub fn main() !void {
    BasicUse.main();
    JustOneError.main();
}

const BasicUse = struct {
    // #region BasicUse
    const std = @import("std");

    // 定义一个错误集合类型
    const FileOpenError = error{
        AccessDenied,
        OutOfMemory,
        FileNotFound,
    };

    // 定义另一个错误集合类型
    const AllocationError = error{
        OutOfMemory,
    };

    pub fn main() void {
        const err = foo(AllocationError.OutOfMemory);
        if (err == FileOpenError.OutOfMemory) {
            std.debug.print("error is OutOfMemory\n", .{});
        }
    }

    fn foo(err: AllocationError) FileOpenError {
        return err;
    }
    // #endregion BasicUse
};

const JustOneError = struct {
    pub fn main() void {
        {
            // #region JustOneError1
            const err = error.FileNotFound;
            // #endregion JustOneError1
            if (err != anyerror.OutOfMemory) {}
        }

        {
            // #region JustOneError2
            const err = (error{FileNotFound}).FileNotFound;
            // #endregion JustOneError2
            if (err != anyerror.OutOfMemory) {}
        }
    }
};

const ConvertEnglishToInteger = struct {
    // #region ConvertEnglishToInteger
    const std = @import("std");
    const maxInt = std.math.maxInt;

    pub fn parseU64(buf: []const u8, radix: u8) !u64 {
        var x: u64 = 0;

        for (buf) |c| {
            const digit = charToDigit(c);

            if (digit >= radix) {
                return error.InvalidChar;
            }

            // x *= radix
            var ov = @mulWithOverflow(x, radix);
            if (ov[1] != 0) return error.OverFlow;

            // x += digit
            ov = @addWithOverflow(ov[0], digit);
            if (ov[1] != 0) return error.OverFlow;
            x = ov[0];
        }

        return x;
    }

    fn charToDigit(c: u8) u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            else => maxInt(u8),
        };
    }
    // #endregion ConvertEnglishToInteger
};

test "parse u64" {
    const result = try ConvertEnglishToInteger.parseU64("1234", 10);
    try @import("std").testing.expect(result == 1234);
}

const CatchBasic = struct {
    const parseU64 = ConvertEnglishToInteger.parseU64;
    // #region CatchBasic
    fn doAThing(str: []u8) void {
        const number = parseU64(str, 10) catch 13;
        _ = number; // ...
    }
    // #endregion CatchBasic
};

const CatchAdvanced = struct {
    const parseU64 = ConvertEnglishToInteger.parseU64;
    // #region CatchAdvanced
    fn doAThing(str: []u8) void {
        const number = parseU64(str, 10) catch blk: {
            //   指定某些复杂逻辑处理
            break :blk 13;
        };
        _ = number; // 这里的 number 已经被初始化
    }
    // #endregion CatchAdvanced
};

const TryBasic = struct {
    const parseU64 = ConvertEnglishToInteger.parseU64;
    // #region TryBasic1
    fn doAThing1(str: []u8) !void {
        const number = try parseU64(str, 10);
        _ = number;
    }
    // #endregion TryBasic1

    // #region TryBasic2
    fn doAThing2(str: []u8) !void {
        const number = parseU64(str, 10) catch |err| return err;
        _ = number;
    }
    // #endregion TryBasic2
};

const AssertNoError = struct {
    const parseU64 = ConvertEnglishToInteger.parseU64;
    // #region AssertNoError
    const number = parseU64("1234", 10) catch unreachable;
    // #endregion AssertNoError
};

const PreciseErrorHandle = struct {
    const parseU64 = ConvertEnglishToInteger.parseU64;
    fn doSomethingWithNumber(_: u64) void {}

    // #region PreciseErrorHandle
    fn doAThing(str: []u8) void {
        if (parseU64(str, 10)) |number| {
            doSomethingWithNumber(number);
        } else |err| switch (err) {
            error.Overflow => {
                // 处理溢出
            },
            // 此处假定这个错误不会发生
            error.InvalidChar => unreachable,
            // 这里你也可以使用 else 来捕获额外的错误
            else => |leftover_err| return leftover_err,
        }
    }
    // #endregion PreciseErrorHandle
};

const NotHandleError = struct {
    const parseU64 = ConvertEnglishToInteger.parseU64;
    fn doSomethingWithNumber(_: u64) void {}

    // #region NotHandleError
    fn doADifferentThing(str: []u8) void {
        if (parseU64(str, 10)) |number| {
            doSomethingWithNumber(number);
        } else |_| {
            // 你也可以在这里做点额外的事情
        }
        // 或者你也可以这样：
        parseU64(str, 10) catch {};
    }
    // #endregion NotHandleError
};

const ErrDefer = struct {
    const std = @import("std");

    // #region DeferErrorCapture
    fn deferErrorCaptureExample() !void {
        // 捕获错误
        errdefer |err| {
            std.debug.print("the error is {s}\n", .{@errorName(err)});
        }

        return error.DeferError;
    }
    // #endregion DeferErrorCapture
};

const DeferErrDefer = struct {
    // #region DeferErrDefer
    const std = @import("std");
    const Allocator = std.mem.Allocator;

    const Foo = struct {
        data: u32,
    };

    fn tryToAllocateFoo(allocator: Allocator) !*Foo {
        return allocator.create(Foo);
    }

    fn deallocateFoo(allocator: Allocator, foo: *Foo) void {
        allocator.destroy(foo);
    }

    fn getFooData() !u32 {
        return 666;
    }

    fn createFoo(allocator: Allocator, param: i32) !*Foo {
        const foo = getFoo: {
            var foo = try tryToAllocateFoo(allocator);
            errdefer deallocateFoo(allocator, foo);

            foo.data = try getFooData();

            break :getFoo foo;
        };
        // This lasts for the rest of the function
        errdefer deallocateFoo(allocator, foo);

        // Error is now properly handled by errdefer
        if (param > 1337) return error.InvalidParam;

        return foo;
    }
    // #endregion DeferErrDefer
};

test "createFoo" {
    try @import("std").testing.expectError(error.InvalidParam, DeferErrDefer.createFoo(@import("std").testing.allocator, 2468));
}

const ReferError = struct {

    // #region ReferError
    // 由编译器推导而出的错误集
    pub fn add_inferred(comptime T: type, a: T, b: T) !T {
        const ov = @addWithOverflow(a, b);
        if (ov[1] != 0) return error.Overflow;
        return ov[0];
    }

    // 明确声明的错误集
    pub fn add_explicit(comptime T: type, a: T, b: T) Error!T {
        const ov = @addWithOverflow(a, b);
        if (ov[1] != 0) return error.Overflow;
        return ov[0];
    }

    const Error = error{
        Overflow,
    };
    // #endregion ReferError
};
