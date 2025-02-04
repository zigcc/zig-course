---
outline: deep
---

# 数值类型

> 数值类型是语言运行时的基本类型，当它编译为机器码时，其中包含着许多的 _CPU 运算器_ 的操作指令。

## 整数

### 类型

在 zig 中，对整数的类型划分很详细，以下是类型表格：

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

同时 zig 支持任意位宽的整数，使用 `u` 或者 `i` 后面加数字即可，例如 `i7` 代表有符号的 7 位整数，整数类型允许的最大位宽为`65535`。

::: tip 🅿️ 提示
`usize` 和 `isize` 这两种类型的的大小取决于，运行程序的目标计算机 CPU 的类型：32 位 CPU 则两个类型均为 32 位，64 位同理。
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

zig 编译器对于除零的处理是分别在编译期和运行时（除 `ReleaseSmall` 构建模式外）进行检测，编译时检测出错误则直接停止编译，运行时如果出错会给出完整的堆栈跟踪。

::: details 小细节
这里的“除零”包括了 _除法_ 和 _求余_ 两种操作！
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

zig 中，有以下默认操作可以导致溢出：

- `+`（加法）
- `-`（减法）
- `-`（取反）
- `*`（乘法）
- `/`（除法）
- [`@divTrunc`](https://ziglang.org/documentation/master/#divTrunc)（除法）
- [`@divFloor`](https://ziglang.org/documentation/master/#divFloor)（除法）
- [`@divExact`](https://ziglang.org/documentation/master/#divExact)（除法）

还有在标准库 `@import("std").math` 中的函数可能导致溢出发生。

在编译期和运行时也分别有类似“除零”操作的检测和堆栈跟踪。

**处理溢出**有两种方式，一种是使用内置的溢出处理函数，一种是环绕操作符。

内置溢出处理函数：

- [`@addWithOverflow`](https://ziglang.org/documentation/master/#addWithOverflow)
- [`@subWithOverflow`](https://ziglang.org/documentation/master/#subWithOverflow)
- [`@mulWithOverflow`](https://ziglang.org/documentation/master/#mulWithOverflow)
- [`@shlWithOverflow`](https://ziglang.org/documentation/master/#shlWithOverflow)

这些内建函数返回一个元组，其中包含是否存在溢出（作为 `u1`）以及操作中可能溢出的位。

环绕操作符：

- `+%`（加法环绕）
- `-%`（减法环绕）
- `-%`（取反环绕）
- `*%`（乘法环绕）

这些操作符保证了环绕语义（它们会取计算后溢出的值）。

## 浮点数

浮点数就是表示带有小数点的数字。在 zig 中，浮点数有 `f16`、`f32`、`f64`、`f80`、`f128`、`c_longdouble`（对应 C ABI 的 `long double` ）。

值得注意的是，`comptime_float` 具有 `f128` 的精度和运算。

浮点字面量可以隐式转换为 _任意浮点类型_，如果没有小数部分的话还能够隐式转换为 _任意整数类型_。

浮点运算时遵循 `Strict` 模式，但是可以使用 `@setFloatMode(.Optimized)` 切换到 `Optimized` 模式，有关浮点运算的模式，详见 [`@setFloatMode`](https://ziglang.org/documentation/master/#setFloatMode)。

::: info 🅿️ 提示

zig 并未像其他语言那样默认提供了 NaN、无穷大、负无穷大这些语法，如果需要使用它们，请使用标准库：

<<<@/code/release/number.zig#float

:::

::: details 注意浮点数陷阱

1. 由于计算机是二进制的特性，导致浮点数往往是以近似值的方式存储（受制于浮点精度，例如有些分数无法用小数表示）。

2. 浮点数在某些操作上是反直觉的，这也是精度问题导致的，来看个例子：

```zig
const std = @import("std");

pub fn main() void {
    // assert 用于断言，常用于单元测试和调试
    std.debug.assert(0.1 + 0.2 == 0.3);
}
```

你一定以为这个可以通过断言，0.1 + 0.2 很明显就应该是 0.3 嘛，但实际上在运行时会直接崩溃！

:::

## 运算

常规的运算有等于 (`==`)，不等于 (`!=`)，大于 (`>`)，小于 (`<`)，大于等于 (`>=`)，小于等于 (`<=`)，加减乘除（`+`, `-`, `*`, `/`），左移右移 (`<<`,`>>`)，与或非 (`and`, `or`, `!`)，按位与 (`&`)，按位或 (`|`)，按位异或 (`^`)，按位非 (`~`)，

> 常见的加减乘除我们就不聊了，聊点 zig 中独具特色的小玩意。

<!-- TODO: 对等类型解析 -->

- `+|`：饱和加法，这涉及到[对等类型解析](../../advanced/type_cast.md#对等类型转换)，你现在只需要知道加法结果最多只是该类型的极限即可，例如 `u8` 类型的 255 + 1 后还是 255。
- `-|`：饱和减法，和上面一样，减法结果最小为该类型的极限。
- `*|`：饱和乘法，同上，乘法结果最大或最小为该类型的极限。
- `<<|`：饱和左移，同之前，结果为该类型的极限。
- `++`：矩阵（数组）串联，需要两个矩阵（数组）内元素类型相同。
- `**`：矩阵乘（数组）法，需要在编译期已知矩阵（数组）的大小（长度）和乘的倍数。

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

如果你有使用复数的需求，可以使用标准库中的 [`std.math.Complex`](https://ziglang.org/documentation/master/std/#std.math.complex.Complex)。

<<<@/code/release/number.zig#complex

:::
