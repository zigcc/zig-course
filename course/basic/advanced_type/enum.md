---
outline: deep
---

# 枚举

> 举常常用来列出一个有限集合的任何成员，或者对某一种特定对象的计数。

枚举是一种相对简单，但用处颇多的类型。

## 声明枚举

我们可以通过使用 `enum` 关键字来很轻松地声明并使用枚举：

```zig
const Type = enum {
    ok,
    not_ok,
};

const c = Type.ok;
```

同时，zig 还允许我们访问并操作枚举的标记值：

```zig
// 指定枚举的标记类型
// 现在我们可以在 u2 和 Value 这个枚举类型之中任意切换了
const Value = enum(u2) {
    zero,
    one,
    two,
};
```

在此基础上，我们还可以覆盖枚举的标记值：

```zig
const Value2 = enum(u32) {
    hundred = 100,
    thousand = 1000,
    million = 1000000,
};

// 覆盖部分值
const Value3 = enum(u4) {
    a,
    b = 8,
    c,
    d = 4,
    e,
};
```

::: info 🅿️ 提示

枚举类型支持使用 `if` 和 `switch` 进行匹配，具体见对应章节。

:::

## 枚举方法

没错，枚举也可以拥有方法，实际上枚举仅仅是一种命名空间（你可以看作是一类 struct ）。

```zig
const Suit = enum {
    clubs,
    spades,
    diamonds,
    hearts,

    pub fn isClubs(self: Suit) bool {
        return self == Suit.clubs;
    }
};
```

## 枚举大小

要注意的是，枚举的大小是会经过 zig 编译器进行严格的计算，如以上的枚举类型 `Type` ，它大小等效于 `u1`。

以下示例中，我们使用了内建函数 `@typeInfo` 和 `@tagName` 来获取枚举的大小和对应的 tag name：

```zig
const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

const Small = enum {
    one,
    two,
    three,
    four,
};

pub fn main() !void {
    try expect(@typeInfo(Small).Enum.tag_type == u2);
    try expect(@typeInfo(Small).Enum.fields.len == 4);
    try expect(mem.eql(u8, @typeInfo(Small).Enum.fields[1].name, "two"));
    try expect(mem.eql(u8, @tagName(Small.three), "three"));
}

```

## 枚举推断

枚举也支持让 zig 编译器自动进行推断，即在已经知道枚举的类型情况下仅使用字段来指定枚举的值：

```zig
const Color = enum {
    auto,
    off,
    on,
};

pub fn main() !void {
    const color1: Color = .auto; // 此处枚举进行了自动推断
    const color2 = Color.auto;
    _ = (color1 == color2); // 这里比较的结果是 true
}
```

## 非详尽枚举

zig 允许我们不列出所有的枚举值，未列出枚举值可以使用 `_` 代替，但需明确指出枚举大小并且不能已经将整个大小空间消耗干净。

:::info 🅿️ 提示

`@enumFromInt` 允许我们通过一个整数来反推一个枚举，但需要注意需要注意不要超出枚举的大小空间，这会牵扯到 `@intCast` 到枚举大小等价整数类型的安全语义。

:::

```zig
const Number = enum(u8) {
    one,
    two,
    three,
    _,
};

const number = Number.one;
const result = switch (number) {
    .one => true,
    .two,
    .three => false,
    _ => false,
};
// result 是 true

const is_one = switch (number) {
    .one => true,
    else => false,
};
// is_one 也是true
```

## `EnumLiteral`

::: info 🅿️ 提示

此部分内容并非是初学者需要掌握的内容，它涉及到 zig 本身的类型系统和 [编译期反射](../../more/reflection#构建新的类型)，可以暂且跳过！

:::

zig 还包含另外一个特殊的类型 `EnumLiteral`，它是 [`std.builtin.Type`](https://ziglang.org/documentation/master/std/#A;std:builtin.Type) 的一部分。

可以将它称之为“枚举字面量”，它是一个与 `enum` 完全不同的类型，可以查看 zig 类型系统对 `enum` 的 [定义](https://ziglang.org/documentation/master/std/#A;std:builtin.Type.Enum)，并不包含 `EnumLiteral`！

它的具体使用如下：

```zig
// 使用内建函数 @Type 构造出一个 EnumLiteral 类型
// 这是目前官方文档中的使用方案
const EnumLiteral: type = @Type(.EnumLiteral);

// 定义一个常量 enum_literal，它的类型为 EnumLiteral，并赋值为 “.kkk”
const enum_literal: EnumLiteral = .kkk;

// 使用内建函数 @tagName 获取 enum_literal 的 tag name，并进行打印
std.debug.print("enum_literal is {s}", .{@tagName(enum_literal)});
```

注意：此类型常用于作为函数参数！

## extern

注意，我们不在这里使用 `extern` 关键字。

默认情况下，zig 不保证枚举和 C ABI 兼容，但是我们可以通过指定标记类型来达到这一效果：

```zig
const Foo = enum(c_int) { a, b, c };
```
