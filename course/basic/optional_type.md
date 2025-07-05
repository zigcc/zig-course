---
outline: deep
---

# 可选类型

## Overview

在 Zig 中，为了在不损害效率的前提下提高代码安全性，可选类型是一个重要的解决方案。它的标志是 `?`，`?T` 表示该类型的值可以是 `null` 或 `T` 类型。

<<<@/code/release/optional_type.zig#basic_type

通常，可选类型在指针上发挥作用，而非整数。

`null`（空引用）是许多运行时异常的根源，甚至被指责为[计算机科学中最严重的错误](https://www.lucidchart.com/techblog/2015/08/31/the-worst-mistake-of-computer-science/)。

我们可以通过可选类型来规避空引用问题。这是一种相对保守的做法，它同时兼顾了代码的可读性和运行效率。目前，Rust 在这方面更为激进，这增加了程序员在编写代码时的心智负担（因为你需要经常与编译期“斗智斗勇”，但好处是大大减少了运行时调试的负担）。相对而言，Zig 采取了一种折中方案：在编译期进行简单的检测，且检测出的错误通常很容易纠正。然而，这种方案的缺点是不能保证运行时绝对安全（可选类型仅能避免空指针问题，但不能避免悬空指针、迷途指针和野指针等问题）。

Zig 对 `null` 有特殊处理，并保证 `null` 不会被赋值给一个非可选类型变量。

## 和 C 对比

看看下面代码中 Zig 和 C 在处理 `null` 上的区别。（尝试调用 `malloc` 申请一块内存。）

::: code-group

<<<@/code/release/optional_type.zig#malloc [zig]

```c [c]
// 引用的是 malloc 的原型
void *malloc(size_t size);

struct Foo *do_a_thing(void) {
    char *ptr = malloc(1234);
    if (!ptr) return NULL;
    // ...
}
```

:::

在这里，我们通过使用 `orelse` 解构了可选类型，确保 `ptr` 是一个合法可用的指针；如果 `malloc` 返回 `null`，则直接返回 `null`。（这看起来比 C 更加明了且易用。）

再看下例：

:::code-group

<<<@/code/release/optional_type.zig#check_null [zig]

```c
void do_a_thing(struct Foo *foo) {
    // 干点什么。。。
    if (foo) {
        do_something_with_foo(foo);
    }
    // 干点什么。。。
}
```

:::

看起来区别不大，只是在 `if` 语法上有所不同。`if` 块中保证 `foo` 不为 `null`。

当然，在 C 中，你可以使用 `__attribute__((nonnull))` 来告诉 C 编译器这里不可能为 `null`，但其使用成本明显比 Zig 高。

## 编译期反射访问可选类型

> [!WARNING]
> 该部分内容需要编译期反射的知识，可以选择暂时跳过！

我们也可以通过编译期函数来实现反射，进而访问可选类型：

<<<@/code/release/optional_type.zig#comptime_access_optional_type

## 可选指针

可选指针会保证与普通指针具有相同的大小，`null` 会被视为地址 0。
