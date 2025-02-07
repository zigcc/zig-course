---
outline: deep
---

# 结构体

> 在 zig 中，类型是一等公民！

结构体本身是一个高级的数据结构，用于将多个数据表示为一个整体。

## 基本语法

结构体的组成：

- 首部关键字 `struct`
- 和变量定义一样的结构体名字
- 多个字段
- 方法
- 多个声明

以下是一个简短的结构体声明：

::: code-group

<<<@/code/release/struct.zig#default_struct [default]

<<<@/code/release/struct.zig#more_struct [more]

:::

上方的代码的内容：

- 定义了一个结构体 `Circle`，用于表示一个圆
- 包含字段 `radius`
- 一个声明 `PI`
- 包含两个方法 `init` 和 `area`

:::info 🅿️ 提示

值得注意的是，结构体的方法除了使用 `.` 语法来使用外，和其他的函数没有任何区别！这意味着你可以在任何你用普通函数的地方使用结构体的方法。

:::

## 自引用

常见的自引用方式是函数第一个参数为结构体指针类型，例如：

::: code-group

<<<@/code/release/struct.zig#deault_self_reference1 [default]

<<<@/code/release/struct.zig#more_self_reference1 [more]

:::

平常使用过程中会面临另外的一个情况，就是匿名结构体要如何实现自引用呢？

