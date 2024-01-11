---
outline: deep
---

# 可选类型

zig 在不损害效率和可读性的前提下提高代码安全性的一个方案就是可选类型，`?` 是可选类型的标志，你可以将它放在类型的前面，代表它的值是null或者这个类型。

```zig
// 一个普通的i32整数
const normal_int: i32 = 1234;

// i32的可选类型，现在它的值可以是 i32 或者 null
const optional_int: ?i32 = 5678;
```

当然，可选类型在整数上没什么大用，更多是在指针上使用，null（空引用）是许多运行时异常的根源，甚至被指责为[计算机科学中最严重的错误](https://www.lucidchart.com/techblog/2015/08/31/the-worst-mistake-of-computer-science/)。

当然这在 zig 中不存在，通过可选类型我们可以解决这个问题，zig 在解决空指针上采取的方式比较保守，它兼顾了代码的可读性和效率问题。

其中目前最为激进的应该是 Rust ，它真的是非常的激进，这增加了程序员在写代码时的心智负担（因为你经常需要和编译期斗智斗勇，但好处大大是减少了你在运行时 debug 的负担）。相对来说，zig 采取的是一种折中的方案，编译期仍然会给你检测，并且这种检测不是很深奥，而且纠正起来很简单，缺点是并不能保证你的运行时是绝对安全的（可选类型仅仅能保证你不使用空指针，却不能保证你出现悬空指针【迷途指针、野指针】等情况的出现）。

zig 会将 null 特殊看待，并且保证你不会将一个可能为 null 的值赋值给一个不能是 null 的变量。

首先我们和 zig 的目标：C 对比一下，看一下两者在处理 null 上的区别，在接下来的代码中，我们尝试调用 `malloc`，并且申请一块内存：

::: code-group

```c [c]
// 引用的是malloc的原型
void *malloc(size_t size);

struct Foo *do_a_thing(void) {
    char *ptr = malloc(1234);
    if (!ptr) return NULL;
    // ...
}
```

```zig [zig]
extern fn malloc(size: usize) ?*u8;

fn doAThing() ?*Foo {
    const ptr = malloc(1234) orelse return null;
    _ = ptr; // ...
}
```

:::

在这里，至少zig 看起来要比 c 好用，我们通过使用 `orelse` 关键字保证解构了可选类型，保证我们这里的 `ptr` 一定是一个可用的指针，否则的话我们直接会返回 `null`。

在 c 中，检查 `null` 你大概是这样处理的：

```c
void do_a_thing(struct Foo *foo) {
    // do some stuff

    if (foo) {
        do_something_with_foo(foo);
    }

    // do some stuff
}
```

而在 zig 中，我们可以这样处理：

```zig
const Foo = struct{};
fn doSomethingWithFoo(foo: *Foo) void { _ = foo; }

fn doAThing(optional_foo: ?*Foo) void {
    // do some stuff

    if (optional_foo) |foo| {
      doSomethingWithFoo(foo);
    }

    // do some stuff
}
```

嗯。。。看起来可能没什么不同，不过在 zig 的这个块中保证了 `foo` 不是一个可选类型的指针，而是一个指针。

当然在 c 中你可以使用 `__attribute__((nonnull))` 来告诉 GCC 编译器这里不能是一个 null 。

## 编译期反射访问可选类型

我们也可以通过编译期函数来实现反射进而访问可选类型：

```zig
const expect = @import("std").testing.expect;

test "optional type" {
    // 定义一个可选类型并且赋值为null:
    var foo: ?i32 = null;

    // 赋值1234
    foo = 1234;

    try comptime expect(@typeInfo(@TypeOf(foo)).Optional.child == i32);
}
```

## 可选指针

可选指针会保证和指针有一样的大小，`null` 会被视作地址 0 考虑！
