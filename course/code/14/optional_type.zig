pub fn main() !void {
    try ComptimeAccessOptionalType.main();
}

// #region basic_type
// 一个普通的i32整数
const normal_int: i32 = 1234;

// i32的可选类型，现在它的值可以是 i32 或者 null
const optional_int: ?i32 = 5678;
// #endregion basic_type

const Malloc = struct {
    const Foo = struct {};

    // #region malloc
    // extern 用于连接标准 libc 的 malloc 函数，它是 posix 标准之一
    extern fn malloc(size: usize) ?*u8;

    fn doAThing() ?*Foo {
        // 尝试调用 malloc 申请内存，如果失败则返回null
        const ptr = malloc(1234) orelse return null;
        _ = ptr; // ...
    }
    // #endregion malloc
};

const CheckNull = struct {
    const Foo = struct {};
    // #region check_null
    fn doSomethingWithFoo(foo: *Foo) void {
        _ = foo;
    }

    fn doAThing(optional_foo: ?*Foo) void {
        // 干点什么。。。
        if (optional_foo) |foo| {
            doSomethingWithFoo(foo);
        }
        // 干点什么。。。
    }
    // #endregion check_null
};

const ComptimeAccessOptionalType = struct {
    const expect = @import("std").testing.expect;
    pub fn main() !void {
        // #region comptime_access_optional_type
        // 声明一个可选类型，并赋值为 null
        var foo: ?i32 = null;

        // 重新赋值为子类型的值，这里是 i32
        foo = 1234;

        // 使用编译期反射来获取 foo 的类型信息
        try comptime expect(@typeInfo(@TypeOf(foo)).Optional.child == i32);
        // #endregion comptime_access_optional_type
    }
};
