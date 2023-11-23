---
outline: deep
---

# defer

`defer` 将在当前作用域末尾执行表达式。

如果存在多个 `defer`，它们将会按照出栈方式执行。

```zig
const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    defer print("exec third", .{});

    if (false) {
        defer print("will not exec", .{});
    }

    defer {
        print("exec second", .{});
    }
    defer {
        print("exec first", .{});
    }
}
```

`defer` 分别可以执行单个语句和一个块，并且如果控制流不经过 `defer`，则不会执行。

对应 `defer` 的还有 `errdefer`，具体见这里 [`errdefer`](/basic/error_handle#errdefer)。
