# 向量

> 向量（Vector）提供了一种对一组同类型（布尔、整型、浮点、指针）值进行并行操作的方法，它会尽可能利用 `SIMD`（单指令多数据）指令集。

向量类型通过内置函数 [@Vector](https://ziglang.org/documentation/master/#Vector) 创建。

## 基本使用

向量支持与底层基本类型相同的内置运算符。这些操作都是按元素执行的，并返回一个与输入向量长度相同的向量。支持的运算符包括：

- 算术运算符 (`+`, `-`, `/`, `*`, `@divFloor`, `@sqrt`, `@ceil`, `@log`, ... )
- 位操作符 (`>>`, `<<`, `&`, `|`,`~`, ... )
- 比较运算符 (`<`, `>`, `==`, ...)

禁止混合使用标量（单个数字）和向量进行数学运算。Zig 提供了 [`@splat`](https://ziglang.org/documentation/master/#splat) 内建函数，可以方便地将标量转换为向量。同时，可以使用 [`@reduce`](https://ziglang.org/documentation/master/#reduce) 和数组索引语法将向量转换为标量。向量还支持直接赋值给已知长度的固定长度数组。如果需要重新排列元素，可以使用 [`@shuffle`](https://ziglang.org/documentation/master/#shuffle) 和 [`@select`](https://ziglang.org/documentation/master/#select) 函数。

<<<@/code/release/vector.zig#basic

::: info 🅿️ 提示

可以使用 `@as` 将向量强制转换为数组。

如果向量的长度小于目标机器的 SIMD 寄存器宽度，操作通常会编译为单个 SIMD 指令；如果向量长度更长，则会编译为多个 SIMD 指令。

如果目标体系结构不支持 SIMD，编译器将默认依次对每个向量元素进行操作。

Zig 支持最大 `2^32 - 1` 的向量长度。请注意，过长的向量长度（例如 `2^20`）可能会导致当前版本的 Zig 编译器崩溃。

:::

## 解构向量

与数组类似，向量也可以被解构：

<<<@/code/release/vector.zig#deconstruct

## `@splat`

`@splat(scalar: anytype) anytype`

生成一个向量，其所有元素都与传入的 `scalar` 参数相同。向量的类型和长度由编译器推断。

<<<@/code/release/vector.zig#splat

## `@reduce`

`@reduce(comptime op: std.builtin.ReduceOp, value: anytype) E`

使用传入的运算符对向量进行水平归约（_sequential horizontal reduction_），最终得到一个标量。

<<<@/code/release/vector.zig#reduce

::: info 🅿️ 提示

1. 所有运算符均可用于整型。
2. `.And`, `.Or`, `.Xor` 也可用于布尔类型。
3. `.Min`, `.Max`, `.Add`, `.Mul` 还可用于浮点型。

注意：`.Add` 和 `.Mul` 在整型上的操作是**环绕（wrapping）**的。

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

根据掩码 `mask`（一个向量），从向量 `a` 或向量 `b` 中选择元素，组成一个新的向量。`mask` 的长度决定了返回向量的长度。`mask` 中的每个值逐个指定从 `a` 或 `b` 中选择哪个元素：正数表示从 `a` 中选择指定索引的元素（索引从 0 开始递增），负数表示从 `b` 中选择指定索引的元素（索引从 -1 开始递减）。

::: info 🅿️ 提示

- 建议对 `b` 中的索引使用 `~` 运算符，这样两个向量的索引都可以从 0 开始（例如，`~@as(i32, 0)` 结果为 -1）。
- 如果 `mask` 中选择的元素在 `a` 或 `b` 中是 `undefined`，则结果向量中对应的元素也将是 `undefined`。
- `mask` 中的元素索引越界会导致编译错误。
- 如果 `a` 或 `b` 是 `undefined`，则其长度被视为与另一个非 `undefined` 向量的长度相同。如果 `a` 和 `b` 都是 `undefined`，`@shuffle` 将返回一个所有元素都是 `undefined` 的向量。

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

根据 `pred`（一个布尔类型的向量），按元素从 `a` 或 `b` 中选择值。如果 `pred[i]` 为 `true`，则结果向量中对应的元素为 `a[i]`；否则为 `b[i]`。

<<<@/code/release/vector.zig#select
