---
outline: deep
---

# 未定义操作

zig 本身有许多未定义行为，它们可以很方便地帮助开发者找出错误。

如果在编译期就检测到了未定义的行为，那么 zig 会发出编译错误并停止继续编译，大多数编译时无法检测到的未定义行为均会在运行时被检测到。这就是 zig 的安全检查！

> [!WARNING]
> 注意：本章节并没有 CI 检查，故可能存在内容过期的情况，具体可参考 [官方手册](https://ziglang.org/documentation/master/#Undefined-Behavior)。

安全检查会在 debug、ReleaseSafe 模式下开启，但可以使用 [`@setRuntimeSafety`](https://ziglang.org/documentation/master/#setRuntimeSafety) 来强制指定在单独的块中是否开启安全检查（这将忽略构建模式）。

当出现安全检查失败时，zig 会编译失败并触发堆栈跟踪：

```zig
test "safety check" {
    unreachable;
}
```

```sh
$ zig test test_undefined_behavior.zig
1/1 test.safety check... thread 892159 panic: reached unreachable code
/home/ci/actions-runner/_work/zig-bootstrap/zig/docgen_tmp/test_undefined_behavior.zig:2:5: 0x222c65 in test.safety check (test)
    unreachable;
    ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/test_runner.zig:181:28: 0x22da7d in mainTerminal (test)
        } else test_fn.func();
                           ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/test_runner.zig:36:28: 0x223c8a in main (test)
        return mainTerminal();
                           ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:575:22: 0x22319c in posixCallMainAndExit (test)
            root.main();
                     ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:253:5: 0x222cf1 in _start (test)
    asm volatile (switch (native_arch) {
    ^
???:?:?: 0x0 in ??? (???)
error: the following test command crashed:
/home/ci/actions-runner/_work/zig-bootstrap/out/zig-local-cache/o/4558e134302b78f1a543202d094b3e06/test
```

以下说明各种未定义行为。

## 不可达代码

即 `unreachable`，如果程序执行到它，那么会触发完整的堆栈跟踪！

## 索引越界访问

无论是数组还是切片，发生越界访问会发生错误导致程序终止进而触发堆栈跟踪！

## 负数转换为无符号整数

这本身就是非法行为，故会直接出现报错，如果仅仅是想要将负数当作无符号整数看待，可以使用 [`@bitCast`](https://ziglang.org/documentation/master/#bitCast)。

如果想要获取到无符号整数的最大值，可以使用 `std.math.maxInt`。

## 数据截断

注意我们这里指的是数据类型的范围变小了，不足以容纳数据的值，例如：

```zig
const spartan_count: u16 = 300;
const byte: u8 = @intCast(spartan_count);
```

上面这段代码毫无疑问会失败，因为 `u8` 类型无法容纳下 300 这个数。

除非，我们显式强制截断位，使用 [`@truncate`](https://ziglang.org/documentation/master/#truncate)。

## 整数溢出

常规的运算可能导致溢出，如加 `+` 减 `-` 乘 `*` 除 `/` 取反 `-` 运算可能出现溢出。

还有 [`@divTrunc`](https://ziglang.org/documentation/master/#divTrunc)、[`@divFloor`](https://ziglang.org/documentation/master/#divFloor)、[`@divExact`](https://ziglang.org/documentation/master/#divExact)，可能造成溢出。

标准库提供的函数可能存在溢出：

- `@import("std").math.add`
- `@import("std").math.sub`
- `@import("std").math.mul`
- `@import("std").math.divTrunc`
- `@import("std").math.divFloor`
- `@import("std").math.divExact`
- `@import("std").math.shl`

为了处理这些情况，zig 提供了几个溢出检测函数来处理溢出问题：

- [`@addWithOverflow`](https://ziglang.org/documentation/master/#addWithOverflow)
- [`@subWithOverflow`](https://ziglang.org/documentation/master/#subWithOverflow)
- [`@mulWithOverflow`](https://ziglang.org/documentation/master/#mulWithOverflow)
- [`@shlWithOverflow`](https://ziglang.org/documentation/master/#shlWithOverflow)

以上这些内建函数会返回一个元组，包含计算的结果和是否发生溢出的判断位。

```zig
const print = @import("std").debug.print;
pub fn main() void {
    const byte: u8 = 255;

    const ov = @addWithOverflow(byte, 10);
    if (ov[1] != 0) {
        print("overflowed result: {}\n", .{ov[0]});
    } else {
        print("result: {}\n", .{ov[0]});
    }
}
```

除此以外，我们还可以使用环绕（**Wrapping**）操作来处理计算：

- `+%` 加法环绕
- `-%` 减法环绕
- `-%` 取否环绕
- `*%` 乘法环绕

它们会取计算后溢出的值！

## 移位溢出

进行左移操作时，可能导致结果溢出，此时程序或者编译器会停止并发出警告！

## 除零操作

很显然，除零是非法操作，故会引起程序或者编译器报错！

当然，还包括求余运算，除数为零是也是非法的！

## 精确除法溢出

精确除法使用的是 [`@divExact`](https://ziglang.org/documentation/master/#divExact)，它需要保证被除数可以整除除数，否则会触发编译器错误！

## 尝试解开可选类型 Null

可选类型值是 `null` 时，如果直接使用 `variable.?` 语法来解开可选，那么会导致出现错误！

正确的处理方案是使用 [`if` 语法](../basic/process_control/decision.md#解构可选类型)来解开可选类型。

## 尝试解开错误联合类型 Error

错误联合类型如果是 `error` 时，直接使用它会导致程序或者编译器停止运行！

正确的处理方案是使用 [`if` 语法](../basic/process_control/decision.md#解构错误联合类型)来解开可选类型。

## 无效错误码

使用 [`@errorFromInt`](https://ziglang.org/documentation/master/#errorFromInt) 获取错误时，如果没有对应整数的错误，那么会导致程序或编译器报错！

## 无效枚举转换

当使用 [`@enumFromInt`](https://ziglang.org/documentation/master/#enumFromInt) 来获取枚举时，如果没有对应整数的枚举，那么会导致程序或者编译器报告错误！

## 无效错误集合转换

两个不相关的错误集不可以相互转换，如果强制使用 [`@errorCast`](https://ziglang.org/documentation/master/#errorCast)转换两个不相关的错误集，那么会导致程序或者编译器报告错误！

## 指针对齐错误

指针对齐转换可能发生错误，如：

```zig
const ptr: *align(1) i32 = @ptrFromInt(0x1);
const aligned: *align(4) i32 = @alignCast(ptr);
```

`0x1` 地址很明显是不符合 4 字节对齐，会导致编译器错误。

## 联合类型字段访问错误

如果访问的联合类型字段并非是它当前的有效字段，那么会触发非法行为！

可以通过重新分配来更改联合类型的有效字段：

```zig
const Foo = union {
    float: f32,
    int: u32,
};

var f = Foo{ .int = 42 };
f = Foo{ .float = 12.34 };
```

::: info 🅿️ 提示

注意：packed 和 extern 标记的联合类型并没有这种安全监测！

:::

## 浮点转换整数发生越界

当将浮点数转换为整数时，如果浮点数的值超出了整数类型的范围，就会发生非法越界，例如：

```zig
const float: f32 = 4294967296;
const int: i32 = @intFromFloat(float);
```

## 指针强制转换为 Null

将允许地址为 0 的指针转换为地址不可能为 0 的指针，这会触发非法行为。

C 指针、可选指针、`allowzero` 标记的指针，这些都是允许地址为 0，但普通指针是不允许的。
