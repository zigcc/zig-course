---
outline: deep
---

# 数组

数组是日常敲代码使用相当频繁的类型之一，在 zig 中，数组的分配和 C 类似，均是在内存中连续分配且固定数量的相同类型元素。

因此数组有以下三点特性：

- 长度固定
- 元素必须有相同的类型
- 依次线性排列

## 创建数组

在 zig 中，你可以使用以下的方法，来声明并定义一个数组：

<<<@/code/release/array.zig#create_array

以上代码展示了定义一个字面量数组的方式，其中你可以选择指明数组的大小或者使用 `_` 代替。使用 `_` 时，zig 会尝试自动计算数组的长度。

数组元素是连续放置的，故我们可以使用下标来访问数组的元素，下标索引从 `0` 开始！

关于[越界问题](https://ziglang.org/documentation/master/#Index-out-of-Bounds)，zig 在编译期和运行时均有完整的越界保护和完善的堆栈错误跟踪。

### 多维数组

多维数组（矩阵）实际上就是嵌套数组，我们很容易就可以创建一个多维数组出来：

<<<@/code/release/array.zig#matrix

在以上的示例中，我们使用了 [for](/basic/process_control/loop) 循环，来进行矩阵的打印，关于循环我们放在后面再聊。

## 哨兵数组（标记终止数组）

> 很抱歉，这里的名字是根据官方的文档直接翻译过来的，原文档应该是 ([Sentinel-Terminated Arrays](https://ziglang.org/documentation/master/#toc-Sentinel-Terminated-Arrays)) 。

:::info

本质上来说，这是为了兼容 C 中的规定的字符串结尾字符`\0`

:::

我们使用语法 `[N:x]T` 来描述一个元素为类型 `T`，长度为 `N` 的数组，在它对应 `N` 的索引处的值应该是 `x`。前面的说法可能比较复杂，换种说法，就是这个语法表示数组的长度索引处的元素应该是 `x`，具体可以看下面的示例：

<<<@/code/release/array.zig#terminated_array

:::info 🅿️ 提示

注意：只有在使用哨兵时，数组才会有索引为数组长度的元素！

:::

## 操作

:::info

以下操作都是编译期 (comptime) 的，如果你需要运行时地处理数组操作，请使用 `std.mem`。

:::

### 乘法

可以使用 `**` 对数组做乘法操作，运算符左侧是数组，右侧是倍数，进行矩阵的叠加。

<<<@/code/release/array.zig#multiply

### 串联

数组之间可以使用 `++` 进行串联操作（编译期），只要两个数组的元素类型相同，它们就可以串联！

<<<@/code/release/array.zig#connect

## 奇技淫巧

受益于 zig 自身的语言特性，我们可以实现某些其他语言所不具备的方式来操作数组。

### 使用函数初始化数组

可以使用函数来初始化数组，函数要求返回一个数组的元素或者一个数组。

<<<@/code/release/array.zig#func_init_array

### 编译期初始化数组

通过编译期来初始化数组，以此来抵消运行时的开销！

<<<@/code/release/array.zig#comptime_init_array

这个示例中，我们使用了编译期的功能，来帮助我们实现这个数组的初始化，同时还利用了 `blocks` 和 `break` 的性质，关于这个我们会在 [循环](/basic/process_control/loop) 讲解！
