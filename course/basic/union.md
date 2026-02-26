---
outline: deep
---

# 联合类型

联合类型（Union）是一种特殊的复合类型，其所有字段**共享同一块内存空间**。联合的大小等于其最大字段的大小（可能包含对齐填充）。在任何给定时间点，联合只能存储其中一种类型的值——写入一个字段会使其他字段的数据失效。

## 基本使用

联合类型的基本使用示例如下：

::: code-group

<<<@/code/release/union.zig#default_basic [default]

<<<@/code/release/union.zig#more_basic [more]

:::

:::info 🅿️ 提示

需要注意的是，Zig 不保证普通联合类型在内存中的具体表现形式。如果需要确保其内存布局与 C 兼容，可以使用 `extern union` 或 `packed union`。

:::

如果要初始化一个在编译期已知字段名的联合类型，可以使用 [`@unionInit`](https://ziglang.org/documentation/master/#unionInit) 内建函数：

```zig
@unionInit(
    comptime Union: type,
    comptime active_field_name: []const u8,
    init_expr
) Union
```

<<<@/code/release/union.zig#union_init

## 标记联合（Tagged Union）

联合类型在定义时可以使用枚举进行标记，并且可以通过 `@as` 函数将联合类型直接视为声明的枚举来使用或比较。

换句话说，普通的 `union` 可以存储多种值，但无法跟踪当前存储的是哪种类型。而**标记联合**（`tag union`）则在 `union` 的基础上增加了类型跟踪能力，使其更加安全和易用。

::: info 🅿️ 提示

简单来说，标记联合可以明确辨别当前存储的类型，使用起来更方便。

而普通联合类型在 `ReleaseSmall` 和 `ReleaseFast` 构建模式下，将无法检测出错误的读取行为。例如，将一个 `u64` 存储在一个 `union` 中，然后尝试将其读取为一个 `f64`，这在程序员看来是非法的，但在这些构建模式下运行时却可能不会报错！

:::

::: code-group

<<<@/code/release/union.zig#default_tag [default]

<<<@/code/release/union.zig#more_tag [more]

:::

如果要修改实际的载荷（即标记联合中的值），可以使用 `*` 语法捕获指针类型：

::: code-group

<<<@/code/release/union.zig#default_capture_payload [default]

<<<@/code/release/union.zig#more_capture_payload [more]

:::

还支持使用 [`@tagName`](https://ziglang.org/documentation/master/#tagName) 来获取当前活跃字段的名称（返回一个编译期常量 `[:0]const u8`，即字符串）：

<<<@/code/release/union.zig#tag_name

::: info 🅿️ 提示

上面的 `Small2` 也是一个标记联合类型，不过它的标记是一个匿名的枚举类型，并且该枚举类型成员为：`a`, `b`, `c`。

:::

## 自动推断

Zig 也支持自动推断联合类型：

<<<@/code/release/union.zig#auto_infer

## `extern union`

`extern union` 保证其内存布局与目标 C ABI 兼容。

具体用法请参见 [`extern struct`](advanced_type/struct.md#extern) 部分。

## `packed union`

`packed union` 保证其内存布局与声明顺序相同，并且尽可能紧凑。具体用法请参见 [`packed struct`](advanced_type/struct.md#packed) 部分。
