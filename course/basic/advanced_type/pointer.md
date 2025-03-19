---
outline: deep
---

# 指针

> zig 作为一门 low level 语言，那肯定要有指针的。

指针是指向一块内存区域地址的变量，它存储了一个地址，我们可以通过指针来操作其指向内存区域。

**取地址**：通过 `&` 符号来获取某个变量所对应的内存地址，如 `&integer` 就是获取变量 `integer` 的内存地址。

与 C 不同，Zig 中的指针类型要分为两种（一种是单项指针，一种是多项指针），它们主要是对指向的元素做了区分，便于更好地使用。下图展示了它们指向元素的不同：

![pointer representation](/picture/basic/pointer-representation.svg)

:::info 🅿️ 提示

上图中包含了切片（slice）类型，严格来说它不是指针，但其是由指针构成的（一般称为胖指针），而且在代码中用的更为普遍，因此列在一起便于读者比较。

:::

:::warning 关于指针运算

zig 本身支持指针运算（加减操作），但有一点需要注意：最好将指针分配给 `[*]T` 类型后再进行计算。

尤其是在切片中，不可直接对其指针进行更改，这会破坏切片的内部结构！

:::

## 单项指针

单项指针指向单个元素。

单项指针的类型为：`*T`，`T`是所指向内存区域的类型，解引用方法是 `ptr.*`。

<<<@/code/release/pointer.zig#single_pointer

单项指针本身支持以下操作：

- 解引用语法 `ptr.*`
- 切片语法 `ptr[0..1]`
- 指针减法 `ptr - ptr`

:::info 🅿️ 提示

函数指针略有特殊：

<<<@/code/release/pointer.zig#fn_pointer

:::

## 多项指针

多项指针指向未知数量的多个元素。

