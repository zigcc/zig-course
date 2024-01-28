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
        // 下一行代表返回到blk这个tag处
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

### 作为表达式使用

::: code-group

```zig [default]
const os_msg = switch (builtin.target.os.tag) {
    .linux => "we found a linux user",
    else => "not a linux user",
};
```

```zig [more]
const builtin = @import("builtin");

pub fn main() !void {
    const os_msg = switch (builtin.target.os.tag) {
        .linux => "we found a linux user",
        else => "not a linux user",
    };
    _ = os_msg;
}
```

:::

### 捕获 `Tag Union`

我们还可以使用 switch 对标记联合类型进行捕获操作，对字段值的修改可以通过在捕获变量名称之前放置 `*` 并将其转换为指针来完成：

::: code-group

```zig [default]
const Item = union(enum) {
    a: u32,
    c: Point,
    d,
    e: u32,
};

var a = Item{ .c = Point{ .x = 1, .y = 2 } };

const b = switch (a) {
    // 多个匹配
    Item.a, Item.e => |item| item,

    // 可以使用 * 语法来捕获对应的指针进行修改操作
    Item.c => |*item| blk: {
        item.*.x += 1;
        break :blk 6;
    },

    // 这里最后一个联合类型,匹配已经穷尽了，我们就不需要使用else了
    Item.d => 8,
};
```

```zig [more]
const std = @import("std");
pub fn main() !void {
    const Point = struct {
        x: u8,
        y: u8,
    };
    const Item = union(enum) {
        a: u32,
        c: Point,
        d,
        e: u32,
    };

    var a = Item{ .c = Point{ .x = 1, .y = 2 } };

    const b = switch (a) {
        // 多个匹配
        Item.a, Item.e => |item| item,

        // 可以使用 * 语法来捕获对应的指针进行修改操作
        Item.c => |*item| blk: {
            item.*.x += 1;
            break :blk 6;
        },

        // 这里最后一个联合类型,匹配已经穷尽了，我们就不需要使用else了
        Item.d => 8,
    };

    std.debug.print("{any}\n", .{b});
}
```

:::

### 匹配和推断枚举

在使用 switch 匹配时，也可以继续对枚举类型进行自动推断：

```zig
const Color = enum {
    auto,
    off,
    on,
};
const color = Color.off;
// 编译器会帮我们完成其余的工作
const result = switch (color) {
    .auto => false,
    .on => false,
    .off => true,
};
```

### 内联 switch

switch 的分支可以标记为 `inline` 来要求编译器生成该分支对应的所有可能分支：

```zig
// 这段函数用来判断一个结构体的字段是否是 optional，同时它也是 comptime 的
// 故我们可以在下面使用inline 来要求编译器帮我们展开这个switch
fn isFieldOptional(comptime T: type, field_index: usize) !bool {
    const fields = @typeInfo(T).Struct.fields;
    return switch (field_index) {
        // 这里每次都是不同的值
        inline 0...fields.len - 1 => |idx| @typeInfo(fields[idx].type) == .Optional,
        else => return error.IndexOutOfBounds,
    };
}
```

`inline else` 可以展开所有的 else 分支，这样做的好处是，允许编译器在编译时显示生成所有分支，这样在编译时可以检查分支是否均能被正确地处理：

```zig
fn withSwitch(any: AnySlice) usize {
    return switch (any) {
        inline else => |slice| slice.len,
    };
}
```

当使用 `inline else` 捕获 tag union 时，可以额外捕获 tag 和对应的 value：

```zig
const U = union(enum) {
    a: u32,
    b: f32,
};

fn getNum(u: U) u32 {
    switch (u) {
        // 这里 num 是一个运行时可知的值
        // 而 tag 则是对应的标签名，这是编译期可知的
        inline else => |num, tag| {
            if (tag == .b) {
                return @intFromFloat(num);
            }
            return num;
        }
    }
}
```
