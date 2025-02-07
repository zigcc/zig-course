---
outline: deep
---

# 可选类型

## Overview

在 Zig 中，要在不损害效率的前提下，尽量提高代码安全性，其中一个方案就是可选类型，他的标志是 `?`，`?T`表示它的值是它的值是 `null` 或`T`。

<<<@/code/release/optional_type.zig#basic_type

当然，它一般在指针上发挥作用，而不是整数。

`null`（空引用）是许多运行时异常的根源，甚至被指责为[计算机科学中最严重的错误](https://www.lucidchart.com/techblog/2015/08/31/the-worst-mistake-of-computer-science/)。

我们可以通过可选类型来规避它。这其实是一种比较保守的做法，它同时兼顾了代码的可读性和运行效率。目前最为激进的应该是 _Rust_，它真的是非常的激进，这增加了程序员在写代码时的心智负担（因为你经常需要和编译期斗智斗勇，但好处大大是减少了你在运行时 _Debug_ 的负担）。相对地，zig 采取了一种折中方案，编译期进行简单的检测，而且检测出来的错误一般很容易纠正；这样的缺点是并不能保证你的运行时是绝对安全的（可选类型仅仅能避免空指针问题，却不能避免悬空指针、迷途指针和野指针等问题）。

zig 将 `null` 特殊看待，并且保证 `null` 不会被赋值给一个非可选类型变量。

## 和 C 对比

看看下面代码中两者在处理 `null` 上的区别。（尝试调用 `malloc` 申请一块内存。）

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

在这里，我们通过使用 `orelse` 解构了可选类型，保证 `ptr` 是一个合法可用的指针，否则直接返回 `null`。（这看起来比 C 更加明了且易用）

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

看起来区别不大，只是在 `if` 语法上有点不同，`if` 块中保证 `foo` 不为 `null`。

当然，在 C 中，你可以用 `__attribute__((nonnull))` 来告诉 C 编译器这里不不可能是 `null`，但其使用成本明显比 Zig 高。

## 编译期反射访问可选类型

> [!WARNING]
> 该部分内容需要编译期反射的知识，可以选择暂时跳过！

我们也可以通过编译期函数来实现反射进而访问可选类型：

<<<@/code/release/optional_type.zig#comptime_access_optional_type

## 可选指针

可选指针会保证和指针有一样的大小，`null` 会被视作地址 0 考虑！
