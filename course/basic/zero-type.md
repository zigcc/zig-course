---
outline: deep
---

# 零大小类型

在 Zig 中，有一些特殊的类型被称为**零大小类型**（Zero-Sized Types），它们在内存中不占用任何空间（0 bit）。

这些类型的特点是，它们的值不会出现在最终的构建结果中，因为它们不占用任何内存空间。

## `void`

`void` 是一个典型的**零大小类型**，常用于表示函数没有返回值。

除了作为函数返回值，`void` 还可以用于初始化泛型实例，例如 `std.AutoHashMap`：

```zig
var map = std.AutoHashMap(i32, void).init(std.testing.allocator);
```

这样可以得到一个 `i32` 类型的集合（set）。尽管可以使用其他方式实现集合功能，但这种方法可以显著减少内存占用，因为它不需要存储实际的值。

## 整数

[整数](../basic/basic_type/number.md) 声明可以使用 `u0` 和 `i0` 来声明**零大小整数类型**，它们的大小也是 0 bit。

## 数组和切片

[数组](../basic/advanced_type/array.md) 和 [切片](../basic/advanced_type/slice.md) 当其长度为 0 时，被视为**零大小类型**。

此外，如果数组或切片的元素类型本身就是零大小类型，那么无论其长度如何，该数组或切片都将是**零大小类型**。

## 枚举

只有一个成员的 [枚举](../basic/advanced_type/enum.md) 也是**零大小类型**。

## 结构体

[结构体](../basic/advanced_type/struct.md) 当其为空，或者所有字段都是零大小类型时，该结构体也是**零大小类型**。

例如，`const zero = struct {};` 就是一个零大小类型，其大小为 0。

## 联合类型

## 联合类型

仅包含一种可能类型（且该类型是零大小类型）的 [联合类型](../basic/union.md) 也是零大小类型。
