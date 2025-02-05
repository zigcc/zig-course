---
outline: deep
---

# 联合类型

联合类型 (union)，它实际上是用户定义的一种特殊的类型，划分出一块内存空间用来存储多种类型，但同一时间只能存储一个类型。

## 基本使用

联合类型的基本使用：

::: code-group

<<<@/code/release/union.zig#default_basic [default]

<<<@/code/release/union.zig#more_basic [more]

:::

:::info 🅿️ 提示

需要注意的是，zig 不保证普通联合类型在内存中的表现形式！如果有需要，可以使用 `extern union` 或者 `packed union` 来保证它遵守 c 的规则。

:::

如果要初始化一个在编译期已知的字段名的联合类型，可以使用 [`@unionInit`](https://ziglang.org/documentation/master/#unionInit)：

```zig
@unionInit(
    comptime Union: type,
    comptime active_field_name: []const u8,
    init_expr
) Union
```

<<<@/code/release/union.zig#union_init

## 标记联合

联合类型可以在定义时使用枚举进行标记，并且可以通过 `@as` 函数将联合类型直接看作声明的枚举来使用（或比较）。

换种说法，`union` 是普通的联合类型，它可以存储多种值，但它无法跟踪当前值的类型。而`tag union` 则在 `union` 的基础上可以跟踪当前值的类型，更加安全。

::: info 🅿️ 提示

简单来说，就是标记联合可以辨别当前存储的类型，易于使用。

而普通的联合类型在 `ReleaseSmall` 和 `ReleaseFast` 的构建模式下，将无法检测出普通的联合类型的读取错误，例如将一个 `u64` 存储在一个 `union` 中，然后尝试将其读取为一个 `f64`，在程序员的角度看是非法的，但运行确是正常的！

:::

::: code-group

<<<@/code/release/union.zig#default_tag [default]

<<<@/code/release/union.zig#more_tag [more]

:::

如果要修改实际的载荷（即标记联合中的值），你可以使用 `*` 语法捕获指针类型：

::: code-group

<<<@/code/release/union.zig#default_capture_payload [default]

<<<@/code/release/union.zig#more_capture_payload [more]

:::

还支持使用 [`@tagName`](https://ziglang.org/documentation/master/#tagName) 来获取到对应的 name（返回的是一个 comptime 的 `[:0]const u8`，也就是字符串）：

<<<@/code/release/union.zig#tag_name

::: info 🅿️ 提示

上面的 `Small2` 也是一个标记联合类型，不过它的标记是一个匿名的枚举类型，并且该枚举类型成员为：`a`, `b`, `c`。

:::

## 自动推断

zig 也支持自动推断联合类型：

<<<@/code/release/union.zig#auto_infer

## `extern union`

`extern union` 保证内存布局与目标 C ABI 兼容。

具体可以见 [`extern struct`](advanced_type/struct.md#extern)。

## `packed union`

`packed union` 保证内存布局和声明顺序相同并且尽量紧凑，具体见 [`extern struct`](advanced_type/struct.md#packed)。
