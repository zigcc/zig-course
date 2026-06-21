pub fn main() !void {}

const Basic = struct {
    const std = @import("std");

    test "expect addOne adds one to 41" {

        // 标准库提供了不少有用的函数
        // testing 下的函数均是测试使用的
        // expect 会假定其参数为 true，如果不通过则报告错误
        // try 用于当 expect 返回错误时，直接返回，并通知测试运行器测试结果未通过
        try std.testing.expect(addOne(41) == 42);
    }

    test addOne {
        // test 的名字也可以使用标识符，例如我们在这里使用的就是函数名字 addOne
        try std.testing.expect(addOne(41) == 42);
    }

    /// 定义一个函数效果是给传入的参数执行加一操作
    fn addOne(number: i32) i32 {
        return number + 1;
    }
};

const Nestd = struct {
    const std = @import("std");
    const expect = std.testing.expect;

    test {
        std.testing.refAllDecls(S);
        _ = S;
        _ = U;
    }

    const S = struct {
        test "S demo test" {
            try expect(true);
        }

        const SE = enum {
            V,

            // 此处测试由于未被引用，将不会执行.
            test "This Test Won't Run" {
                try expect(false);
            }
        };
    };

    const U = union { // U 被顶层测试块引用了
        s: US, // 并且US在此处被引用，则US容器中的测试块也会被执行测试

        const US = struct {
            test "U.US demo test" {
                // This test is a top-level test declaration for the struct.
                // The struct is nested (declared) inside of a union.
                try expect(true);
            }
        };

        test "U demo test" {
            try expect(true);
        }
    };
};

test "all" {
    _ = Basic;
}

const allDecl = struct {
    const std = @import("std");
    const builtin = @import("builtin");

    pub fn refAllDecls(comptime T: type) void {
        if (!builtin.is_test) return;
        inline for (comptime std.meta.declarations(T)) |decl| {
            _ = &@field(T, decl.name);
        }
    }
};
