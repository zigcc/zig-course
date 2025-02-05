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
