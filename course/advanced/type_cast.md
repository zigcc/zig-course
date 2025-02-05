---
outline: deep
---

# 类型转换

> 在计算机科学，特别是在程序设计语言中，类型转换（英语：type conversion）指将数据从一种类型转换到另一种类型的过程。

zig 提供了三种类型转换，第一种是已知完全安全且不存在歧义的普通类型转换，第二种是用于避免出现错误的显式强制类型转换，第三种是对等类型解析（**Peer Type Resolution**）。

## 普通类型转换

出现时机：当需要一种类型时却提供了另一种类型，如果此时这种转换是安全，且不存在歧义，则会由 zig 自动完成。

仅当完全明确如何从一种类型转换为另一种类型并且保证转换安全时才允许自动转换，但有一个例外，那就是 zig 的 [C 指针](https://ziglang.org/documentation/master/#C-Pointers)。

大致的规则如下：

### 限制更严格

例如非 `const` -> `const`，增加 `volatile` 限制，大的内存对齐转为小的内存对齐，错误集合转为超集（子集转为超集），指针转为可选指针，这些转换实际上在运行时没有任何操作，因为值没有任何变化。

### 整数与浮点数拓宽

整数可以转换为可以表示旧类型全部值的整数类型，这句话看起来可能有点绕，就像 `u8` 转为 `u16` 没有任何问题，因为 `u16` 肯定可以容纳 `u8`，而 `u8` 转为 `i16` 也没有问题，因为 `i16` 同样也容纳 `u8`。

浮点数同理，可以转换为可以表示旧类型全部值的浮点类型。

<<<@/code/release/type-cast.zig#widen

### 立即数整数和浮点数出现歧义

这往往是由于编译器推断类型出现歧义导致的，例如：

```zig
test "implicit cast to comptime_int" {
    const f: f32 = 54.0 / 5;
    _ = f;
}
```

它会报告如下的错误：

```shell
$ zig test test_ambiguous_coercion.zig
docgen_tmp/test_ambiguous_coercion.zig:3:25: error: ambiguous coercion of division operands 'comptime_float' and 'comptime_int'; non-zero remainder '4'
```

此处歧义为两种情况：

1. 参照 `5` 的类型，将 `54.0` 转换为 `comptime_int` 就是 `54`，再相除，得到结果再转换为 `f32`，最终 `f` 为 `10`。

2. 参照 `54.0` 的类型，将 `5` 转换为 `comptime_float` 就是 `5.0`，再相除，得到结果再转换为 `f32`，最终 `f` 为 `10.8`。

### 切片、数组、指针

1. 指向常量数组的指针，可以分配给元素为常量的切片，这在处理字符串时很有用。

<<<@/code/release/type-cast.zig#pointer_arr_slice_1

2. 允许直接将数组的指针赋值给切片 (会被自动转换)，这会使切片长度直接等于数组。

<<<@/code/release/type-cast.zig#pointer_arr_slice_2

3. 数组指针赋值给多项指针（自动转换）。

<<<@/code/release/type-cast.zig#pointer_arr_slice_3

4. 单项指针可以赋值给长度只有 1 的数组指针

<<<@/code/release/type-cast.zig#pointer_arr_slice_4

### 可选类型

可选类型的载荷（**payload**），包括 `null`，允许自动转换为可选类型。

<<<@/code/release/type-cast.zig#optional_payload

### 错误联合类型

错误联合类型的载荷（**payload**），包括错误集，允许自动转换为错误联合类型。

<<<@/code/release/type-cast.zig#error_union

### 编译期数字

编译期已知的数字，如果另外一个类型可以表示它，那么会自动进行转换。

<<<@/code/release/type-cast.zig#comptime_integer

### 联合类型和枚举

标记联合类型可以自动转换为对应的枚举，并且在编译期可以确定联合类型的某一个字段仅有一个可能值（该值为枚举的一个值）时，对应的枚举值可以直接自动转换为标记联合类型（这里包括 void 类型，因为它也是唯一值）：

<<<@/code/release/type-cast.zig#tag_union_enum

### undefined

undefined 是一个神奇的值，它可以赋值给所有类型，代表这个值尚未初始化。

### 元组和数组

当元组中的所有值均为同一个类型时，我们可以直接将它转化为数组（自动转换）：

<<<@/code/release/type-cast.zig#tuple_arr

## 显式强制转换

显式强制转换是通过内建函数完成的，有些转换是安全的，有些是执行语言级断言，有些转换在运行时无操作。

- [`@bitCast`](https://ziglang.org/documentation/master/#bitCast) 更改类型但保持位不变
- [`@alignCast`](https://ziglang.org/documentation/master/#alignCast) 显式强制转换对齐
- [`@enumFromInt`](https://ziglang.org/documentation/master/#enumFromInt) 根据整数值获取对应的枚举值
- [`@errCast`](https://ziglang.org/documentation/master/#errorCast) 显式强制转换为错误的子集
- [`@floatCast`](https://ziglang.org/documentation/master/#floatCast) 将大浮点数转为小浮点数
- [`@floatFromInt`](https://ziglang.org/documentation/master/#floatFromInt) 将整数显式强制转换为浮点数
- [`@intCast`](https://ziglang.org/documentation/master/#intCast) 在不同的整数类型中显式强制转换
- [`@intFromBool`](https://ziglang.org/documentation/master/#intFromBool) 将 `true` 转换为 `1`，`false` 转换为 `0`
- [`@intFromEnum`](https://ziglang.org/documentation/master/#intFromEnum) 根据整数值获取对应的联合标记或者枚举值
- [`@intFromError`](https://ziglang.org/documentation/master/#intFromError) 获取对应错误的整数值
- [`@intFromFloat`](https://ziglang.org/documentation/master/#intFromFloat) 获取浮点数的整数部分
- [`@intFromPtr`](https://ziglang.org/documentation/master/#intFromPtr) 获取指针指向的地址（整数 `usize`），这在嵌入式开发和内核开发时很常用
- [`@ptrFromInt`](https://ziglang.org/documentation/master/#ptrFromInt) 根据整数 `usize` 来获取对应的指针，这在嵌入式开发和内核开发时很常用
- [`@ptrCast`](https://ziglang.org/documentation/master/#ptrCast) 不同的指针类型之间进行显式强制转换
- [`@truncate`](https://ziglang.org/documentation/master/#truncate) 不同类型的整数间，截断位

## 对等类型转换

对等类型转换（**Peer Type Resolution**），这个词汇仅仅在 zig 的文档中出现过，它看起来与前面提到的普通类型解析很像，根据 zig 的[开发手册](https://ziglang.org/documentation/master/)所述，它发生在以下情况：

- `switch` 的表达式
- `if` 的表达式
- `while` 的表达式
- `for` 的表达式
- 块中的多个 `break` 语句
- 一些二元操作符

对等类型转换发生时，会尽量转换为所有对等类型可以转换成的类型，以下是一些示例：

对等类型转换处理整数转换：

<<<@/code/release/type-cast.zig#peer_resolution_1

对等类型转换处理不同大小的数组到切片：

<<<@/code/release/type-cast.zig#peer_resolution_2

对等类型转换处理数组到常量切片：

<<<@/code/release/type-cast.zig#peer_resolution_3

对等类型转换处理 `?T` 到 `T`：

<<<@/code/release/type-cast.zig#peer_resolution_4

对等类型转换处理 `*[0]u8` 到 `[]const u8`：

> `*[0]u8` 是长度为 0 的数组的指针

<<<@/code/release/type-cast.zig#peer_resolution_5

对等类型转换处理 `*[0]u8` 和 `[]const u8` 到 `anyerror![]u8`：

<<<@/code/release/type-cast.zig#peer_resolution_6

对等类型转换处理 `*const T` 到 `?*T`：

<<<@/code/release/type-cast.zig#peer_resolution_7
