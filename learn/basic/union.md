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

    print("{}\n", .{payload.int});
}
```
:::