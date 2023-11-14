---
outline: deep
---

# Switch

switch 语句可以进行匹配，并且switch匹配不能出现遗漏匹配的情况。

## 基本使用

:::code-group

```zig [default]
var num: u8 = 5;
switch (num) {
    5 => {
        print("this is 5\n", .{});
    },
    else => {
        print("this is not 5\n", .{});
    },
}
```

```zig [more]
const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var num: u8 = 5;
    switch (num) {
        5 => {
            print("this is 5\n", .{});
        },
        else => {
            print("this is not 5\n", .{});
        },
    }
}
```

:::

:::info 🅿️ 提示

switch 的匹配必须要要穷尽所有，或者具有 `else` 分支！

:::

## 进阶使用

switch 还支持用 `,` 分割的多匹配、`...` 的范围选择符，类似循环中的 `tag` 语法、编译期表达式，以下是演示：

```zig [default]
const a: u64 = 10;
const zz: u64 = 103;

// 作为表达式使用
const b = switch (a) {
    // 多匹配项
    1, 2, 3 => 0,

    // 范围匹配
    5...100 => 1,

    // tag形式的分配匹配，可以任意复杂
    101 => blk: {
        const c: u64 = 5;
        break :blk c * 2 + 1;
    },

    zz => zz,
    // 支持编译期运算
    blk: {
        const d: u32 = 5;
        const e: u32 = 100;
        break :blk d + e;
    } => 107,

    
    // else 匹配剩余的分支
    else => 9,
};

try expect(b == 1);
```