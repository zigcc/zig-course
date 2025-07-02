---
outline: deep
---

# 变量声明与定义

> 变量的声明和定义是编程语言中最基础且最常见的操作之一。

## 变量声明

> 变量是用于在内存中存储值的命名空间。

在 Zig 中，我们使用 `var` 关键字来声明变量，其格式为 `var variable_name: Type = initial_value;`。以下是一个示例：

<<<@/code/release/define_variable.zig#define

::: info 🅿️ 提示

目前 Zig 遵循“非必要不使用变量”的原则，即尽可能使用常量。

同时，Zig 要求所有非顶层定义的变量（包括常量）都必须被使用。如果变量未被使用，编译器会报告错误，但可以通过将其赋值给 `_` 来解决此问题。

:::

### 标识符命名

在 Zig 中，**_禁止变量遮蔽（shadowing）外部作用域的同名变量_**！

标识符必须以**字母**或**下划线**开头，后跟任意字母、数字或下划线，并且不得与关键字重叠。

如果需要使用不符合这些规定的名称（例如与外部库的链接），可以使用 `@""` 语法。

<<<@/code/release/define_variable.zig#identifier

::: info 🅿️ 提示

注意，上方代码 `const color: Color = .@"really red";` 后面的 `.@"really red"` 是一个枚举推断，这是由编译器完成的。更多内容请参见[_枚举_](/basic/advanced_type/enum)章节！

:::

### 常量

Zig 使用 `const` 关键字来声明常量。常量一旦声明并赋值后，其值便不可更改，只能在初次声明时进行赋值。

<<<@/code/release/define_variable.zig#const

### `undefined`

我们可以使用 `undefined` 关键字使变量保持未初始化状态。

<<<@/code/release/define_variable.zig#undefined

使用 `undefined` 初始化的变量不会执行任何初始化操作，因此我们无法预知其初始值。

`undefined` 常用于初始值不重要的场合。例如，用作缓冲区的变量通常会被传递给另一个函数进行写入操作，覆盖原有内容。由于不会对其进行读取操作，因此没有必要将这个变量初始化为某个特定值。

<<<@/code/release/define_variable.zig#use-undefined

::: warning ⚠️ 警告

慎重使用 `undefined`：如果一个变量的值是未定义的，那么对其进行读取操作时，读取到任何值都是可能的，甚至可能读取到对于该变量所使用的类型而言完全没有意义的值。

在 `Debug` 模式下，Zig 会将 `0xaa` 字节写入未定义的内存。这是为了尽早发现错误，并帮助检测调试器中未定义内存的使用。然而，此行为仅是一种实现细节，而非语言语义，因此不能保证代码可以观察到它。
:::

## 解构赋值

解构赋值（Destructuring Assignment）是 Zig `0.12` 版本引入的新语法，允许对可索引的聚合结构（如元组、向量和数组）进行解构。

<<<@/code/release/define_variable.zig#deconstruct

解构表达式只能出现在块内（不在容器范围内）。赋值的左侧必须由逗号分隔的列表组成，其中每个元素可以是左值（例如 `var` 变量）或变量声明：

<<<@/code/release/define_variable.zig#deconstruct_2

解构表达式可以以 `comptime` 关键字作为前缀。在这种情况下，整个解构表达式在编译期（`comptime`）求值。所有声明的 `var` 都将是 `comptime var`，并且所有表达式（左值和右值）都在编译期求值。

## 块

块（block）用于限制变量声明的作用域。例如，以下代码是非法的：

```zig
{
    var x: i32 = 1;
    _ = &x;
}
x += 1;
```

块也可以是一个表达式。当块带有标签时，`break` 语句可以从块中返回一个值。

<<<@/code/release/define_variable.zig#block

上方的 `blk` 是标签名称，你可以设置任何你喜欢的名字。

### Shadow（遮蔽）

Shadow（遮蔽）指的是在内部作用域中声明一个与外部作用域中同名的变量，导致外部作用域的变量被“遮蔽”的现象。

然而，这种行为在 Zig 中是被禁止的！
这样做的好处是强制标识符在其生命周期内保持一致性，并防止意外使用错误的变量。

注意：如果两个块中的变量作用域不交叉，那么它们可以同名。

### 空的块

空的块等效于 `void{}`，即一个空的函数体。

## 容器

在 Zig 中，**容器** 是充当命名空间的任何语法结构，用于保存变量和函数声明。容器也可以是可实例化的类型定义。结构体、枚举、联合、不透明类型，甚至 Zig 源文件本身都是容器。然而，容器不能包含语句（语句是描述程序运行操作的一个单位）。

当然，你也可以这样理解：容器是一个只包含变量或常量定义以及函数定义的命名空间。

注意：容器和块（block）是不同的概念！

> [!IMPORTANT]
> 初次阅读此处感到困惑是正常的。在学习完后续概念后，此处内容将自然理解。

## 注释

接下来我们了解如何在 Zig 中正确书写注释。Zig 支持三种注释方式：普通注释、文档注释和顶层文档注释。

`//` 是普通注释，其作用与其他编程语言中的 `//` 相同。

::: details 小细节
值得一提的是，Zig 本身并未提供类似 `/* */` 这种多行注释。这意味着多行注释的最佳实践形式是使用多行的 `//`。

PS: 说实话，我认为这个设计并不太好。
:::

`///` 是文档注释，用于为函数、类型、变量等提供说明。文档注释记录了紧随其后的代码元素。

<<<@/code/release/define_variable.zig#doc-comment

`//!` 是顶层文档注释，通常用于记录文件的作用。**它必须放在作用域的顶层，否则会导致编译错误**。

<<<@/code/release/define_variable.zig#top-level

::: details 小细节
为什么是作用域顶层呢？实际上，Zig 将一个源码文件看作是一个容器。
:::

## `usingnamespace`

关键字 `usingnamespace` 可以将一个容器中的所有 `pub` 声明混入到当前的容器中。

例如，可以使用 `usingnamespace` 将 `std` 标准库混入到 `main.zig` 这个容器中：

```zig
const T = struct {
    usingnamespace @import("std");
};
pub fn main() !void {
    T.debug.print("Hello, World!\n", .{});
}
```

注意：无法在结构体 `T` 内部直接使用混入的声明，需要使用 `T.debug` 这种方式才可以！

`usingnamespace` 还可以使用 `pub` 关键字进行修饰，用于转发声明，这常用于组织 API 文件和 C 语言的 `import`。

```zig
pub usingnamespace @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("GLFW/glfw3.h");
    @cDefine("STBI_ONLY_PNG", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});
```

相关的使用方法可以是这样的：

```zig
pub usingnamespace @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xproto.h");
});
```

针对以上引入的头文件，我们可以这样使用 `@This().xcb_generic_event_t`。

> [!IMPORTANT]
> 初次阅读此处感到困惑是正常的。在学习完后续概念后，此处内容将自然理解。

## `threadlocal`

变量可以使用 `threadlocal` 修饰符，使得该变量在不同线程中拥有不同的实例：

<<<@/code/release/define_variable.zig#threadlocal
