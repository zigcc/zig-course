---
outline: deep
---

# 类型转换

> 在计算机科学，特别是在程序设计语言中，类型转换（英语：type conversion）指将数据从一种类型转换到另一种类型的过程。

zig 提供了三种类型转换，第一种是已知完全安全且不存在歧义的普通类型转换，第二种是用于避免出现错误的显式强制类型转换，第三种是对等类型解析（**Peer Type Resolution**）。

## 普通类型转换

**普通类型转换**的出现时机：当需要一种类型时却提供了另一种类型，如果此时这种转换是安全，且不存在歧义，则会由 zig 自动完成。

仅当完全明确如何从一种类型转换为另一种类型并且保证转换安全时才允许自动转换，但有一个例外，那就是 zig 的 [C指针](https://ziglang.org/documentation/master/#C-Pointers)。

大致的规则如下：

### 限制更严格

例如非 `const` -> `const`，增加 `volatile` 限制，大的内存对齐转为小的内存对齐，错误集合转为超集（子集转为超集），指针转为可选指针，这些转换实际上在运行时没有任何操作，因为值没有任何变化。

### 整数与浮点数拓宽

整数可以转换为可以表示旧类型全部值的整数类型，这句话看起来可能有点绕，就像 `u8` 转为 `u16` 没有任何问题，因为 `u16` 肯定可以容纳 `u8`，而 `u8` 转为 `i16` 也没有问题，因为 `i16` 同样也容纳 `u8`。

浮点数同理，可以转换为可以表示旧类型全部值的浮点类型。

```zig
const a: u8 = 250;
const b: u16 = a;
const c: u32 = b;
const d: u64 = c;
const e: u64 = d;
const f: u128 = e;
// f 和 a 是相等的

const g: u8 = 250;
const h: i16 = h;
// g 和 h 相等

const i: f16 = 12.34;
const j: f32 = i;
const k: f64 = j;
const l: f128 = k;
// i 和 l 相等
```

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
    const f: f32 = 54.0 / 5;
```

此处歧义为两种情况：

1. 参照 `5` 的类型，将 `54.0` 转换为 `comptime_int` 就是 `54`，再相除，得到结果再转换为 `f32`，最终 `f` 为 `10`。

2. 参照 `54.0` 的类型，将 `5` 转换为 `comptime_float` 就是 `5.0`， 再相除，得到结果再转换为 `f32`，最终 `f` 为 `10.8`。

### 切片、数组、指针

1. 指向常量数组的指针，可以分配给元素为常量的切片，这在处理字符串时很有用。

```zig
const x1: []const u8 = "hello";
const x2: []const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
// x1 和 x2 相等

const y1: anyerror![]const u8 = "hello";
const y2: anyerror![]const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
// 是错误联合类型时，也有效

const z1: ?[]const u8 = "hello";
const z2: ?[]const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
// 可选类型也有效果

const a1: anyerror!?[]const u8 = "hello";
const a2: anyerror!?[]const u8 = &[5]u8{ 'h', 'e', 'l', 'l', 111 };
// 错误联合可选类型也有效
```

2. 允许直接将数组的指针赋值给切片(会被自动转换)，这会使切片长度直接等于数组。

```zig
var buf: [5]u8 = "hello".*;
const x: []u8 = &buf;

const buf2 = [2]f32{ 1.2, 3.4 };
const x2: []const f32 = &buf2;
```

3. 数组指针赋值给多项指针（自动转换）。

```zig
var buf: [5]u8 = "hello".*;
const x: [*]u8 = &buf;

var buf2: [5]u8 = "hello".*;
const x2: ?[*]u8 = &buf2;
// 可选类型也有效

var buf3: [5]u8 = "hello".*;
const x3: anyerror![*]u8 = &buf3;
// 联合错误类型也有效

var buf4: [5]u8 = "hello".*;
const x4: anyerror!?[*]u8 = &buf4;
// 联合错误可选类型也有效
```

4. 单项指针可以赋值给长度只有 1 的数组指针

```zig
var x: i32 = 1234;
const y: *[1]i32 = &x;
const z: [*]i32 = y;
// 先转为长度为 1 的数组指针，再转换为多项指针。
// 如果 x 直接赋值给 z，则编译器会报错
```

### 可选类型

可选类型的载荷（**payload**），包括 `null`，允许自动转换为可选类型。

```zig
const y: ?i32 = null;
const y1: anyerror!?i32 = null;
// 错误联合可选类型也可以
```

### 错误联合类型

错误联合类型的载荷（**payload**），包括错误集，允许自动转换为错误联合类型。

```zig
const y: anyerror!i32 = error.Failure;
```

### 编译期数字

编译期已知的数字，如果另外一个类型可以表示它，那么会自动进行转换。

```zig
const x: u64 = 255;
const y: u8 = x;
// 自动转换到 u8
```

### 联合类型和枚举

标记联合类型可以自动转换为对应的枚举，并且在编译期可以确定联合类型的某一个字段仅有一个可能值（该值为枚举的一个值）时，对应的枚举值可以直接自动转换为标记联合类型（这里包括 void 类型，因为它也是唯一值）：

```zig
const std = @import("std");
const expect = std.testing.expect;

const E = enum {
    one,
    two,
    three,
};

const U = union(E) {
    one: i32,
    two: f32,
    three,
};

const U2 = union(enum) {
    a: void,
    b: f32,

    fn tag(self: U2) usize {
        switch (self) {
            .a => return 1,
            .b => return 2,
        }
    }
};

pub fn main() !void {
    const u = U{ .two = 12.34 };
    const e: E = u; // 将联合类型转换为枚举
    try expect(e == E.two);

    const three = E.three;
    const u_2: U = three; // 将枚举转换为联合类型，注意这里 three 并没有对应的类型，故可以直接转换
    try expect(u_2 == E.three);

    const u_3: U = .three; // 字面量供 zig 编译器来自动推导
    try expect(u_3 == E.three);

    const u_4: U2 = .a; // 字面量供 zig 编译器来推导，a 也是没有对应的类型（void）
    try expect(u_4.tag() == 1);

    // 下面的 b 字面量推导是错误的，因为它有对应的类型 f32
    //var u_5: U2 = .b;
    //try expect(u_5.tag() == 2);
}
```

### undefined

undefined 是一个神奇的值，它可以赋值给所有类型，代表这个值尚未初始化。

### 元组和数组

当元组中的所有值均为同一个类型时，我们可以直接将它转化为数组（自动转换）：

```zig
const Tuple = struct{ u8, u8 };

const tuple: Tuple = .{5, 6};
// 一切都是自动完成的
const array: [2]u8 = tuple;
```

## 显式强制转换

显式强制转换是通过内置函数完成的，有些转换是安全的，有些是执行语言级断言，有些转换在运行时无操作。

- [`@bitCast`](https://ziglang.org/documentation/0.11.0/#bitCast) 更改类型但保持位不变
- [`@alignCast`](https://ziglang.org/documentation/0.11.0/#alignCast) 显式强制转换对齐
- [`@enumFromInt`](https://ziglang.org/documentation/0.11.0/#enumFromInt) 根据整数值获取对应的枚举值
- [`@errSetCast`](https://ziglang.org/documentation/0.11.0/#errSetCast) 显式强制转换为错误的子集
- [`@floatCast`](https://ziglang.org/documentation/0.11.0/#floatCast) 将大浮点数转为小浮点数
- [`@floatFromInt`](https://ziglang.org/documentation/0.11.0/#floatFromInt) 将整数显式强制转换为浮点数
- [`@intCast`](https://ziglang.org/documentation/0.11.0/#intCast) 在不同的整数类型中显式强制转换
- [`@intFromBool`](https://ziglang.org/documentation/0.11.0/#intFromBool) 将 `true` 转换为 `1`，`false` 转换为 `0`
- [`@intFromEnum`](https://ziglang.org/documentation/0.11.0/#intFromEnum) 根据整数值获取对应的联合标记或者枚举值
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

```zig
const a: i8 = 12;
const b: i16 = 34;
const c = a + b;
// c 的类型是 u16
```

对等类型转换处理不同大小的数组到切片：

```zig
const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

pub fn main() !void {
    // mem.eql 执行检查内存是否相等
    try expect(mem.eql(u8, boolToStr(true), "true"));
    try expect(mem.eql(u8, boolToStr(false), "false"));
    try comptime expect(mem.eql(u8, boolToStr(true), "true"));
    try comptime expect(mem.eql(u8, boolToStr(false), "false"));
}

fn boolToStr(b: bool) []const u8 {
    return if (b) "true" else "false";
}
```


对等类型转换处理数组到常量切片：

```zig
fn testPeerResolveArrayConstSlice(b: bool) !void {
    const value1 = if (b) "aoeu" else @as([]const u8, "zz");
    const value2 = if (b) @as([]const u8, "zz") else "aoeu";
    try expect(mem.eql(u8, value1, "aoeu"));
    try expect(mem.eql(u8, value2, "zz"));
}

testPeerResolveArrayConstSlice(true);
// 上面这个语句执行会成功
```

对等类型转换处理 `?T` 到 `T`：

```zig
fn peerTypeTAndOptionalT(c: bool, b: bool) ?usize {
    if (c) {
        return if (b) null else @as(usize, 0);
    }

    return @as(usize, 3);
}

// 下面语句执行为 true
peerTypeTAndOptionalT(true, false).? == 0
```

对等类型转换处理 `*[0]u8` 到 `[]const u8`：

> `*[0]u8` 是长度为 0 的数组的指针

```zig
fn peerTypeEmptyArrayAndSlice(a: bool, slice: []const u8) []const u8 {
    if (a) {
        return &[_]u8{};
    }

    return slice[0..1];
}

// 以下两句均为true
peerTypeEmptyArrayAndSlice(true, "hi").len == 0
peerTypeEmptyArrayAndSlice(false, "hi").len == 1
```

对等类型转换处理 `*[0]u8` 和 `[]const u8` 到 `anyerror![]u8`：

```zig
fn peerTypeEmptyArrayAndSliceAndError(a: bool, slice: []u8) anyerror![]u8 {
    if (a) {
        return &[_]u8{};
    }

    return slice[0..1];
}
```

对等类型转换处理 `*const T` 到 `?*T`：

```zig
const a: *const usize = @ptrFromInt(0x123456780);
const b: ?*usize = @ptrFromInt(0x123456780);

a == b 这个表达式的值为 true
```