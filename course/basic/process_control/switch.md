---
outline: deep
---

# Switch

switch 语句可以进行匹配，并且 switch 匹配不能出现遗漏匹配的情况。

## 基本使用

:::code-group

<<<@/code/release/switch.zig#basic [default]

<<<@/code/release/switch.zig#basic_more [more]

:::

:::info 🅿️ 提示

switch 的匹配必须要穷尽所有，或者具有 `else` 分支！

:::

## 进阶使用

switch 还支持用 `,` 分割的多匹配、`...` 的范围选择符，类似循环中的 `tag` 语法、编译期表达式，以下是演示：

<<<@/code/release/switch.zig#advanced [default]

### 作为表达式使用

在 zig 中，还可以将 `switch` 作为表达式来使用：

::: code-group

<<<@/code/release/switch.zig#expression [default]

<<<@/code/release/switch.zig#expression_more [more]

:::

### 捕获 `Tag Union`

我们还可以使用 switch 对标记联合类型进行捕获操作，对字段值的修改可以通过在捕获变量名称之前放置 `*` 并将其转换为指针来完成：

<<<@/code/release/switch.zig#catch_tag_union

### 匹配和推断枚举

在使用 switch 匹配时，也可以继续对枚举类型进行自动推断：

<<<@/code/release/switch.zig#auto_refer

### 内联 switch

switch 的分支可以标记为 `inline` 来要求编译器生成该分支对应的所有可能分支：

<<<@/code/release/switch.zig#isFieldOptional

`inline else` 可以展开所有的 else 分支，这样做的好处是，允许编译器在编译时显式生成所有分支，这样在编译时可以检查分支是否均能被正确地处理：

<<<@/code/release/switch.zig#withSwitch

当使用 `inline else` 捕获 tag union 时，可以额外捕获 tag 和对应的 value：

<<<@/code/release/switch.zig#catch_tag_union_value

### labeled switch

这是 `0.14.0` 引入的新特性，当 `switch` 语句带有标签时，它可以被 `break` 或 `continue` 语句引用。`break` 将从 `switch` 语句返回一个值。

针对 `switch` 的 `continue` 语句必须带有一个操作数。当执行时，它会跳转到匹配的分支，就像用 `continue` 的操作数替换了初始 `switch` 值后重新执行 `switch` 一样。

例如以下两段代码的写法是一样的：

<<<@/code/release/switch.zig#labeled_switch_1

<<<@/code/release/switch.zig#labeled_switch_2

这可以提高（例如）状态机的清晰度，其中 `continue :sw .next_state` 这样的语法是明确的、清楚的，并且可以立即理解。

不过，这个设计的目的是处理对数组中每个元素进行 `switch` 判断的情况，在这种情况下，使用单个 `switch` 语句可以提高代码的清晰度和性能：

<<<@/code/release/switch.zig#vm

如果 `continue` 的操作数在编译时就已知，那么它可以被简化为一个无条件分支指令，直接跳转到相关的 `case`。这种分支是完全可预测的，因此通常执行速度很快。

如果操作数在运行时才能确定，每个 `continue` 可以内联嵌入一个条件分支（理想情况下通过跳转表实现），这使得 CPU 可以独立于其他分支来预测其目标。相比之下，基于循环的简化实现会迫使所有分支都通过同一个分发点，这会妨碍分支预测。
