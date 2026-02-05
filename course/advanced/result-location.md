---
outline: deep
---

# 结果位置语义

> Result Location Semantics 是 Zig 类型系统的核心机制之一，它允许编译器根据上下文自动推断类型。

在 Zig 中，许多表达式的类型不是由表达式本身决定的，而是由表达式的**使用方式**决定的。这种机制被称为**结果位置语义（Result Location Semantics）**。

## 什么是结果位置语义

结果位置语义是指编译器根据表达式结果的**存储位置**（即"结果位置"）来推断表达式类型的机制。

简单来说，当你写 `.{ .x = 1, .y = 2 }` 这样的表达式时，编译器会查看这个值将被赋给什么类型的变量，然后自动推断出正确的类型。

<<<@/code/release/result-location.zig#basic_inference

## 结果类型

**结果类型（Result Type）** 是编译器期望表达式产生的类型。它由表达式的上下文决定：

### 变量声明

当变量有显式类型声明时，右侧表达式的结果类型就是该变量的类型：

<<<@/code/release/result-location.zig#result_type_variable

### 函数返回值

函数的返回类型决定了 `return` 表达式的结果类型：

<<<@/code/release/result-location.zig#result_type_return

### 函数参数

函数参数类型决定了调用时传入表达式的结果类型：

<<<@/code/release/result-location.zig#result_type_param

### 结构体字段默认值

结构体字段的类型决定了默认值表达式的结果类型：

<<<@/code/release/result-location.zig#result_type_field_default

## 结果位置

**结果位置（Result Location）** 是指表达式结果将被存储的内存位置。Zig 编译器会将结果位置的信息传递给子表达式，这使得某些优化成为可能。

### 嵌套结构的结果位置传播

结果位置信息会传播到嵌套的子表达式：

<<<@/code/release/result-location.zig#result_location_nested

## 声明字面量

**声明字面量（Decl Literals）** 是 Zig 0.14.0 引入的语法特性。它扩展了枚举字面量语法 `.foo`，使其不仅可以引用枚举成员，还可以引用目标类型上的任何声明。

### 基本用法

<<<@/code/release/result-location.zig#decl_literal_basic

由于 `val` 的类型是 `S`，编译器知道 `.default` 应该在 `S` 的命名空间中查找，因此 `.default` 等价于 `S.default`。

### 在结构体字段默认值中使用

声明字面量在设置字段默认值时特别有用：

<<<@/code/release/result-location.zig#decl_literal_field_default

### 调用函数

声明字面量也支持调用函数：

<<<@/code/release/result-location.zig#decl_literal_function

### 与错误联合类型配合

声明字面量支持通过 `try` 调用返回错误联合的函数：

<<<@/code/release/result-location.zig#decl_literal_error_union

## 避免错误的字段默认值

声明字面量的一个重要应用是避免**错误的字段默认值（Faulty Default Field Values）**问题。

### 问题示例

考虑以下代码：

<<<@/code/release/result-location.zig#faulty_default_problem

这里的问题是 `ptr` 和 `len` 是相互关联的，但默认值允许用户只覆盖其中一个，导致数据不一致。

### 使用声明字面量的解决方案

<<<@/code/release/result-location.zig#faulty_default_solution

## 标准库中的应用

从 Zig 0.14.0 开始，标准库中的许多类型都采用了声明字面量模式。

### ArrayListUnmanaged

<<<@/code/release/result-location.zig#stdlib_arraylist

### GeneralPurposeAllocator

<<<@/code/release/result-location.zig#stdlib_gpa

## 字段和声明不可重名

Zig 0.14.0 引入了一项限制：容器类型（`struct`、`union`、`enum`、`opaque`）的字段和声明不能同名。

<<<@/code/release/result-location.zig#naming_conflict

这个限制是为了消除 `MyType.foo` 到底是访问字段还是声明的歧义。
