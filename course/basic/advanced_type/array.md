---
outline: deep
---

# 数组

数组是日常编程中使用相当频繁的数据类型之一，在 Zig 中，数组的内存分配方式与 C 类似：在内存中连续分配固定数量的相同类型的元素。

因此，数组具有以下三个特性：

- 长度固定
- 元素必须有相同的类型
- 依次线性排列

## 创建数组

在 Zig 中，你可以使用以下方式来声明并定义一个数组：

<<<@/code/release/array.zig#create_array

以上代码展示了如何定义一个字面量数组。其中，你可以明确指定数组的大小，也可以使用 `_` 让 Zig 自动推断数组的长度。

数组元素是连续存放的，因此我们可以通过下标来访问数组元素。下标索引从 `0` 开始。

关于[越界问题](https://ziglang.org/documentation/master/#Index-out-of-Bounds)，Zig 在编译期和运行时都提供了完整的越界保护和完善的堆栈错误跟踪。

### 解构数组

我们在变量声明的章节中提到过，数组可以被解构。让我们回顾一下：

<<<@/code/release/array.zig#deconstruct

### 多维数组

多维数组（矩阵）实际上就是嵌套的数组。我们可以很容易地创建一个多维数组：

<<<@/code/release/array.zig#matrix

在以上示例中，我们使用了 [for](/basic/process_control/loop) 循环来打印矩阵。关于循环的更多细节，我们将在后续章节讨论。

## 哨兵数组（标记终止数组）

> 该名称直接翻译自官方文档的 ([Sentinel-Terminated Arrays](https://ziglang.org/documentation/master/#toc-Sentinel-Terminated-Arrays))。

:::info

其本质是为了兼容 C 语言中以 `\0` 作为结尾的字符串。

:::

我们使用 `[N:x]T` 语法来定义一个哨兵数组。它表示一个长度为 `N`、元素类型为 `T` 的数组，并且在索引 `N` 处的值固定为 `x`。换言之，在数组末尾有一个值为 `x` 的哨兵元素。请看下面的示例：

<<<@/code/release/array.zig#terminated_array

:::info 🅿️ 提示

注意：只有哨兵数组才能访问到索引为数组长度的元素！

:::

## 操作

:::info

以下操作都是在编译期（comptime）执行的。如果需要在运行时处理数组，请使用 `std.mem`。

:::

### 乘法

可以使用 `**` 对数组进行乘法操作。运算符左侧是数组，右侧是重复的次数，最终会生成一个更长的数组。

<<<@/code/release/array.zig#multiply

### 串联

可以使用 `++` 在编译期对数组进行串联。只要两个数组的元素类型相同，它们就可以被连接起来。

<<<@/code-release/array.zig#connect

## 奇技淫巧

得益于 Zig 独特的语言特性，我们可以用一些在其他语言中不常见的方式来操作数组。

### 使用函数初始化数组

我们可以使用函数来初始化数组。该函数需要返回数组的单个元素或整个数组。

<<<@/code/release/array.zig#func_init_array

### 编译期初始化数组

我们可以在编译期初始化数组，从而避免运行时的开销。

<<<@/code/release/array.zig#comptime_init_array

在这个示例中，我们利用编译期执行的特性来初始化数组，并结合了 `blocks` 和 `break` 的用法。关于这些，我们将在[循环](/basic/process_control/loop)章节中详细讲解。
