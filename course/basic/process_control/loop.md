---
outline: deep
---

# 循环

<!-- 讲解标签 blocks break -->

在 zig 中，循环分为两种，一种是 `while`，一种是 `for`。

## `for`

for 循环是另一种循环处理方式，主要用于迭代数组和切片。

它支持 `continue` 和 `break`。

迭代数组和切片：

<<<@/code/release/loop.zig#for_array

以上代码中的 value，我们称之为对 数组（切片）迭代的值捕获，注意它是只读的。

在迭代时操作数组（切片）：

<<<@/code/release/loop.zig#for_handle_array

以上代码中的 value 是一个指针，我们称之为对 数组（切片）迭代的指针捕获，注意它也是只读的，不过我们可以通过借引用指针来操作数组（切片）的值。

### 迭代数字

迭代连续的整数很简单，以下是示例：

<<<@/code/release/loop.zig#for_integer

### 迭代索引

如果你想在迭代数组（切片）时，也可以访问索引，可以这样做：

<<<@/code/release/loop.zig#index_for

以上代码中，其中 value 是值，而 i 是索引。

### 多目标迭代

当然，你也可以同时迭代多个目标（数组或者切片），当然这两个迭代的目标要长度一致防止出现未定义的行为。

<<<@/code/release/loop.zig#multi_for

### 作为表达式使用

当然，for 也可以作为表达式来使用，它的行为和 [while](#作为表达式使用) 一模一样。

<<<@/code/release/loop.zig#for_as_expression

### 标记

`continue` 的效果类似于 `goto`，并不推荐使用，因为它和 `goto` 一样难以把控，以下示例中，outer 就是标记。

`break` 的效果就是在标记处的 while 执行 break 操作，当然，同样不推荐使用。

它们只会增加你的代码复杂性，非必要不使用！

::: code-group

<<<@/code/release/loop.zig#label_for_1 [break]

<<<@/code/release/loop.zig#label_for_2 [continue]

:::

### 内联 `inline`

`inline` 关键字会将 for 循环展开，这允许代码执行一些一些仅在编译时有效的操作。

需要注意，内联 for 循环要求迭代的值和捕获的值均是编译期已知的。

:::code-group

<<<@/code/release/loop.zig#inline_for [basic]

<<<@/code/release/loop.zig#inline_for_more [more]

:::

## `while`

while 循环用于重复执行表达式，直到某些条件不再成立。

基本使用：

:::code-group

<<<@/code/release/loop.zig#while_basic [basic]

<<<@/code/release/loop.zig#while_more [more]

:::

### `continue` 表达式

while 还支持一个被称为 continue 表达式的方法来便于我们控制循环，其内部可以是一个语句或者是一个作用域（`{}` 包裹）

:::code-group

<<<@/code/release/loop.zig#while_continue_1 [单语句]

<<<@/code/release/loop.zig#while_continue_2 [多语句]

:::

### 作为表达式使用

zig 还允许我们将 while 作为表达式来使用，此时需要搭配 `else` 和 `break`。

这里的 `else` 是当 while 循环结束并且没有经过 `break` 返回值时触发，而 `break` 则类似于 return，可以在 while 内部返回值。

<<<@/code/release/loop.zig#while_as_expression

### 标记

`continue` 的效果类似于 `goto`，并不推荐使用，因为它和 `goto` 一样难以把控，以下示例中，outer 就是标记。

`break` 的效果就是在标记处的 while 执行 break 操作，当然，同样不推荐使用。

::: info 🅿️ 提示

它们只会增加你的代码复杂性，非必要不使用！

:::

:::code-group

<<<@/code/release/loop.zig#label_while_continue [continue]

<<<@/code/release/loop.zig#label_while_break [break]

:::

### 内联 `inline`

`inline` 关键字会将 while 循环展开，这允许代码执行一些一些仅在编译时有效的操作。

:::code-group

<<<@/code/release/loop.zig#inline_while [basic]

<<<@/code/release/loop.zig#inline_while_more [more]

:::

:::info 🅿️ 提示

建议以下情况使用内联 while：

- 需要在编译期执行循环
- 你确定展开后会代码效率会更高

:::

### 解构可选类型

像 `if` 一样，`while` 也会尝试解构可选类型，并在遇到 `null` 时终止循环。

:::code-group

<<<@/code/release/loop.zig#while_optional [basic]

<<<@/code/release/loop.zig#while_optional_more [more]

:::

当 `|x|` 语法出现在 `while` 表达式上，`while` 条件必须是可选类型。

### 解构错误联合类型

和上面类似，同样可以解构错误联合类型，`while` 分别会捕获错误和有效负载，当错误发生时，转到 `else` 分支执行，并退出：

:::code-group

<<<@/code/release/loop.zig#while_error_union [basic]

<<<@/code/release/loop.zig#while_error_union_more [more]

:::

当 `else |x|` 时语法出现在 `while` 表达式上，`while` 条件必须是错误联合类型。
