---
outline: deep
---

# Switch 语句

`switch` 语句用于进行多分支匹配，并且要求覆盖所有可能的匹配情况。

## 基本使用

:::code-group

<<<@/code/release/switch.zig#basic [default]

<<<@/code/release/switch.zig#basic_more [more]

:::

:::info 🅿️ 提示

`switch` 语句的匹配必须穷尽所有可能的分支，或者包含一个 `else` 分支来处理未匹配的情况！

:::

## 进阶使用

`switch` 还支持使用 `,` 分割的多匹配、`...` 范围选择符、类似循环中的 `tag` 语法以及编译期表达式。以下是演示：

<<<@/code/release/switch.zig#advanced [default]

### 作为表达式使用

在 Zig 中，`switch` 语句还可以作为表达式使用：

::: code-group

<<<@/code/release/switch.zig#expression [default]

<<<@/code/release/switch.zig#expression_more [more]

:::

### 捕获 `Tag Union`

我们还可以使用 `switch` 对标记联合类型进行捕获操作。要修改字段值，可以在捕获变量名称之前放置 `*` 并将其转换为指针：

<<<@/code/release/switch.zig#catch_tag_union

### 匹配和推断枚举

在使用 `switch` 匹配时，也可以继续对枚举类型进行自动推断：

<<<@/code/release/switch.zig#auto_refer

### 内联 `switch`

`switch` 的分支可以标记为 `inline`，以要求编译器生成该分支对应的所有可能情况：

<<<@/code/release/switch.zig#isFieldOptional

`inline else` 可以展开所有的 `else` 分支。这样做的好处是，允许编译器在编译时显式生成所有分支，从而在编译时检查分支是否都能被正确处理：

<<<@/code/release/switch.zig#withSwitch

当使用 `inline else` 捕获 `tag union` 时，可以额外捕获标签（tag）和对应的值（value）：

<<<@/code/release/switch.zig#catch_tag_union_value

### 标签化 `switch`（Labeled Switch）

这是 `0.14.0` 版本引入的新特性。当 `switch` 语句带有标签时，它可以被 `break` 或 `continue` 语句引用。`break` 将从 `switch` 语句返回一个值。

针对 `switch` 的 `continue` 语句必须带有一个操作数。当执行时，它会跳转到匹配的分支，就像用 `continue` 的操作数替换了初始 `switch` 值后重新执行 `switch` 一样。

例如，以下两段代码的写法是等价的：

<<<@/code/release/switch.zig#labeled_switch_1

<<<@/code/release/switch.zig#labeled_switch_2

这可以提高（例如）状态机的清晰度，其中 `continue :sw .next_state` 这样的语法是明确、清晰且易于理解的。

这个设计的目的是处理对数组中每个元素进行 `switch` 判断的情况。在这种情况下，使用单个 `switch` 语句可以提高代码的清晰度和性能：

<<<@/code/release/switch.zig#vm

如果 `continue` 的操作数在编译时就已知，那么它可以被简化为一个无条件分支指令，直接跳转到相关的 `case`。这种分支是完全可预测的，因此通常执行速度很快。

如果操作数在运行时才能确定，每个 `continue` 可以内联嵌入一个条件分支（理想情况下通过跳转表实现），这使得 CPU 可以独立于其他分支来预测其目标。相比之下，基于循环的简化实现会迫使所有分支都通过同一个分发点，这会妨碍分支预测。
