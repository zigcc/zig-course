---
outline: deep
---

# 向量

> 向量（Vector）为我们提供了并行操纵一组同类型（布尔、整型、浮点、指针）的值的方法，它尽可能使用 `SIMD` 指令。

## 基本使用

向量支持与底层基本类型相同的内置运算符。这些操作是按元素执行，并返回与输入向量长度相同的向量，包括：

- 算术运算符 (`+`, `-`, `/`, `*`, `@divFloor`, `@sqrt`, `@ceil`, `@log`, ... )
- 位操作符 (`>>`, `<<`, `&`, `|`,`~`, ... )
- 比较远算符 (`<`, `>`, `==`, ...)

禁止对标量（单个数字）和向量的混合使用数学运算符，Zig 提供了 [`@splat`](https://ziglang.org/documentation/master/#splat) 内建函数来轻松从标量转换为向量，并且它支持 [`@reduce`](https://ziglang.org/documentation/master/#reduce) 和数组索引语法以从向量转换为标量，向量还支持对具有已知长度的固定长度数组进行赋值，如果需要重新排列元素，可以使用 [`@shuffle`](https://ziglang.org/documentation/master/#shuffle) 和 [`@select`](https://ziglang.org/documentation/master/#select) 函数。

<<<@/code/release/vector.zig#basic

::: info 🅿️ 提示

可以使用 `@as` 将向量转为数组。

比目标机器的 SIMD 大小短的向量的操作通常会编译为单个 SIMD 指令，而比目标机器 SIMD 大小长的向量将编译为多个 SIMD 指令。

如果给定的目标体系架构上不支持 SIMD，则编译器将默认依次对每个向量元素进行操作。

Zig 支持任何已知的最大 2^32-1 向量长度。请注意，过长的向量长度（例如 2^20）可能会导致当前版本的 Zig 上的编译器崩溃。

:::

## `@splat`

`@splat(scalar: anytype) anytype`

生成一个向量，向量的每个元素均是传入的参数 `scalar`，向量的类型和长度由编译器推断。

<<<@/code/release/vector.zig#splat

## `@reduce`

`@reduce(comptime op: std.builtin.ReduceOp, value: anytype) E`

使用传入的运算符对向量进行水平按顺序合并（_sequential horizontal reduction_），最终得到一个标量。

<<<@/code/release/vector.zig#reduce

::: info 🅿️ 提示

1. 所有的运算符均可用于整型
2. `.And`, `.Or`, `.Xor` 还可用于布尔。
3. `.Min`, `.Max`, `.Add`, `.Mul` 还可以用于浮点型。

注意：`.Add` 和 `.Mul` 在整型上的操作是 **wrapping**。

<!-- 增加说明关于浮点的 optimized 说明 -->

:::

## `@shuffle`

```zig
@shuffle(
    comptime E: type,
    a: @Vector(a_len, E),
    b: @Vector(b_len, E),
    comptime mask: @Vector(mask_len, i32)
) @Vector(mask_len, E)
```

根据掩码`mask`（一个向量 Vector），返回向量 a 或者向量 b 的值，组成一个新的向量，mask 的长度决定返回的向量的长度，并且逐个根据 mask 中的值，来从 a 或 b 选出值，正数是从 a 选出指定索引的值（从 0 开始，变大），负数是从 b 选出指定索引的值（从 -1 开始，变小）。

::: info 🅿️ 提示

- 建议对 b 中的索引使用 `~` 运算符，以便两个索引都可以从 0 开始（即 `~@as(i32, 0)` 为 -1）。
- 对于每个 mask 挑选出来的元素，如果它从 A 或 B 中的选出的值是 `undefined`，则结果元素也是 `undefined`。
- mask 中的元素索引越界会产生编译错误。
- 如果 a 或 b 是 `undefined`，该变量长度相当于另一个非 `undefined` 变量的长度。如果两个向量均是 `undefined`，则 `@shuffle` 返回所有元素是 `undefined` 的向量

:::

<<<@/code/release/vector.zig#shuffle

## `@select`

```zig
@select(
    comptime T: type,
    pred: @Vector(len, bool),
    a: @Vector(len, T),
    b: @Vector(len, T)
) @Vector(len, T)
```

根据 pred（一个元素全为布尔类型的向量）从 a 或 b 中按元素选择值。如果 `pred[i]` 为 `true`，则结果中的相应元素将为 `a[i]`，否则为 `b[i]`。

<<<@/code/release/vector.zig#select
