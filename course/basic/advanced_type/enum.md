---
outline: deep
---

# 枚举

> 枚举常用于表示一个有限集合的成员，或对特定类型的对象进行分类。

枚举是一种相对简单但用途广泛的类型。

## 声明枚举

我们可以通过 `enum` 关键字轻松地声明和使用枚举：

<<<@/code/release/enum.zig#basic_enum

同时，Zig 还允许我们访问和操作枚举的标记值：

<<<@/code/release/enum.zig#enum_with_value

在此基础上，我们还可以覆盖枚举的标记值：

<<<@/code/release/enum.zig#enum_with_value2

::: info 🅿️ 提示

枚举类型支持使用 `if` 和 `switch` 进行匹配，具体细节请参见相应章节。

:::

## 枚举方法

是的，枚举也可以拥有方法。实际上，枚举在 Zig 中是一种特殊的命名空间（可以看作一种特殊的 `struct`）。

<<<@/code/release/enum.zig#enum_with_method

## 枚举大小

需要注意的是，Zig 编译器会严格计算枚举的大小。例如，前面示例中的 `Type` 枚举，其大小等效于 `u1`。

以下示例中，我们使用了内建函数 `@typeInfo` 和 `@tagName` 来获取枚举的大小和对应的标签名称（tag name）：

<<<@/code/release/enum.zig#enum_size

## 枚举推断

枚举也支持类型推断（通过结果位置语义），即在已知枚举类型的情况下，可以仅使用字段名来指定枚举值：

<<<@/code/release/enum.zig#enum_reference

## 非详尽枚举

Zig 允许我们定义非详尽枚举，即在定义时无需列出所有可能的成员。未列出的成员可以使用 `_` 来表示。由于存在未列出的成员，编译器无法自动推断枚举的大小，因此必须显式指定其底层类型。

<<<@/code/release/enum.zig#non_exhaustive_enum

:::info 🅿️ 提示

`@enumFromInt` 能够将整数转换为枚举值。但需要注意，如果所选枚举类型中没有表示该整数的值，就会导致[未定义行为](../../advanced/undefined_behavior#无效枚举转换)。

如果目标枚举类型是非详尽枚举，那么除了涉及 `@intCast` 相关的安全检查之外，`@enumFromInt` 始终能够得到有效的枚举值。

:::

<<<@/code/release/enum.zig#enum_from_int

## `EnumLiteral`

::: info 🅿️ 提示

此部分内容并非初学者需要掌握的内容，它涉及到 Zig 的类型系统和[编译期反射](../../advanced/reflection#构建新的类型)，可以暂且跳过！

:::

Zig 还包含一个特殊的类型 `EnumLiteral`，它是 [`std.builtin.Type`](https://ziglang.org/documentation/master/std/#std.builtin.Type) 的一部分。

我们可以称之为“枚举字面量”。它是一个与 `enum` 完全不同的类型。可以查看 Zig 类型系统对 `enum` 的[定义](https://ziglang.org/documentation/master/std/#std.builtin.Type.Enum)，其中并不包含 `EnumLiteral`。

它的具体用法如下：

<<<@/code/release/enum.zig#enum_literal

注意：此类型常用于函数参数。

## extern

注意，我们通常不直接对枚举使用 `extern` 关键字。

默认情况下，Zig 不保证枚举与 C ABI 兼容，但我们可以通过指定其标记类型来确保兼容性：

```zig
const Foo = enum(c_int) { a, b, c };
```
