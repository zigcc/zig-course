---
outline: deep
---

# 字符与布尔值

> 在计算机中定义的 _字符_ 往往都是 [ASCII](https://en.wikipedia.org/wiki/ASCII) 码表的值，绝非我们平常所指的单个文字。
>
> 布尔值往往通过二进制的 0 和 1 来表示。

## 字符

这个类型其实平常使用不算多，在 zig 中字符就是 `u8`，并且需要是 ASCII 码表中的内容,这和 C 的逻辑基本相同（“基本”的原因见 `c_char` 说明）。

具体可以参照以下例子：

```zig
const print = @import("std").debug.print;

pub fn main() void {
    var char: u8 = 'h';
    print("{c}\n", .{char});
}
```

:::tip 🅿️ 提示

由于 char 本质就是 `u8` 类型，所以你可以使用 ASCII 码表的值来替换字符，例如 h 在表中对应的值是 104,那么以下，两种输出方式的结果应该是一样的。

```zig
const print = @import("std").debug.print;

pub fn main() void {
    var char: u8 = 'h';
    var char_num:u8 = 104;
    print("{c}\n", .{char});
    print("{c}\n", .{char_num});
}
```

:::

:::details 关于 `c_char`

你如果自行看了 zig 官方文档中关于类型的部分，应该会注意到 `c_char` 类型，它对应 C 中的 `char` 类型。

但是需要注意，`u8` 和 `c_char` 并不是全等的，因为 `c_char` 虽然是 8 位，但是它是否有符号取决于 target (目标机器)。

:::

## 布尔值

> 常用于流程控制

在 zig 中，布尔值有两个，分别是 `true` 和 `false`， 它们在内存中占用的大小为1个字节。
