---
outline: deep
---

# 联合类型

联合类型(union)，它实际上用户定义的一种特殊的类型，划分出一块内存空间用来存储多种类型，但同一时间只能存储一个类型。

## 基本使用

联合类型的基本使用：

::: code-group

```zig [default]
const Payload = union {
    int: i64,
    float: f64,
    boolean: bool,
};

var payload = Payload{ .int = 1234 };

// 或者是让 zig 编译期进行推倒
var payload_1: Payload = .{ .int = 1234 };

print("{}\n",.{payload.int});
```

```zig [more]
const print = @import("std").debug.print;

const Payload = union {
    int: i64,
    float: f64,
    boolean: bool,
};

pub fn main() !void {
    var payload = Payload{ .int = 1234 };
    var payload_1: Payload = .{ .int = 1234 };

    print("{}\n", .{payload.int});
}
```

:::

:::info 🅿️ 提示

需要注意的是，zig 不保证普通联合类型在内存中的表现形式！如果有需要，可以使用 `extern union` 或者 `packed union` 来保证它遵守 c 的规则。

:::

如果要初始化一个在编译期已知的字段名的联合类型，可以使用 [`@unionInit`](https://ziglang.org/documentation/master/#unionInit)：

```zig
@unionInit(comptime Union: type, comptime active_field_name: []const u8, init_expr) Union
```

```zig
const Payload = union {
    int: i64,
    float: f64,
    boolean: bool,
};
// 通过 @unionInit 初始化一个联合类型
const payload = @unionInit(Payload, "int", 666);
```

## 标记联合

联合类型可以在定义时使用枚举进行标记，通过 `@as` 函数将联合类型作为声明的枚举来使用。

示例



```zig [more]
const std = @import("std");
const expect = std.testing.expect;

const ComplexTypeTag = enum {
    ok,
    not_ok,
};
const ComplexType = union(ComplexTypeTag) {
    ok: u8,
    not_ok: void,
};

pub fn main() !void {
    const c = ComplexType{ .ok = 42 };
    try expect(@as(ComplexTypeTag, c) == ComplexTypeTag.ok);

    switch (c) {
        ComplexTypeTag.ok => |value| try expect(value == 42),
        ComplexTypeTag.not_ok => unreachable,
    }

    // 使用 zig 的 meta 库获取对应的 tag
    try expect(std.meta.Tag(ComplexType) == ComplexTypeTag);
}
```

如果要修改实际的载荷，你可以使用 `*` 语法捕获指针类型：

```zig
const std = @import("std");
const expect = std.testing.expect;

const ComplexTypeTag = enum {
    ok,
    not_ok,
};
const ComplexType = union(ComplexTypeTag) {
    ok: u8,
    not_ok: void,
};

pub fn main() !void {
    var c = ComplexType{ .ok = 42 };

    switch (c) {
        ComplexTypeTag.ok => |*value| value.* += 1,
        ComplexTypeTag.not_ok => unreachable,
    }

    try expect(c.ok == 43);
}
```

还支持使用 [`@tagName`]() 来获取到对应的 name（返回的是一个 comptime 的 `[:0]const u8`，也就是字符串）：

```zig
const Small2 = union(enum) {
    a: i32,
    b: bool,
    c: u8,
};

@tagName(Small2.a);
// 这个返回值将会是 a
```


## 自动推断

zig 也支持自动推断联合类型：

```zig
const Number = union {
    int: i32,
    float: f64,
};

// 自动推断
const i: Number = .{ .int = 42 };
```
## `extern union`

`extern union` 保证内存布局与目标 C ABI 兼容。

具体可以见 [`extern struct`](advanced_type/struct.md#extern)。

## `packed union`

`packed union` 保证内存布局和声明顺序相同并且尽量紧凑，具体见 [`extern struct`](advanced_type/struct.md#packed)。
