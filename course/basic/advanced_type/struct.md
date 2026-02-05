# 结构体

> 在 Zig 中，类型是“一等公民”！

结构体是一种高级数据结构，用于将多个相关数据组织成一个单一的实体。

## 基本语法

结构体的组成：

- 首部关键字 `struct`
- 与变量定义相同的结构体名称
- 多个字段
- 方法
- 多个声明

以下是一个简短的结构体声明：

::: code-group

<<<@/code/release/struct.zig#default_struct [default]

<<<@/code/release/struct.zig#more_struct [more]

:::

上面的代码展示了以下内容：

- 定义了一个结构体 `Circle`，用于表示一个圆
- 包含 `radius` 字段
- 一个常量声明 `PI`
- 包含两个方法 `init` 和 `area`

:::info 🅿️ 提示

值得注意的是，结构体的方法除了可以使用 `.` 语法调用外，与普通函数并无本质区别。这意味着你可以在任何可以使用普通函数的地方使用结构体的方法。

:::

## 结构体初始化

在声明了结构体类型之后，我们需要创建该类型的实例。Zig 使用 **结构体字面量（struct literal）** 语法来初始化结构体。

结构体字面量的完整语法是 `StructName{ .field1 = value1, .field2 = value2 }`：

<<<@/code/release/struct.zig#struct_init_basic

以上代码展示了：

- 使用结构体类型名称 `Point` 加上花括号 `{}` 来创建实例
- 花括号内使用 `.字段名 = 值` 的形式为每个字段赋值
- 字段之间用逗号分隔

:::info 🅿️ 提示

结构体字面量中必须为所有没有默认值的字段提供初始值，否则会产生编译错误。

:::

## 自引用

常见的自引用方式是将结构体自身的指针作为函数的第一个参数，例如：

::: code-group

<<<@/code/release/struct.zig#deault_self_reference1 [default]

<<<@/code/release/struct.zig#more_self_reference1 [more]

:::

在实际使用中，匿名结构体如何实现自引用是一个常见问题。

