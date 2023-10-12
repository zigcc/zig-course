---
outline: deep
---

# 循环

<!-- 讲解标签 blocks break -->

在 zig 中，循环分为两种，一种是 `while`，一种是 `for`。

## `for`

for 循环是另一种循环处理方式，主要用于迭代数组和切片。

它支持 `continue` 和 `break`。

迭代数组和切片：

```zig
const items = [_]i32 { 4, 5, 3, 4, 0 };
var sum: i32 = 0;

for (items) |value| {
    if (value == 0) {
        continue;
    }
    sum += value;
}
```

以上代码中的 value，我们称之为对 数组（切片）迭代的值捕获，注意它是只读的。

在迭代时操作数组（切片）：

```zig
var items = [_]i32 { 3, 4, 2 };

for (&items) |*value| {
    value.* += 1;
}
```

以上代码中的value是一个指针，我们称之为对 数组（切片）迭代的指针捕获，注意它也是只读的，不过我们可以通过借引用指针来操作数组（切片）的值。

### 迭代数字

迭代连续的整数很简单，以下是示例：

```zig
for (0..5) |i| {
    // do something
}
```

### 迭代索引

如果你想在迭代数组（切片）时，也可以访问索引，可以这样做：

```zig
const items = [_]i32 { 4, 5, 3, 4, 0 };
for (items, 0..) |value, i| {
    // do something
}
```

以上代码中，其中 value 是值，而 i 是索引。

### 多目标迭代

当然，你也可以同时迭代多个目标（数组或者切片），当然这两个迭代的目标要长度一致防止出现未定义的行为。

```zig
const items = [_]usize{ 1, 2, 3 };
const items2 = [_]usize{ 4, 5, 6 };

for (items, items2) |i, j| {
// do something
}
```

### 作为表达式使用

当然，for 也可以作为表达式来使用，它的行为和 [while](#作为表达式使用) 一模一样。

```zig
var items = [_]?i32 { 3, 4, null, 5 };

const result = for (items) |value| {
    if (value == 5) {
        break value;
    }
} else 0;
```

### 标记

`continue` 的效果类似于 `goto`，并不推荐使用，因为它和 `goto` 一样难以把控，以下示例中，outer 就是标记。

`break` 的效果就是在标记处的 while 执行 break 操作，当然，同样不推荐使用。

它们只会增加你的代码复杂性，非必要不使用！

```zig
var count: usize = 0;
outer: for (1..6) |_| {
    for (1..6) |_| {
        count += 1;
        break :outer;
    }
}


```

```zig
var count: usize = 0;
outer: for (1..9) |_| {
    for (1..6) |_| {
        count += 1;
        continue :outer;
    }
}
```

### 内联 `inline`

`inline` 关键字会将 for 循环展开，这允许代码执行一些一些仅在编译时有效的操作。

需要注意，内联 for 循环要求迭代的值和捕获的值均是编译期已知的。

:::code-group

```zig [default]
pub fn main() !void {
    const nums = [_]i32{2, 4, 6};
    var sum: usize = 0;
    inline for (nums) |i| {
        const T = switch (i) {
            2 => f32,
            4 => i8,
            6 => bool,
            else => unreachable,
        };
        sum += typeNameLength(T);
    }
    try expect(sum == 9);
}

fn typeNameLength(comptime T: type) usize {
    return @typeName(T).len;
}
```

```zig [more]
const std = @import("std");
const expect = std.testing.expect;

pub fn main() !void {
    const nums = [_]i32{2, 4, 6};
    var sum: usize = 0;
    inline for (nums) |i| {
        const T = switch (i) {
            2 => f32,
            4 => i8,
            6 => bool,
            else => unreachable,
        };
        sum += typeNameLength(T);
    }
    try expect(sum == 9);
}

fn typeNameLength(comptime T: type) usize {
    return @typeName(T).len;
}
```

:::

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

### `continue` 表达式

while 还支持一个被称为 continue 表达式的方法来便于我们控制循环，其内部可以是一个语句或者是一个作用域（`{}` 包裹）

:::code-group

```zig [单语句]
var i: usize = 0;
while (i < 10) : (i += 1) {}
```

```zig [多语句]
var i: usize = 1;
var j: usize = 1;
while (i * j < 2000) : ({ i *= 2; j *= 3; }) {
    const my_ij = i * j;
    try expect(my_ij < 2000);
}
```

:::

### 作为表达式使用

zig 还允许我们将 while 作为表达式来使用，此时需要搭配 `else` 和 `break`。

这里的 `else` 是当 while 循环结束并且没有经过 `break` 返回值时触发，而 `break` 则类似于return，可以在 while 内部返回值。

```zig
fn rangeHasNumber(begin: usize, end: usize, number: usize) bool {
    var i = begin;
    return while (i < end) : (i += 1) {
        if (i == number) {
            break true;
        }
    } else false;
}
```

### 标记

`continue` 的效果类似于 `goto`，并不推荐使用，因为它和 `goto` 一样难以把控，以下示例中，outer 就是标记。

`break` 的效果就是在标记处的 while 执行 break 操作，当然，同样不推荐使用。

它们只会增加你的代码复杂性，非必要不使用！

```zig
var i: usize = 0;
outer: while (i < 10) : (i += 1) {
    while (true) {
        continue :outer;
    }
}

outer: while (true) {
        while (true) {
            break :outer;
        }
    }
```

### 内联 `inline`

`inline` 关键字会将 while 循环展开，这允许代码执行一些一些仅在编译时有效的操作。

:::code-group

```zig [default]
pub fn main() !void {
    comptime var i = 0;
    var sum: usize = 0;
    inline while (i < 3) : (i += 1) {
        const T = switch (i) {
            0 => f32,
            1 => i8,
            2 => bool,
            else => unreachable,
        };
        sum += typeNameLength(T);
    }
    try expect(sum == 9);
}

fn typeNameLength(comptime T: type) usize {
    return @typeName(T).len;
}
```

```zig [more]
const std = @import("std");
const expect = std.testing.expect;

pub fn main() !void {
    comptime var i = 0;
    var sum: usize = 0;
    inline while (i < 3) : (i += 1) {
        const T = switch (i) {
            0 => f32,
            1 => i8,
            2 => bool,
            else => unreachable,
        };
        sum += typeNameLength(T);
    }
    try expect(sum == 9);
}

fn typeNameLength(comptime T: type) usize {
    return @typeName(T).len;
}
```

:::

:::info 🅿️ 提示
建议以下情况使用内联 while：

- 需要在编译期执行循环
- 你确定展开后会代码效率会更高
  :::

### 解构可选类型

### 结构错误联合类型