---
outline: deep
---

# 编译期

在开始之前，我们需要先梳理一下，什么是**编译期**？

对于这个概念，你可能会一脸懵逼。所以我们先看一下什么是运行时（runtime）：

> “在计算机科学中代表一个计算机程序从开始执行到终止执行的运作、执行的时期。”

对应地，我们可以尝试给编译期做一个定义：“zig 编译期是指在 zig 编译期间执行的动作。”

:::info 🅿️ 提示

在 Zig 中，类型是一等公民。它们可以分配给变量，作为参数传递给函数，并从函数返回。但需要注意：它们只能用于**编译期**已知的语句或函数中！

通常一个编译期已知的语句或函数带有 `comptime` 关键字！

:::

`comptime` 这个关键字表示：

- 在这个调用点，标记的值必须是在编译期已知的，否则 zig 会报告错误！
- 在函数定义中，该值（包括参数、类型）必须是编译期已知的（但无需全部都是编译期已知的，仅保证依赖关系中的符合即可）！

## 编译期参数实现鸭子类型

> “当看到一只鸟走起来像鸭子、游泳起来像鸭子、叫起来也像鸭子，那么这只鸟就可以被称为鸭子。”

一个实现 `max` 功能的函数：

<<<@/code/release/comptime.zig#DuckType_max

以上，我们定义了一个函数，它包含一个编译期参数 `T`，这个 `T` 的类型是 `type`，也就是一个类型，同时其他的参数和返回值类型也都是 `T`，这意味着参数类型与返回值类型是一致的。

很明显，上述的 `max` 函数仅仅只能比较整数和浮点数，我们可以稍稍改造它一下变成 `maxPlus`，使之支持布尔值：

<<<@/code/release/comptime.zig#DuckType_maxPlus

我们可以看到，`T` 是一个参数（参数在 zig 中均是只读的），我们可以正常把它当作常量来使用。

:::info 🅿️ 提示

上面操作可行的原因：

因为编译期会在编译期隐式内联 `if` 表达式，并且会跳过对未使用的分支的分析（可以简单看作删掉了该分支），所以当传入的 `T` 是 `bool` 时，编译后的结果是这个样子：

<<<@/code/release/comptime.zig#DuckType_max_actual

这些额外未使用的分支在编译时会被“裁剪掉”，只保留运行时所需要的分支。

:::

> [!TIP]
>
> 注意：这也适用于 `switch`。

## 编译期变量

变量可以也标记上 `comptime`，标记变量是编译期已知的。这会通知编译器，该变量的读取和写入完全是在编译期执行的，任何发生运行时对变量的操作将会在编译时报错。

该特性可以与 `inline` 一起使用，以下的示例仅仅是示范作用（实际没有必要这么操作）：

::: code-group

<<<@/code/release/comptime.zig#comptimeVariable_default [default]

<<<@/code/release/comptime.zig#comptimeVariable [more]

:::

针对不同的参数，实际上会在编译期生成不同的代码：

> [!TIP]
>
> 注意：以下函数命名仅仅是为了区分才如此命名！

<<<@/code/release/comptime.zig#comptimeVariable_t

<<<@/code/release/comptime.zig#comptimeVariable_o

<<<@/code/release/comptime.zig#comptimeVariable_w

:::info 🅿️ 提示

这种编译期变量的实现，更多是为了代替需要使用宏、代码生成、预处理器的场景。

:::

## 编译期表达式

通过 `comptime` 标记告诉编译器表达式需要在编译期完成计算，如果无法完成计算，编译器将会报告错误。

对于一个编译期表达式，它有以下特性：

- 所有变量都是 `comptime` 变量
- 所有 `if`、`while`、`for` 和 `switch` 表达式都在编译时求值，否则报告编译错误。
- 所有 `return` 和 `try` 表达式都是无效的（除非函数本身在编译时被调用）。
- 所有具有运行时副作用或依赖于运行时值的代码都会触发编译错误。
- 所有函数调用都会导致编译器在编译时分析该函数，如果该函数尝试执行具有全局运行时副作用的操作，则会触发编译错误。

:::info 🅿️ 提示

故我们无需专门为编译期表达式编写函数，只需要编写普通的函数就行。

:::

一个简单的斐波那契数列函数：

<<<@/code/release/comptime.zig#comptimeExpression

以上函数实现了 [斐波那契数列](https://zh.wikipedia.org/zh-sg/斐波那契数)，注意到我们使用的是递归方法来实现，在编译期，堆栈的嵌套层数最大是：1000，如果超过了这个值，可以使用 [`@setEvalBranchQuota`](https://ziglang.org/documentation/master/#setEvalBranchQuota)，来修改默认的堆栈嵌套。

:::info 🅿️ 提示

注意：当前的自托管编译期设计存在某些缺陷（使用自己的堆栈进行 comptime 函数调用），当宿主机器并没有提供足够大的堆栈时，将导致堆栈溢出，具体问题可以见这个 [issue](https://github.com/ziglang/zig/issues/13724)。

:::

在容器（Container）级别（任何函数之外），所有表达式都是隐式的 `comptime` 表达式，这意味着我们可以使用函数来初始化复杂的静态数据。例如：

<<<@/code/release/comptime.zig#comptimeExpression_container

`add_comptime` 函数作为编译期可执行函数，我们用它来进行数据的初始化，当然我们这里可以直接赋值为 `3`，这里仅仅作为示例。当我们在处理复杂数据时很有用。

## 生成数据结构

通过使用编译期特性，可以使用 `comptime` 来生成数据结构，无需引入额外语法。

<<<@/code/release/comptime.zig#GenericDataStruct

以上代码，我们通过 `List` 函数初始化变量 `list`，它是一个结构体的示例，`List(i32)` 返回的是一个结构体类型。

:::info 🅿️ 提示

关于这个结构体的名字，它是由编译器决定的，根据创建匿名结构体时调用的函数名称和参数推断出名称为`List(i32)`。

:::

例如简单实现一个单链表的结构：

<<<@/code/release/comptime.zig#GenericDataStruct_node

在此示例中，`Node` 结构引用自身。这完全可行，因为所有顶级声明都是与顺序无关的。

只要编译器可以确定结构的大小，就可以自由地引用其自身。

在这种情况下，Node 将自身称为指针，该指针在编译时具有明确定义的大小，因此它可以正常工作。
