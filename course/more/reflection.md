---
outline: deep
---

# 反射

> 在计算机学中，反射（**reflection**），是指计算机程序在运行时（**runtime**）可以访问、检测和修改它本身状态或行为的一种能力。用比喻来说，反射就是程序在运行的时候能够“观察”并且修改自己的行为。

事实上，由于 zig 是一门强类型的静态语言，因此它的反射是在编译期实现的，允许我们观察已有的类型，并根据已有类型的信息来创造新的类型！

## 观察已有类型

zig 提供了不少函数来获取已有类型的信息，如：`@TypeOf`、`@typeName`、`@typeInfo`、`@hasDecl`、`@hasField`、`@field`、`@fieldParentPtr`、`@call`。

### `@TypeOf`

[`@TypeOf`](https://ziglang.org/documentation/master/#TypeOf)，该内建函数用于使用获取变量的类型。

原型为：`@TypeOf(...) type`

它接受任意个表达式作为参数，并返回它们的公共可转换类型（使用 [对等类型转换](../advanced/type_cast.md#对等类型转换)），表达式会完全在编译期执行，并且不会产生任何副作用（可以看作仅仅进行来类型计算）。

```zig
// 会触发编译器错误，因为 bool 和 float 类型无法进行比较
// 无法执行对等类型转换
_ = @TypeOf(true, 5.2);
// 结果为 comptime_float
_ = @TypeOf(2, 5.2);
```

无副作用是指：

<<<@/code/release/reflection.zig#no_effects

以上这段测试完全可以运行通过，原因在于，`@TypeOf` 仅仅执行了类型计算，并没有真正地执行函数体的内容，故函数 `foo` 的效果并不会真正生效！

### `@typeName`

[`@typeName`](https://ziglang.org/documentation/master/#typeName)，该内建函数用于获取类型的名字。

该函数返回的类型名字完全是一个字符串字面量，并且包含其父容器的名字（通过 `.` 分隔）：

<<<@/code/release/reflection.zig#typeName

```sh
$ zig build run
main.T
main.T.Y
```

### `@typeInfo`

[`@typeInfo`](https://ziglang.org/documentation/master/#typeInfo)，该内建函数用于获取类型的信息。

该函数返回一个 [`std.builtin.Type`](https://ziglang.org/documentation/master/std/#std.builtin.Type)，它包含了此类型的所有信息。

它是一个联合类型，有 `Struct`, `Union`, `Enum`, `ErrorSet` 等变体来储存结构体、联合、枚举、错误集等类型的类型信息。要判断类型的种类，可以使用 `switch` 或直接访问相应变体来断言之。

对结构、联合、枚举和错误集合，它保证信息中字段的顺序与源码中出现的顺序相同。

对结构、联合、枚举和透明类型，它保证信息中声明的顺序与源码中出现的顺序相同。

如以下示例中，首先使用`@typeInfo` 来获取类型 `T` 的信息，然后将其断言为一个 `Struct` 类型，最后用 `inline for` 输出其字段值。

<<<@/code/release/reflection.zig#typeInfo

需要注意的是，我们必须使用 `inline for` 才能编译通过，这是因为结构体的 **“字段类型”** [`std.builtin.Type.StructField`](https://ziglang.org/documentation/master/std/#std.builtin.Type.StructField)中的一个字段是 `comptime_int`类型，使得 StructField 没有运行时大小，从而不能在运行时遍历其数组，必须用 `inline for` 在编译期计算。

::: warning

获得的类型信息不能用于修改已有类型，但我们可以用这些信息在编译期构建新的类型！

:::

在以下示例中，使用 `@typeInfo` 获得一个整数类型的长度，并返回和它的长度相同的`u8`数组类型。当位数不为 8 的整倍数时，产生一个编译错误。

<<<@/code/release/reflection.zig#TypeInfo2

在以下示例中，使用 `@typeInfo` 获得一个结构体的信息，并使用 `@Type` 构造一个新的类型。构造的新结构体类型和原结构体的字段名和顺序相同，但结构体的内存布局被改为 extern，且每个字段的对齐被改为 1。

<<<@/code/release/reflection.zig#TypeInfo3

在以上示例中，我们将原类型的类型信息稍作修改，构造了一个新的类型。可以看到，虽然我们修改了得到的 `MyStruct` 的类型信息，但 `MyStruct` 本身并没有变化。

### `@hasDecl`

[`@hasDecl`](https://ziglang.org/documentation/master/#hasDecl) 用于返回一个容器中是否包含指定名字的声明。

完全是编译期计算的，故值也是编译期已知的。

<<<@/code/release/reflection.zig#hasDecl

### `@hasField`

[`@hasField`](https://ziglang.org/documentation/master/#hasField) 和 [`@hasDecl`](https://ziglang.org/documentation/master/#hasDecl) 类似，但作用于字段，它会返回一个结构体类型（联合类型、枚举类型）是否包含指定名字的字段。

完全是编译期计算的，故值也是编译期已知的。

<<<@/code/release/reflection.zig#hasField

### `@field`

[`@field`](https://ziglang.org/documentation/master/#field) 用于获取变量（容器类型）的字段或者容器类型的声明。

<<<@/code/release/reflection.zig#Field

::: info 🅿️ 提示

注意：`@field` 作用于变量时只能访问字段，而作用于类型时只能访问声明。

:::

### `@fieldParentPtr`

[`@fieldParentPtr`](https://ziglang.org/documentation/master/#fieldParentPtr) 根据给定的指向结构体字段的指针和名字，可以获取结构体的基指针。

<<<@/code/release/reflection.zig#fieldParentPtr

### `@call`

[`@call`](https://ziglang.org/documentation/master/#call) 调用一个函数，和普通的函数调用方式相同。

它接收一个调用修饰符、一个函数、一个元组作为参数。

<<<@/code/release/reflection.zig#call

## 构建新的类型

zig 除了获取类型信息外，还提供了在编译期构建全新类型的能力，允许我们通过非常规的方式来声明一个类型。

构建新类型的能力主要依赖于 `@Type`。

### `@Type`

该函数实际上就是 `@typeInfo` 的反函数，它将类型信息具体化为一个类型。

函数的原型为：

`@Type(comptime info: std.builtin.Type) type`

参数的具体类型可以参考 [此处](https://ziglang.org/documentation/master/std/#std.builtin.Type)。

以下示例为我们构建一个新的结构体：

<<<@/code/release/reflection.zig#Type

::: info 🅿️ 提示

除了常见的类型外，还有以下特殊类型：

- 关于枚举，还存在一个 `EnumLiteral` 类型，可以称之为枚举字面量，详细说明见 [枚举](../basic/advanced_type/enum.md#enumliteral)。

:::

::: warning

需要注意的是，当前 zig 并不支持构建的类型包含声明（declaration），即定义的变量（常量）或方法，具体原因见此 [issue](https://github.com/ziglang/zig/issues/6709)！

不得不说，不支持声明极大地降低了 zig 编译期的特性。

:::