多项指针的类型为：`[*]T`，`T`是所指向内存区域的类型，且该类型必须具有明确的大小（这意味着它不能是 [`anyopaque`](https://ziglang.org/documentation/master/#toc-C-Type-Primitives) 和其他任意[不透明类型](https://ziglang.org/documentation/master/#opaque)）。

解引用方法支持以下几种：

- 索引语法 `ptr[i]`
- 切片语法 `ptr[start..end]` 和 `ptr[start..]`
- 指针运算 `ptr + int`, `ptr - int`
- 指针减法 `ptr - ptr`

<<<@/code/release/pointer.zig#multi_pointer

:::info 🅿️ 提示

数组和切片都与指针有紧密的联系。

`*[N]T`：这是指向一个数组的单项指针，数组的长度为 N。也可以将其理解为指向 N 个元素的指针。

支持这些语法：

- 索引语法：`array_ptr[i]`
- 切片语法：`array_ptr[start..end]`
- `len` 属性：`array_ptr.len`
- 指针减法：`array_ptr - array_ptr`

`[]T`：这是切片，相当于一个胖指针，包含了一个类型为 `[*]T` 的指针和一个长度。

支持这些语法：

- 索引语法：`slice[i]`
- 切片语法：`slice[start..end]`
- `len` 属性：`slice.len`
  数组指针的类型中就包含了长度信息，而切片中则实际存储着长度。数组指针和切片的长度都可以通过 `len` 属性来获取。

:::details 示例

<<<@/code/release/pointer.zig#array_and_slice

:::

### 哨兵指针（标记终止指针）

:::info

本质上来说，这是为了兼容 C 中的规定的字符串结尾字符`\0`

:::

哨兵指针就和哨兵数组类似，我们使用语法 `[*:x]T`，这个指针标记了边界的值，故称为“哨兵”。

它的长度有标记值 `x` 来确定，这样做的好处就是提供了针对缓冲区溢出和过度读取的保护。

:::details 示例

我们接下来演示一个示例，该示例中使用了 zig 可以无缝与 C 交互的特性，故你可以暂时略过这里！

<<<@/code/release/pointer.zig#st_pointer

以上代码编译需要额外连接 libc，你只需要在你的 `build.zig` 中添加 `exe.linkLibC();` 即可。

:::

## 多项指针和单向指针区别

本部分专门用于解释并区别单向指针和多项指针！

先列出以下类型：

- `[4] const u8`

该类型代表的是一个长度为 4 的数组，数组内的元素类型为 `const u8`。

- `[] const u8`

该类型代表的是一个切片，切片内元素类型为 `const u8`。

- `*[4] const u8`

该类型代表的是一个指针，它指向一个内存地址，内存中该地址存储着一个长度为 4 的数组，数组内的元素类型为 `const u8`。

- `*[] const u8`

该类型代表的是一个指针，它指向一个内存地址，内存中该地址存储着一个切片。

- `[*] const u8`

该类型代表的是一个指针，它指向一个内存地址，内存中该地址存储着一个数组，但长度未知！！

其中 `[*] const u8` 可以看作是 C 中的 `* const char`，这是因为在 C 语言中一个普通的指针也可以指向一个数组，zig 仅仅是单独把这种令人迷惑的行为单独作为一个语法而已！

## 指针和整数互转

[`@ptrFromInt`](https://ziglang.org/documentation/master/#ptrFromInt) 可以将整数地址转换为指针，[`@intFromPtr`](https://ziglang.org/documentation/master/#intFromPtr) 可以将指针转换为整数：

<<<@/code/release/pointer.zig#ptr2int

## 指针强制转换

内置函数 [`@ptrCast`](https://ziglang.org/documentation/master/#ptrCast) 可以将将指针的元素类型转换为另一种类型，也就是不同类型的指针强制转换。

一般情况下，应当尽量避免使用 `@ptrCast`，这会创建一个新的指针，根据通过它的加载和存储操作，可能导致无法检测的非法行为。

<<<@/code/release/pointer.zig#ptr_cast

## 额外特性

以下的是指针的额外特性，初学者可以直接略过以下部分，等到你需要时再来学习即可！

### `volatile`

> 如果不知道什么是指针操作的“_副作用_”，那么这里你可以略过，等你需要时再来查看！

对指针的操作应假定为没有副作用。如果存在副作用，例如使用内存映射输入输出（Memory Mapped Input/Output），则需要使用 `volatile` 关键字来修饰。

在以下代码中，保证使用 `mmio_ptr` 的值进行操作（这里你看起来可能会感到迷惑，在编译代码时，编译器可以能会让值在实际运行过程中进行缓存，这里保证每次都使用 `mmio_ptr` 的值，以确保正确触发“副作用”），并保证了代码执行的顺序。

<<<@/code/release/pointer.zig#volatile

该节内容，此处仅仅讲述了少量内容，如果要了解更多，你可能需要查看[官方文档](https://ziglang.org/documentation/master/#toc-volatile)！

### 对齐

> 如果你不知道内存对齐的含义是什么，那么本节内容你可以跳过了，等到你需要时再来查看！

每种类型都有一个对齐方式——也就是数个字节，这样，当从内存加载或存储该类型的值时，内存地址必须能被该数字整除。我们可以使用 `@alignOf` 找出任何类型的内存对齐大小。

内存对齐大小取决于 CPU 架构，但始终是 2 的幂，并且小于 1 << 29。
:::info

`align(0)` 表意是：无需对齐，这在高性能、内存紧迫场景下用处很大。
参考：[allow align(0) on struct fields](https://github.com/ziglang/zig/issues/3802)

:::

在 Zig 中，指针类型具有对齐值。如果该值等于基础类型的对齐方式，则可以从类型中省略它：

<<<@/code/release/pointer.zig#align

:::info 🅿️ 提示

和 `*i32` 类型可以强制转换为 `*const i32` 类型类似，具有较大对齐大小的指针可以隐式转换为具有较小对齐大小的指针，但反之则不然。

如果有一个指针或切片的对齐方式较小，但知道它实际上具有较大的对齐方式，请使用 `@alignCast` 将指针更改为更对齐的指针，例如：`@as([]align(4) u8, @alignCast(slice4))`，这在运行时无操作，但插入了安全检查。

:::details 示例

<<<@/code/release/pointer.zig#align_cast

:::

如果有一个指针或切片，它的对齐很小，但我们知道它实际上有一个更大的对齐，那么使用 [`@alignCast`](https://ziglang.org/documentation/master/#alignCast) 让其 `align` 更大。在运行时是无操作的，但会额外加入一个 [安全检查](https://ziglang.org/documentation/master/#Incorrect-Pointer-Alignment)：

> 例如这段代码就是错误的，不会被正常执行

```zig
const std = @import("std");

test "pointer alignment safety" {
    var array align(4) = [_]u32{ 0x11111111, 0x11111111 };
    const bytes = std.mem.sliceAsBytes(array[0..]);
    try std.testing.expect(foo(bytes) == 0x11111111);
}
fn foo(bytes: []u8) u32 {
    const slice4 = bytes[1..5];
    const int_slice = std.mem.bytesAsSlice(u32, @as([]align(4) u8, @alignCast(slice4)));
    return int_slice[0];
}
```

```sh
$ zig test test_incorrect_pointer_alignment.zig
1/1 test_incorrect_pointer_alignment.test.pointer alignment safety...thread 958173 panic: incorrect alignment
/home/ci/actions-runner/_work/zig-bootstrap/zig/doc/langref/test_incorrect_pointer_alignment.zig:10:68: 0x1048962 in foo (test)
    const int_slice = std.mem.bytesAsSlice(u32, @as([]align(4) u8, @alignCast(slice4)));
                                                                   ^
/home/ci/actions-runner/_work/zig-bootstrap/zig/doc/langref/test_incorrect_pointer_alignment.zig:6:31: 0x104880f in test.pointer alignment safety (test)
    try std.testing.expect(foo(bytes) == 0x11111111);
                              ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/compiler/test_runner.zig:214:25: 0x10efab9 in mainTerminal (test)
        if (test_fn.func()) |_| {
                        ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/compiler/test_runner.zig:62:28: 0x10e7ead in main (test)
        return mainTerminal();
                           ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:647:22: 0x10e7430 in posixCallMainAndExit (test)
            root.main();
                     ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:271:5: 0x10e6ffd in _start (test)
    asm volatile (switch (native_arch) {
    ^
???:?:?: 0x0 in ??? (???)
error: the following test command crashed:
/home/ci/actions-runner/_work/zig-bootstrap/out/zig-local-cache/o/608e4a8451ecb0974638281c85927599/test --seed=0x9bc870fd
```

### 零指针

零指针实际上是一个未定义的错误行为（[Pointer Cast Invalid Null](https://ziglang.org/documentation/master/#Pointer-Cast-Invalid-Null)），但是当我们给指针增加上 `allowzero` 修饰符后，它就变成合法的行为了！

:::warning 关于零指针的使用

请只在目标 OS 为 `freestanding` 时使用零指针，如果想表示 `null` 指针，请使用[可选类型](/basic/optional_type)！

:::

<<<@/code/release/pointer.zig#zero_pointer

### 编译期

只要代码不依赖于未定义的内存布局，那么指针也可以在编译期发挥作用！

<<<@/code/release/pointer.zig#comptime_pointer

只要指针从未被取消引用，Zig 就能够保留 `comptime` 代码中的内存地址：

<<<@/code/release/pointer.zig#comp_pointer
