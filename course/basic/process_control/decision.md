---
outline: deep
---

# 条件

> 在 zig 中，`if` 这个语法的作用可就大了！

像基础的 `if`，`if else`，`else if` 我们就不说了，直接看例子：

::: code-group

<<<@/code/release/decision.zig#default_if [default]

<<<@/code/release/decision.zig#more_if [more]

:::

## 匹配枚举类型

`if` 可以用于枚举类型的匹配，判断是否相等：

::: code-group

<<<@/code/release/decision.zig#default_match_enum [default]

<<<@/code/release/decision.zig#more_match_enum [more]

:::

## 三元表达式

zig 中的三元表达式是通过 `if else` 来实现的：

::: code-group

<<<@/code/release/decision.zig#default_ternary [default]

<<<@/code/release/decision.zig#more_ternary [more]

:::

## 高级用法

以下内容涉及到了[联合类型](/basic/union)和[可选类型](/basic/optional_type)，你可以在阅读完这两章节后再回来学习。

### 解构可选类型

事实上，解构可选类型操作很简单：

<<<@/code/release/decision.zig#destruct_optional

以上代码的 `else` 分支并非必要，我们解构后获得 `real_b` 就是 `u32` 类型，但是注意我们获得的捕获是只读的！

如果我们想操纵值的内容，可以选择捕获对应的指针：

<<<@/code/release/decision.zig#capture_optional_pointer

`*` 运算符就表示我们选择捕获这个值对应的指针，因此我们可以通过操控指针来修改其值。

### 解构错误联合类型

解构错误联合类型类似于解构可选类型：

<<<@/code/release/decision.zig#destruct_error_union

以上代码中 `value` 类型为 `u32`，else 分支捕获的是错误，即 `err` 的类型将会是 `anyerror`，这是由我们之前显式声明的，否则将会是由编译器推导的。

为了仅检测错误，我们可以这样做：

<<<@/code/release/decision.zig#only_catch_error

同样支持捕获指针来操作值：

<<<@/code/release/decision.zig#catch_pointer

::: warning

那么 if 是如何解构 **错误联合可选类型** 的呢？

答案是 if 会先尝试解构**错误联合类型**，再解构**可选类型**：

<<<@/code/release/decision.zig#destruct_error_optional_union

以上代码中的 `optional_value` 就是可选类型 `?u32`，我们可以在内部继续使用 if 来解构它。

在错误联合可选类型上也可以使用指针捕获：

<<<@/code/release/decision.zig#destruct_error_optional_union_pointer

以上代码中，`*optional_value` 捕获的是可选类型的指针，我们在内部尝试解引用后再一次捕获指针来进行操作。

:::
