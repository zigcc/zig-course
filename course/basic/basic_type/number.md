# 数值类型

> 数值类型是编程语言中最基本的数据类型之一。当它们被编译成机器码时，通常会对应到 CPU 运算器的操作指令。

## 整数

### 类型

在 Zig 中，整数类型划分非常详细，具体如下表所示：

| 类型           | 对应 C 类型          | 描述                           |
| -------------- | -------------------- | ------------------------------ |
| `i8`           | `int8_t`             | 有符号 8 位整数                |
| `u8`           | `uint8_t`            | 无符号 8 位整数                |
| `i16`          | `int16_t`            | 有符号 16 位整数               |
| `u16`          | `uint16_t`           | 无符号 16 位整数               |
| `i32`          | `int32_t`            | 有符号 32 位整数               |
| `u32`          | `uint32_t`           | 无符号 32 位整数               |
| `i64`          | `int64_t`            | 有符号 64 位整数               |
| `u64`          | `uint64_t`           | 无符号 64 位整数               |
| `i128`         | `__int128`           | 有符号 128 位整数              |
| `u128`         | `unsigned __int128`  | 无符号 128 位整数              |
| `isize`        | `intptr_t`           | 有符号指针大小的整数           |
| `usize`        | `uintptr_t` `size_t` | 无符号指针大小的整数           |
| `comptime_int` | 无                   | 编译期的整数，整数字面量的类型 |

<<<@/code/release/number.zig#type

同时，Zig 支持任意位宽的整数。通过在 `u`（无符号）或 `i`（有符号）后加上数字即可定义，例如 `i7` 代表有符号的 7 位整数。整数类型允许的最大位宽为 `65535`。

::: tip 🅿️ 提示
`usize` 和 `isize` 这两种类型的大小取决于目标 CPU 架构：在 32 位系统上它们是 32 位，在 64 位系统上则是 64 位。
:::

### 不同进制

你可以使用以下方式书写字面量：

| 字面量   | 示例       |
| -------- | ---------- |
| 十进制   | 98222      |
| 十六进制 | 0xff       |
| 八进制   | 0o755      |
| 二进制   | 0b11110000 |

### 除零

Zig 编译器会在编译期和运行时（`ReleaseSmall` 构建模式除外）对除零操作进行检测。编译时检测到错误会直接停止编译；运行时如果发生除零，则会给出完整的堆栈跟踪。

::: details 小细节
这里的“除零”包括了除法和求余两种操作。
:::

编译期：

```zig
comptime {
    const a: i32 = 1;
    const b: i32 = 0;
    const c = a / b;
    _ = c;
}
```

```sh
$ zig test test_comptime_division_by_zero.zig
docgen_tmp/test_comptime_division_by_zero.zig:4:19: error: division by zero here causes undefined behavior
    const c = a / b;
                  ^
```

运行时：

```zig
const std = @import("std");

pub fn main() void {
    var a: u32 = 1;
    var b: u32 = 0;
    var c = a / b;
    std.debug.print("value: {}\n", .{c});
}
```

```sh
$ zig build-exe runtime_division_by_zero.zig
$ ./runtime_division_by_zero
thread 2456131 panic: division by zero
/home/ci/actions-runner/_work/zig-bootstrap/zig/docgen_tmp/runtime_division_by_zero.zig:6:15: 0x21e83e in main (runtime_division_by_zero)
    var c = a / b;
              ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:564:22: 0x21e082 in posixCallMainAndExit (runtime_division_by_zero)
            root.main();
                     ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:243:5: 0x21dbd1 in _start (runtime_division_by_zero)
    asm volatile (switch (native_arch) {
    ^
???:?:?: 0x0 in ??? (???)
(process terminated by signal)
```

### 溢出

在 Zig 中，以下默认操作可能导致溢出：

