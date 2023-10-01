---
outline: deep
---

# 条件

> 在 zig 中，`if` 这个语法的作用可就大了！

像基础的 `if`，`if else`，`else if` 我们就不说了，直接看例子：

```zig
const print = @import("std").debug.print;

pub fn main() !void {
    var num: u8 = 1;
    if (num == 1) {
        print("num is 1\n", .{});
    } else if (num == 2) {
        print("num is 2\n", .{});
    } else {
        print("num is other\n", .{});
    }
}
```

## 三元表达式

zig 中的三元表达式是通过 `if else` 来实现的：

::: code-group

```zig [default]
const a: u32 = 5;
const b: u32 = 4;
const result = if (a != b) 47 else 3089;
```

```zig [more]
const print = @import("std").debug.print;

pub fn main() !void {
    const a: u32 = 5;
    const b: u32 = 4;
    const result = if (a != b) 47 else 3089;

    print("result is {}\n", .{result});
}
```

:::

## 高级用法

以下内容涉及到了[联合类型](/basic/union)和[可选类型](/basic/optional_type)，你可以在阅读完这两章节后再回来学习。

### 解构联合类型

### 解构可选类型

### 解构可选联合类型
