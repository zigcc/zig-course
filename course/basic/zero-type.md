---
outline: deep
---

# 零位类型

在 zig 中，有一些类型是特殊的零位类型（**Zero Type**），它们的大小是 0 bit。

它们的特点是，涉及到它们的值不会出现在构建结果中（0 bit 不占任何空间）。

## `void`

`void` 是很明显的**零位类型**，常用于函数无返回值。

但它不止这一种用法，还可以用来初始化泛型实例，例如 `std.AutoHashMap`：

```zig
var map = std.AutoHashMap(i32, void).init(std.testing.allocator);
```

这样就会获得一个 `i32` 的 set，尽管可以使用其他方式来实现集合功能，但这样子实现效果内存占用会更少（因为相当于不存在 value）。

## 整数

[整数](../basic/basic_type/number.md) 声明可以使用 `u0` 和 `i0` 来声明**零位整数类型**，它们的大小也是 0 bit。

## 数组和切片

[数组](../basic/advanced_type/array.md) 和 [切片](../basic/advanced_type/slice.md) 的长度为 0 时，就是**零位类型**。

另外，如果它们的元素类型是零位类型，则它们必定是**零位类型**，此时与数组（切片）长度无关。

## 枚举

只有一个值的 [枚举](../basic/advanced_type/enum.md)，也是**零位类型**。

## 结构体

[结构体](../basic/advanced_type/struct.md) 为空或者字段均为零位类型时，此时结构体也是**零位类型**。

例如，`const zero = struct {};` 就是一个零位类型，它的大小为 0。

## 联合类型

仅具有一种可能类型（且该类型是零位类型）的 [联合类型](../basic/union.md) 也是零位类型。
