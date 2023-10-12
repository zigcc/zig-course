---
outline: deep
---

# 循环

<!-- 讲解标签 blocks break -->

在 zig 中，循环分为两种，一种是 `while`，一种是 `for`。

## `while`

while 循环用于重复执行表达式，直到某些条件不再成立.

基本使用：

:::code-group

```zig [default]
var i: usize = 0;
while (i < 10) {
    if (i == 5) {
        continue;
    }
    std.debug.print("i is {}\n", .{i});
    i += 1;
}
```

```zig [more]
const std = @import("std");

pub fn main() !void {
    var i: usize = 0;
    while (i < 10) {
        if (i == 5) {
            continue;
        }
        std.debug.print("i is {}\n", .{i});
        i += 1;
    }
}
```

:::


## `for`