答案是使用 [`@This`](https://ziglang.org/documentation/master/#This)，这是 zig 专门为匿名结构体和文件类的类型声明（此处可以看 [命名空间](../../more/miscellaneous.md#容器)）提供的处理方案。

此函数会返回一个当前包裹它的容器的类型！

例如：

::: code-group

<<<@/code/release/struct.zig#deault_self_reference2 [default]

<<<@/code/release/struct.zig#more_self_reference2 [more]

:::

:::details 更复杂的例子

下面是一个日常会用到的一个结构体例子，系统账号管理的使用：

::: code-group

<<<@/code/release/struct.zig#deault_self_reference3 [default]

<<<@/code/release/struct.zig#more_self_reference3 [more]

在以上的代码中，我们使用了内存分配的功能，并且使用了切片和多行字符串，以及 `defer` 语法（在当前作用域的末尾执行语句）。

:::

## 自动推断

zig 在使用结构体的时候还支持省略结构体类型，只要能让 zig 编译器推断出类型即可，例如：

<<<@/code/release/struct.zig#auto_reference

## 泛型实现

依托于“类型是 zig 的一等公民”，我们可以很容易的实现泛型。

此处仅仅是简单提及一下该特性，后续我们会专门讲解泛型这一个利器！

以下是一个链表的类型实现：

<<<@/code/release/struct.zig#linked_list

:::info 🅿️ 提示

当然这种操作不局限于声明变量，你在函数中也可以使用（当编译器无法完成推断时，它会给出一个包含完整堆栈跟踪的报错）！

:::

## 字段默认值

结构体允许使用默认值，只需要在定义结构体的时候声明默认值即可：

<<<@/code/release/struct.zig#default_field

## 空结构体

你还可以使用空结构体，具体如下：

::: code-group

<<<@/code/release/struct.zig#default_empty_struct [default]

<<<@/code/release/struct.zig#more_empty_struct [more]

:::

:::info 🅿️ 提示

使用 Go 的朋友对这个可能很熟悉，在 Go 中经常用空结构体做实体在 chan 中传递，它的内存大小为 0！  
而在 C++ 中，这样的空结构体的内存大小则是 1。

:::

## 通过字段获取基指针（基于字段的指针）

为了获得最佳的性能，结构体字段的顺序是由编译器决定的，但是，我们可以仍然可以通过结构体字段的指针来获取到基指针！

<<<@/code/release/struct.zig#base_ptr

这里使用了内建函数 [`@fieldParentPtr`](https://ziglang.org/documentation/master/#toc-fieldParentPtr) ，它会根据给定字段指针，返回对应的结构体基指针。

## 元组

元组实际上就是不指定字段的（匿名）结构体。

由于没有指定字段名，zig 会使用从 0 开始的整数依次为字段命名。但整数并不是有效的标识符，所以使用 `.` 语法访问字段的时候需要将数字写在 `@""` 中。

<<<@/code/release/struct.zig#tuple

当然，以上的语法很啰嗦，所以 zig 提供了类似**数组的语法**来访问元组，例如 `values[3]` 的值就是 "hi"。

:::info 🅿️ 提示

元组还有一个和数组一样的字段 `len`，并且支持 `++` 和 `**` 运算符，以及[内联 for](../process_control/loop.md#内联-inline)。

:::

## 高级特性

以下特性如果你连名字都没有听说过，那就代表你目前无需了解以下部分，待需要时再来学习即可！

> zig 并不保证结构体字段的顺序和结构体大小，但保证它是 ABI 对齐的。

### extern

`extern` 关键字用于修饰结构体，使其内存布局保证匹配对应目标的 C ABI。

这个关键字适合使用于嵌入式或者裸机器上，其他情况下建议使用 `packed` 或者普通结构体。

### packed

`packed` 关键字修饰结构体，普通结构体不同，它保证了内存布局：

- 字段严格按照声明的顺序排列
- 在不同字段之间不会存在位填充（不会发生内存对齐）
- zig 支持任意位宽的整数（通常不足 8 位的仍然使用 8 位），但在 `packed` 下，会只使用它们的位宽
- `bool` 类型的字段，仅有一位
- 枚举类型只使用其整数标志位的位宽
- 联合类型只使用其最大位宽
- 根据目标的字节顺序，非 ABI 字段会被尽量压缩为占用尽可能小的 ABI 对齐整数的位宽。

以上几个特性就有很多有意思的点值得我们使用和注意。

1. zig 允许我们获取字段指针。如果字段涉及位偏移，那么该字段的指针就无法赋值给普通指针（因为位偏移也是指针对齐信息的一部分）。这个情况可以使用 [`@bitOffsetOf`](https://ziglang.org/documentation/master/#bitOffsetOf) 和 [`@offsetOf`](https://ziglang.org/documentation/master/#offsetOf) 观察到：

:::details 示例

<<<@/code/release/struct.zig#packed_bit_offset

:::

2. 使用位转换 [`@bitCast`](https://ziglang.org/documentation/master/#bitCast) 和指针转换 [`@ptrCast`](https://ziglang.org/documentation/master/#ptrCast) 来强制对 `packed` 结构体进行转换操作：

:::details 示例

<<<@/code/release/struct.zig#packed_cast

:::

3. 还可以对 `packed` 的结构体的指针设置内存对齐来访问对应的字段：

:::details 示例

<<<@/code/release/struct.zig#aligned_struct

:::

4. `packed struct` 会保证字段的顺序以及在字段间不存在额外的填充，但针对结构体本身可能仍然存在额外的填充：

:::details 示例

<<<@/code/release/struct.zig#reorder_struct

输出为：

```sh
16
12
0
4
```

在 64 位系统上，Foo 的内存布局是：

```sh
|   4(i32)  |  8(pointer)    |   4(padding)  |
```

额外的讨论信息：[github issue #20265](https://github.com/ziglang/zig/issues/20265)

:::

### 命名规则

由于在 zig 中很多结构是匿名的（例如可以把一个源文件看作是一个匿名的结构体），所以 zig 基于一套规则来进行命名：

- 如果一个结构体位于变量的初始化表达式中，它就以该变量命名（实际上就是声明结构体类型）。
- 如果一个结构体位于 `return` 表达式中，那么它以返回的函数命名，并序列化参数。
- 其他情况下，结构体会获得一个类似 `filename.funcname.__struct_ID` 的名字。
- 如果该结构体在另一个结构体中声明，它将以父结构体和前面的规则推断出的名称命名，并用点分隔。

上面几条规则看着很模糊是吧，我们来几个小小的示例来演示一下：

::: code-group

<<<@/code/release/struct.zig#name_principle

```sh [output]
variable: struct_name.main.Foo
anonymous: struct_name.main__struct_3509
function: struct_name.List(i32)
```

:::
