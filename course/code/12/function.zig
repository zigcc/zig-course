//! 该文件有一部分函数没有进行测试，仅定义
//! ExitProcess 和 atan2 函数是外部函数，不会进行测试。
pub fn main() !void {
    _ = add(1, 2);
    _ = max(u8, 1, 2);
    {
        const num: u8 = 1;
        _ = addFortyTwo(num);
    }
    _ = sub(2, 1);

    // 需要注意这是个死循环函数，不会返回。
    abort();

    _ = shiftLeftOne(1);
}

// #region closure
fn bar(comptime x: i32) fn (i32) i32 {
    // #region lambda
    const res = struct {
        pub fn foo(y: i32) i32 {
            var counter = 0;
            for (x..y) |i| {
                if ((i % 2) == 0) {
                    counter += i * i;
                }
            }
            return counter;
        }
    }.foo;
    // #endregion lambda
    return res;
}
// #endregion closure

// #region add
pub fn add(a: u8, b: u8) u8 {
    return a + b;
}
// #endregion add

// #region max
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
// #endregion max

// #region addFortyTwo
fn addFortyTwo(x: anytype) @TypeOf(x) {
    return x + 42;
}
// #endregion addFortyTwo

// #region ExitProcess
const WINAPI = @import("std").os.windows.WINAPI;
extern "kernel32" fn ExitProcess(exit_code: c_uint) callconv(WINAPI) noreturn;
// #endregion ExitProcess

// #region sub
export fn sub(a: i8, b: i8) i8 {
    return a - b;
}
// #endregion sub

// #region atan2
extern "c" fn atan2(a: f64, b: f64) f64;
// #endregion atan2

// #region abort
fn abort() noreturn {
    @setCold(true);
    while (true) {}
}
// #endregion abort

// #region shiftLeftOne
// 强制该函数在所有被调用位置内联，否则失败。
inline fn shiftLeftOne(a: u32) u32 {
    return a << 1;
}
// #endregion shiftLeftOne
