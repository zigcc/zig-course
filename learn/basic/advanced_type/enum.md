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

## 标记类型

要注意的是，枚举的标记类型是会经过 zig 编译器进行严格的计算，如以上的枚举类型 `Type` ，它标记类型只会是 `u1`。

以下示例中，我们使用了内置函数 `@typeInfo` 和 `@tagName` 来获取枚举的标记类型和对应的 name：

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

枚举也支持让 zig 编译器自动进行推断：

```zig
const Color = enum {
    auto,
    off,
    on,
};

pub fn main() !void {
    const color1: Color = .auto;
    _ = color1;
}
```

## 非详尽枚举

zig 允许我们不列出所有的枚举值，未列出枚举值可以使用 `_` 代替，但需明确指出枚举标记类型并且不能已经将标记消耗干净。

:::info 🅿️ 提示

关于使用`@enumFromInt` 时，需要注意不要超出范围

:::

```zig
const Number = enum(u8) {
    one,
    two,
    three,
    _,
};
```

## extern

注意，我们不在这里使用 `extern` 关键字。

默认情况下，zig 不保证枚举和 C ABI 兼容，但是我们可以通过指定序列类型来达到这一效果：

```zig
const Foo = enum(c_int) { a, b, c };
```
