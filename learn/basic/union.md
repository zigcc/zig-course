---
outline: deep
---

# 联合类型

联合类型(union)，它实际上用户定义的一种特殊的类型，划分出一块内存空间用来存储多种类型，但同一时间只能存储一个类型。

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

:::info

需要注意的是，zig 不保证普通联合类型在内存中的表现形式！如果有需要，可以使用 `extern union` 或者 `packed union` 来保证它遵守 c 的规则。

:::

## 枚举标记

联合类型可以在定义时使用枚举进行标记，类似[标记枚举](advanced_type/enum#标记类型)。你可以通过 `@as` 函数将联合类型作为生命的枚举来使用。

示例

:::code-group

```zig [default]
const ComplexTypeTag = enum {
    ok,
    not_ok,
};

const ComplexType = union(ComplexTypeTag) {
    ok: u8,
    not_ok: void,
};
```

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
}
```

:::

## `extern union`

`extern union` 保证内存布局与目标 C ABI 兼容。

具体可以见 [`extern struct`](advanced_type/struct.md#extern)。

## `packed union`

`packed union` 保证内存布局和声明顺序相同并且尽量紧凑，具体见 [`extern struct`](advanced_type/struct.md#packed)。