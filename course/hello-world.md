---
outline: deep
---

# Hello World

与学习其他编程语言一样，我们也将从经典的 `Hello, World!` 程序开始，以此向 Zig 的世界打一声招呼。

首先，使用 `zig init` 命令初始化一个可执行项目，然后将以下内容覆盖写入到 `src/main.zig` 文件中。

<!-- 引入代码片段 -->
<!-- 具体说明见：https://vitepress.dev/zh/guide/markdown#import-code-snippets -->

<<<@/code/release/hello_world.zig#one

接着运行 `zig build run` 命令，你就可以在终端看到熟悉的 `Hello, World!` 了。

_很简单，不是吗？_

## 代码解析

上述程序通过内建函数 `@import` 导入了 Zig 的标准库 `std`。
在 Zig 中，所有内建函数都以 `@` 符号开头，并遵循小驼峰命名法（lowerCamelCase）。

::: info 🅿️ 提示

`@import` 函数用于查找并导入相应名称的模块或 Zig 源文件（以 `.zig` 为后缀）。

Zig 默认可导入三个核心模块：

- `std`：标准库。
- `builtin`：与构建目标相关的信息。
- `root`：项目的根文件（编译时指定的入口文件，通常是 `src/main.zig`）。

:::

程序的入口点是 `main` 函数。我们在 `main` 函数中调用了标准库 `debug` 包内的 `print` 函数，输出了 "Hello, World!"。

`print` 函数的用法类似于 C 语言的 `printf`，它接受两个参数：第一个是格式化字符串，第二个是包含替换值的元组（tuple）。

- **格式化字符串**：使用 `{}` 作为占位符。Zig 会自动推断值的类型。如果无法推断，则需要显式指定，例如 `{s}` 代表字符串，`{d}` 代表整数。
- **参数**：第二个参数是一个元组，你可以将其理解为一个匿名结构体。

::: warning ⚠️ 注意
`std.debug.print` 主要用于调试，不推荐在生产环境中使用。因为它会将信息打印到 `stderr`，且在某些构建模式下可能会被编译器优化掉。
这只是一个入门示例，接下来我们将探讨更“正确”的打印方式。
:::

下面的内容涉及更底层的概念，你可以*暂时跳过*，待熟悉 Zig 后再来回顾。

## 更标准的输出方式

“打印 Hello, World”看似简单，但在 Zig 中，它能引导我们思考一些底层设计。

Zig 本身没有内置的 `@print()` 函数，输出功能通常由标准库的 `log` 和 `io` 包提供。`std.debug.print` 是一个特例，主要用于调试。

让我们看一个更规范的例子（**但请注意，此代码同样不建议直接用于生产环境**）：

<<<@/code/release/hello_world.zig#two

:::info 🅿️ 提示
`main` 函数的返回类型 `!void` 是一个错误联合类型。它表示该函数要么成功执行并返回 `void`（即无返回值），要么返回一个错误。
:::

这段代码分别向 `stdout` 和 `stderr` 输出了信息。

- `stdout` (标准输出)：用于输出程序的正常信息。写入 `stdout` 的操作可能会失败。
- `stderr` (标准错误)：用于输出错误信息。我们通常假定写入 `stderr` 的操作不会失败（由操作系统保证）。

我们通过 `std.io` 模块获取了标准输出和标准错误的 `writer`，它们提供了 `print` 方法，可以将格式化的字符串写入对应的 I/O 流。

### 考虑性能：使用缓冲区

`print` 函数的每次调用都可能触发一次系统调用（System Call），这会带来内核态与用户态之间上下文切换的开销，影响性能。为了解决这个问题，我们可以引入缓冲区（Buffer），将多次输出的内容攒在一起，然后通过一次写入操作完成，从而减少系统调用的次数。

实现方式如下：

<<<@/code/release/hello_world.zig#three

通过 `std.io.bufferedWriter`，我们为 `stdout` 和 `stderr` 的 `writer` 添加了缓冲功能，从而提高了性能。

## 更进一步：线程安全

以上代码在单线程环境下工作良好，但在多线程环境中，多个线程同时调用 `print` 可能会导致输出内容交错混乱。

为了保证线程安全，我们需要为 `writer` 添加锁。

你可以使用 `std.Thread.Mutex` 来实现一个线程安全的 `writer`。

我们鼓励你阅读[标准库源码](https://ziglang.org/documentation/master/std/#std.Thread.Mutex)来深入了解其工作原理。

## 了解更多

如果你想深入探索这个话题，可以观看此视频：[Advanced Hello World in Zig - Loris Cro](https://youtu.be/iZFXAN8kpPo?si=WNpp3t42LPp1TkFI)
