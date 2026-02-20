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

当然，你也可以同时迭代多个目标（数组或切片）。需要注意的是，这些迭代目标的长度必须一致，以避免出现未定义行为。

<<<@/code/release/loop.zig#multi_for

### 作为表达式使用

`for` 循环也可以作为表达式使用，其行为与 [while](#作为表达式使用) 类似。

<<<@/code/release/loop.zig#for_as_expression

### 标记

`continue` 的效果类似于 `goto`，不推荐过度使用，因为它和 `goto` 一样难以控制。在以下示例中，`outer` 是一个标签。

`break` 的效果是在带有标签的循环处执行 `break` 操作。同样，不推荐过度使用。

它们会增加代码的复杂性，非必要不使用。

::: code-group

<<<@/code/release/loop.zig#label_for_1 [break]

<<<@/code/release/loop.zig#label_for_2 [continue]

:::

### 内联 `inline`

`inline` 关键字会将 `for` 循环展开，这使得代码能够执行一些仅在编译时有效的操作。

需要注意的是，内联 `for` 循环要求迭代的值和捕获的值都必须在编译期已知。

:::code-group

<<<@/code/release/loop.zig#inline_for [basic]

<<<@/code/release/loop.zig#inline_for_more [more]

:::

## `while`

`while` 循环用于重复执行代码块，直到某个条件不再满足。

基本使用：

:::code-group

<<<@/code/release/loop.zig#while_basic [basic]

<<<@/code/release/loop.zig#while_more [more]

:::

### `continue` 表达式

`while` 循环的条件之后可以用冒号 `:` 跟一个括号来声明 **`continue` 表达式**，它会在**每轮循环体结束后、下一轮条件判断之前**自动执行：

<<<@/code/release/loop.zig#while_continue_fix

每轮循环的执行顺序是：

1. 检查条件 `i < 10`
2. 执行循环体
3. 执行 `continue` 表达式 `i += 1`
4. 回到第 1 步

相信看到这里，细心的读者可能已经发现了，在上面的 while 基本使用示例中，当循环执行到 `i == 5` 时，**代码会陷入死循环**。

而 `continue` 表达式会帮助我们完美地避开这个问题，不难发现，即使循环执行到 `i == 5` 时，`i` 的自增仍然会在 `continue` 表达式内执行。

:::info 🅿️ 提示
除了 break 以外，return 也会导致 continue 表达式不执行，因为它们都会直接跳出循环。
:::

另外，`continue` 表达式可以是单个语句，也可以是多个语句（用 `{}` 包裹），示例如下：

:::code-group

<<<@/code/release/loop.zig#while_continue_1 [单语句]

<<<@/code/release/loop.zig#while_continue_2 [多语句]

:::

### 作为表达式使用

Zig 还允许我们将 `while` 循环作为表达式使用，此时需要搭配 `else` 和 `break` 语句。

这里的 `else` 分支会在 `while` 循环正常结束（即没有通过 `break` 语句退出）时触发。而 `break` 语句则类似于 `return`，可以在 `while` 循环内部返回值。

<<<@/code/release/loop.zig#while_as_expression

### 标记

`continue` 的效果类似于 `goto`，不推荐过度使用，因为它和 `goto` 一样难以控制。在以下示例中，`outer` 是一个标签。

`break` 的效果是在带有标签的 `while` 循环处执行 `break` 操作。同样，不推荐过度使用。

它们会增加代码的复杂性，非必要不使用。

:::code-group

<<<@/code/release/loop.zig#label_while_continue [continue]

<<<@/code/release/loop.zig#label_while_break [break]

:::

### 内联 `inline`

`inline` 关键字会将 `while` 循环展开，这使得代码能够执行一些仅在编译时有效的操作。

:::code-group

<<<@/code/release/loop.zig#inline_while [basic]

<<<@/code/release/loop.zig#inline_while_more [more]

:::

:::info 🅿️ 提示

建议在以下情况使用内联 `while`：

- 需要在编译期执行循环。
- 你确定展开后代码效率会更高。

:::

### 解构可选类型

与 `if` 类似，`while` 循环也会尝试解构可选类型，并在遇到 `null` 时终止循环。

:::code-group

<<<@/code/release/loop.zig#while_optional [basic]

<<<@/code/release/loop.zig#while_optional_more [more]

:::

当 `|x|` 语法出现在 `while` 表达式中时，`while` 的条件必须是可选类型。

### 解构错误联合类型

与上述类似，`while` 循环也可以解构错误联合类型。`while` 会分别捕获错误和有效负载。当错误发生时，程序会转到 `else` 分支执行，并退出循环：

:::code-group

<<<@/code/release/loop.zig#while_error_union [basic]

<<<@/code/release/loop.zig#while_error_union_more [more]

:::

当 `else |x|` 语法出现在 `while` 表达式中时，`while` 的条件必须是错误联合类型。
