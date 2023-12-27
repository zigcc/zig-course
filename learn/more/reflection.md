---
outline: deep
---

# 反射

> 在计算机学中，反射（**reflection**），是指计算机程序在运行时（**runtime**）可以访问、检测和修改它本身状态或行为的一种能力。用比喻来说，反射就是程序在运行的时候能够“观察”并且修改自己的行为。

事实上，由于 zig 是一门强类型的静态语言，因此它的反射是在编译期实现的，允许我们观察已有的类型，并根据已有类型的信息来创造新的类型！

## 观察已有类型

zig 提供了不少函数来获取已有类型的信息,如：`@TypeOf`、`@typeName`、`@typeInfo`、`@hasDecl`、`@hasField`、`@field`、`@fieldParentPtr`、`@call`。

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

```zig
const std = @import("std");
const expect = std.testing.expect;

test "no runtime side effects" {
    var data: i32 = 0;
    const T = @TypeOf(foo(i32, &data));
    try comptime expect(T == i32);
    try expect(data == 0);
}

fn foo(comptime T: type, ptr: *T) T {
    ptr.* += 1;
    return ptr.*;
}
```

以上这段测试完全可以运行通过，原因在于，`@TypeOf` 仅仅执行了类型计算，并没有真正地执行函数体的内容，故函数 `foo` 的效果并不会真正生效！

### `@typeName`

[`@typeName`](https://ziglang.org/documentation/master/#typeName)，该内建函数用于获取类型的名字。

该函数返回的类型名字完全是一个字符串字面量，并且包含其父容器的名字（通过 `.` 分隔）：

```zig
const std = @import("std");

const T = struct {
    const Y = struct {};
};

pub fn main() !void {
    std.debug.print("{s}\n", .{@typeName(T)});
    std.debug.print("{s}\n", .{@typeName(T.Y)});
}
```

```sh
$ zig build run
main.T
main.T.Y
```

### `@typeInfo`

[`@typeInfo`](https://ziglang.org/documentation/master/#typeInfo)，该内建函数用于获取类型的信息。

提供类型反射的具体功能，结构体、联合类型、枚举和错误集的类型信息具有保证与源文件中出现的顺序相同的字段，结构、联合、枚举和不透明的类型信息都有声明，也保证与源文件中出现的顺序相同。

实际上，该函数的效果是返回一个 [`std.builtin.Type`](https://ziglang.org/documentation/master/std/#A;std:builtin.Type)，该类型包含了所有 zig 当前可用的类型信息，并允许我们通过该类型观察并获取指定类型的具体信息。

以下是一个简单的示例：

```zig
const std = @import("std");

const T = struct {
    a: u8,
    b: u8,
};

pub fn main() !void {
    // 通过 @typeInfo 获取类型信息
    const type_info = @typeInfo(T);
    // 断言它为 struct
    const struct_info = type_info.Struct;

    // inline for 打印该结构体内部字段的信息
    inline for (struct_info.fields) |field| {
        std.debug.print("field name is {s}, field type is {}\n", .{
            field.name,
            field.type,
        });
    }
}
```

以上的示例中，我们使用了`@typeInfo` 来获取类型 `T` 的信息，随后将其断言为一个 `Struct` 类型，然后再通过 `inline for` 打印输出其字段值。

需要注意的是，我们在此处打印必须要要使用 `inline for`，否则将会编译无法通过，这是因为 结构体的 **“字段类型”** [`std.builtin.Type.StructField`](https://ziglang.org/documentation/master/std/#A;std:builtin.Type.StructField)，其中有一个字段是 `comptime_int`，使得无法在运行时计算索引来便利，只能通过 `inline for` 将其转换为编译期计算。

::: warning

值得注意的是，我们观察并获得的类型信息是 **只读的**，无法以此来修改已有类型，这是由于 zig 是一门静态语言并不具有过多的运行时功能！

但我们可以以此为基础在编译期构建新的类型！

:::

TODO：增加新的示例，仅仅一个示例不足以说明 `@typeInfo` 的使用！

### `@hasDecl`

### `@hasField`

### `@field`

### `@fieldParentPtr`

### `@call`

## 构建新的类型

zig 除了获取类型信息外，还提供了在编译期构建全新类型的能力，允许我们通过非常规的方式来声明一个类型。

构建新类型的能力主要依赖于 `@Type`。

### `@Type`

该函数实际上就是 `@typeInfo` 的反函数，它将类型信息具体化为一个类型。

TODO