答案是使用 [`@This`](https://ziglang.org/documentation/master/#This)。这是 Zig 专门为匿名结构体和文件级别的类型声明（可以参考[命名空间](../../basic/define-variable.md#容器)章节）提供的解决方案。

它会返回当前包裹它的容器的类型。

例如：

::: code-group

<<<@/code/release/struct.zig#deault_self_reference2 [default]

<<<@/code/release/struct.zig#more_self_reference2 [more]

:::

:::details 更复杂的例子

下面是一个日常会用到的结构体例子，关于系统账号管理的使用：

::: code-group

<<<@/code/release/struct.zig#deault_self_reference3 [default]

<<<@/code/release/struct.zig#more_self_reference3 [more]

在以上代码中，我们使用了内存分配功能，并结合了切片、多行字符串以及 `defer` 语法（在当前作用域结束时执行语句）的应用。

:::

## 类型推断简写

在前面我们学习了结构体字面量的完整语法 `StructName{ .field = value }`。当 Zig 编译器能够从上下文推断出结构体类型时，可以省略类型名称，使用简写语法 `.{ .field = value }`。

这种机制被称为**[结果位置语义（Result Location Semantics）](../../advanced/result-location.md)**。

<<<@/code/release/struct.zig#struct_init_inferred

在上面的示例中：

- `pt2` 的类型已经被显式声明为 `Point`，因此编译器可以推断出 `.{ .x = 13, .y = 67 }` 应该是 `Point` 类型
- `origin()` 方法的返回类型已声明为 `Point`，因此返回值可以使用简写
- `printPoint` 函数的参数类型为 `Point`，调用时可以直接传入 `.{ .x = 100, .y = 200 }`

## 泛型实现

得益于“类型是 Zig 的一等公民”这一特性，我们可以轻松实现泛型。

此处仅简单提及该特性，后续我们将专门讲解泛型这一强大工具！

以下是一个链表的类型实现：

<<<@/code/release/struct.zig#linked_list

:::info 🅿️ 提示

当然，这种操作不局限于变量声明，在函数中也可以使用（当编译器无法完成推断时，会给出包含完整堆栈跟踪的错误提示）！

:::

## 字段默认值

结构体允许为字段设置默认值，只需在定义结构体时声明即可：

<<<@/code/release/struct.zig#default_field

然而，仅此还不够。在实际使用中，我们可能只初始化部分字段，而其他字段使用默认值。如果对结构体字段的默认值没有不变性要求，那么这种默认值方案已经足够使用。

但如果要求结构体字段的值具有默认不变性（即要么全部使用默认值，要么全部由使用者手动赋值），则可以采用以下方案：

<<<@/code/release/struct.zig#all_default

## 空结构体

你还可以使用空结构体，具体如下：

::: code-group

<<<@/code/release/struct.zig#default_empty_struct [default]

<<<@/code/release/struct.zig#more_empty_struct [more]

:::

:::info 🅿️ 提示

熟悉 Go 语言的读者可能对此很熟悉，在 Go 中空结构体常用于在 `chan` 中传递实体，其内存大小为 0。
而在 C++ 中，空结构体的内存大小通常为 1 字节。

:::

## 通过字段获取基指针（基于字段的指针）

为了获得最佳性能，结构体字段的内存布局顺序由编译器决定。然而，我们仍然可以通过结构体字段的指针来获取其基指针！

<<<@/code/release/struct.zig#base_ptr

这里使用了内建函数 [`@fieldParentPtr`](https://ziglang.org/documentation/master/#fieldParentPtr)，它会根据给定的字段指针，返回对应的结构体基指针。

## 元组

元组实际上是不指定字段名的（匿名）结构体。

由于没有指定字段名，Zig 会使用从 0 开始的整数依次为字段命名。但整数并不是有效的标识符，因此在使用 `.` 语法访问字段时，需要将数字写在 `@""` 中。

<<<@/code/release/struct.zig#tuple

当然，上述语法较为繁琐，因此 Zig 提供了类似**数组的语法**来访问元组，例如 `values[3]` 的值就是 "hi"。

:::info 🅿️ 提示

元组还有一个与数组相同的 `len` 字段，并且支持 `++` 和 `**` 运算符，以及[内联 for](../process_control/loop.md#内联-inline)。

:::

:::info 🅿️ 提示

元组也支持解构语法！

<<<@/code/release/struct.zig#destruct_tuple

:::

## 高级特性

以下特性可能对初学者来说较为陌生。如果你从未听说过这些概念，则目前无需深入了解，待需要时再来学习即可！

> Zig 并不保证结构体字段的顺序和结构体大小，但保证其符合 ABI 对齐要求。

### extern

`extern` 关键字用于修饰结构体，使其内存布局保证匹配对应目标的 C ABI。

该关键字适用于嵌入式系统或裸机编程，其他情况下建议使用 `packed` 或普通结构体。

### packed

`packed` 关键字修饰的结构体与普通结构体不同，它保证了以下内存布局特性：

- 字段严格按照声明的顺序排列
- 字段之间不会存在位填充（即不进行内存对齐）
- Zig 支持任意位宽的整数（通常不足 8 位的仍会占用 8 位），但在 `packed` 结构体中，字段将只占用其声明的位宽。
- `bool` 类型的字段，仅有一位
- 枚举类型只占用其整数标志位的位宽
- 联合类型只占用其最大成员的位宽
- 根据目标平台的字节序，非 ABI 字段会被尽量压缩，以占用尽可能小的 ABI 对齐整数的位宽。

以上特性在使用时有许多值得注意的有趣之处。

1. Zig 允许我们获取字段指针。如果字段存在位偏移，那么该字段的指针将无法直接赋值给普通指针（因为位偏移也是指针对齐信息的一部分）。这种情况可以通过 [`@bitOffsetOf`](https://ziglang.org/documentation/master/#bitOffsetOf) 和 [`@offsetOf`](https://ziglang.org/documentation/master/#offsetOf) 来观察：

:::details 示例

<<<@/code/release/struct.zig#packed_bit_offset

:::

2. 可以使用位转换 [`@bitCast`](https://ziglang.org/documentation/master/#bitCast) 和指针转换 [`@ptrCast`](https://ziglang.org/documentation/master/#ptrCast) 来强制对 `packed` 结构体进行类型转换：

:::details 示例

<<<@/code/release/struct.zig#packed_cast

:::

3. 还可以对 `packed` 结构体的指针设置内存对齐，以访问对应的字段：

:::details 示例

<<<@/code/release/struct.zig#aligned_struct

:::

4. `packed struct` 保证了字段的顺序以及字段间没有额外的填充。然而，结构体本身可能仍然存在额外的填充：

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

由于在 Zig 中许多结构是匿名的（例如一个源文件可以被视为一个匿名结构体），因此 Zig 遵循一套命名规则：

- 如果一个结构体位于变量的初始化表达式中，它将以该变量命名（实际上是声明结构体类型）。
- 如果一个结构体位于 `return` 表达式中，它将以返回的函数命名，并序列化参数。
- 其他情况下，结构体将获得一个类似 `filename.funcname.__struct_ID` 的名称。
- 如果该结构体在另一个结构体中声明，它将以父结构体和前面规则推断出的名称命名，并用点分隔。

上述规则可能有些抽象，下面通过几个示例来演示：

::: code-group

<<<@/code/release/struct.zig#name_principle

```sh [output]
variable: struct_name.main.Foo
anonymous: struct_name.main__struct_3509
function: struct_name.List(i32)
```

:::