- `+`（加法）
- `-`（减法）
- `-`（取反）
- `*`（乘法）
- `/`（除法）
- [`@divTrunc`](https://ziglang.org/documentation/master/#divTrunc)（除法）
- [`@divFloor`](https://ziglang.org/documentation/master/#divFloor)（除法）
- [`@divExact`](https://ziglang.org/documentation/master/#divExact)（除法）

标准库 `@import("std").math` 中的某些函数也可能导致溢出。

在编译期和运行时，Zig 也会对溢出进行检测，并提供类似“除零”操作的堆栈跟踪。

**处理溢出**有两种主要方式：使用内置的溢出处理函数，或使用环绕操作符。

内置溢出处理函数：

- [`@addWithOverflow`](https://ziglang.org/documentation/master/#addWithOverflow)
- [`@subWithOverflow`](https://ziglang.org/documentation/master/#subWithOverflow)
- [`@mulWithOverflow`](https://ziglang.org/documentation/master/#mulWithOverflow)
- [`@shlWithOverflow`](https://ziglang.org/documentation/master/#shlWithOverflow)

这些内建函数返回一个元组，其中包含一个布尔值（`u1` 类型）指示是否发生溢出，以及操作结果。

环绕操作符：

- `+%`（加法环绕）
- `-%`（减法环绕）
- `-%`（取反环绕）
- `*%`（乘法环绕）

这些操作符保证了环绕语义（即当结果超出类型范围时，会从另一端“环绕”回来）。

## 浮点数

浮点数用于表示带有小数点的数字。在 Zig 中，浮点数类型包括 `f16`、`f32`、`f64`、`f80`、`f128`，以及 `c_longdouble`（对应 C ABI 的 `long double`）。

值得注意的是，`comptime_float` 具有 `f128` 的精度和运算能力。

浮点字面量可以隐式转换为**任意浮点类型**。如果浮点字面量没有小数部分，它还可以隐式转换为**任意整数类型**。

浮点运算默认遵循 `Strict` 模式，但可以使用 `@setFloatMode(.Optimized)` 切换到 `Optimized` 模式。有关浮点运算模式的详细信息，请参见 [`@setFloatMode`](https://ziglang.org/documentation/master/#setFloatMode)。

::: info 🅿️ 提示

Zig 并未像其他语言那样默认提供 `NaN`、无穷大、负无穷大等字面量语法。如果需要使用它们，请通过标准库获取：

<<<@/code/release/number.zig#float

:::

::: details 注意浮点数陷阱

1. 由于计算机内部使用二进制表示，浮点数通常以近似值存储（受限于浮点精度，例如某些分数无法精确表示）。

2. 浮点数在某些操作上可能反直觉，这同样是精度问题导致的。例如：

```zig
const std = @import("std");

pub fn main() void {
    // assert 用于断言，常用于单元测试和调试
    std.debug.assert(0.1 + 0.2 == 0.3);
}
```

你可能会认为这个断言会通过，因为 0.1 + 0.2 显然等于 0.3。但实际上，这段代码在运行时会直接崩溃！

:::

## 运算

常规运算包括：等于 (`==`)，不等于 (`!=`)，大于 (`>`)，小于 (`<`)，大于等于 (`>=`)，小于等于 (`<=`)，加减乘除（`+`, `-`, `*`, `/`），左移右移 (`<<`, `>>`)，逻辑与或非 (`and`, `or`, `!`)，按位与 (`&`)，按位或 (`|`)，按位异或 (`^`)，按位非 (`~`)。

> 常见的加减乘除运算在此不再赘述，我们来聊聊 Zig 中独具特色的一些操作符。

<!-- TODO: 对等类型解析 -->

- `+|`：饱和加法。这涉及到[对等类型解析](../../advanced/type_cast.md#对等类型转换)。简单来说，加法结果不会超过该类型的最大值。例如，`u8` 类型的 255 加 1 后仍然是 255。
- `-|`：饱和减法。与饱和加法类似，减法结果不会低于该类型的最小值。
- `*|`：饱和乘法。乘法结果不会超过该类型的最大值或最小值。
- `<<|`：饱和左移。左移结果不会超过该类型的最大值。
- `++`：数组串联。要求两个数组的元素类型相同。
- `**`：数组重复。在编译期已知数组的长度和重复次数。

运算的优先级：

```zig
// 以下有一部分运算符你没见过不要紧，后续会讲解
x() x[] x.y x.* x.?
a!b
x{}
!x -x -%x ~x &x ?x
* / % ** *% *| ||
+ - ++ +% -% +| -|
<< >> <<|
& ^ | orelse catch
== != < > <= >=
and
or
= *= *%= *|= /= %= += +%= +|= -= -%= -|= <<= <<|= >>= &= ^= |=
```

::: tip 🅿️ 提示

如果你需要使用复数，可以使用标准库中的 [`std.math.Complex`](https://ziglang.org/documentation/master/std/#std.math.complex.Complex)。

<<<@/code/release/number.zig#complex

:::
