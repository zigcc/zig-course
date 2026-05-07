---
outline: deep
---

# 指针

> 作为一门底层语言，Zig 自然支持指针。

指针是一个变量，它存储了另一个变量的内存地址。通过指针，我们可以间接访问和操作其指向的内存区域。

**取地址**：通过 `&` 符号来获取某个变量所对应的内存地址，如 `&integer` 就是获取变量 `integer` 的内存地址。

与 C 不同，Zig 将指针分为两种类型：单项指针和多项指针。这种区分主要是为了明确指针指向的是单个元素还是多个元素，从而更安全、高效地使用指针。下图展示了它们指向元素的不同：

![pointer representation](/picture/basic/pointer-representation.svg)

:::info 🅿️ 提示

上图中包含了切片（slice）类型。严格来说，切片不是指针，但它内部包含一个指针（通常被称为“胖指针”），并且在实际编码中更为常用，因此在这里一并列出以便读者比较。

:::

:::warning 关于指针运算

Zig 支持指针的加减运算，但建议在进行运算前，将指针转换为 `[*]T` 类型。

尤其是在处理切片时，不应直接修改切片的内部指针，因为这会破坏切片的内部结构。

:::

## 单项指针

单项指针指向单个元素。

单项指针的类型为 `*T`，其中 `T` 是所指向的数据类型。解引用操作使用 `ptr.*`。

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

多项指针指向一个或多个连续的元素，但其数量在编译期是未知的。

多项指针的类型为 `[*]T`，其中 `T` 是所指向的数据类型，且 `T` 的大小必须是明确的（这意味着它不能是 [`anyopaque`](https://ziglang.org/documentation/master/#toc-C-Type-Primitives) 或其他[不透明类型](https://ziglang.org/documentation/master/#opaque)）。

它支持以下几种操作：

- 索引语法 `ptr[i]`
- 切片语法 `ptr[start..end]` 和 `ptr[start..]`
- 指针运算 `ptr + int`, `ptr - int`
- 指针减法 `ptr - ptr`

<<<@/code/release/pointer.zig#multi_pointer

:::info 🅿️ 提示

数组和切片都与指针有紧密的联系。

`*[N]T`：这是指向一个数组的单项指针，数组的长度为 N。也可以理解为指向一个包含 N 个元素数组的指针。

支持这些语法：

- 索引语法：`array_ptr[i]`
- 切片语法：`array_ptr[start..end]`
- `len` 属性：`array_ptr.len`
- 指针减法：`array_ptr - array_ptr`

`[]T`：这是切片。它是一个“胖指针”，内部包含一个 `[*]T` 类型的指针和一个长度值。

支持这些语法：

- 索引语法：`slice[i]`
- 切片语法：`slice[start..end]`
- `len` 属性：`slice.len`

数组指针的类型本身就包含了长度信息，而切片则在运行时存储其长度。数组指针和切片的长度都可以通过 `len` 属性来获取。

:::details 示例

<<<@/code/release/pointer.zig#array_and_slice

:::

### 哨兵指针（标记终止指针）

:::info

其本质是为了兼容 C 语言中以 `\0` 作为结尾的字符串。

:::

哨兵指针与哨兵数组类似。我们使用 `[*:x]T` 语法来定义哨兵指针。这种指针通过一个特定的“哨兵”值来标记其边界。

其长度由哨兵值 `x` 的位置决定，这样做的好处是提供了针对缓冲区溢出和过度读取的保护。

:::details 示例

我们接下来演示一个示例。该示例利用了 Zig 与 C 无缝交互的特性，因此，如果你对 C 交互不熟悉，可以暂时跳过。

<<<@/code/release/pointer.zig#st_pointer

以上代码编译需要额外链接 `libc`。在 Zig 0.16 的构建脚本中，可以让对应模块链接 C 标准库，例如 `exe.root_module.linkSystemLibrary("c", .{})`。

:::

## 多项指针和单项指针区别

本节专门解释单项指针和多项指针的区别。

先列出以下类型：

- `[4] const u8`

该类型代表一个长度为 4 的数组，数组内的元素类型为 `const u8`。

- `[] const u8`

该类型代表一个切片，切片内元素类型为 `const u8`。

- `*[4] const u8`

该类型代表一个指针，它指向一个内存地址，该地址存储着一个长度为 4 的数组，数组内的元素类型为 `const u8`。

- `*[] const u8`

该类型代表一个指针，它指向一个内存地址，该地址存储着一个切片。

- `[*] const u8`

该类型代表一个指向内存地址的指针，该地址存储了一个或多个 `const u8` 类型的元素，但其数量是未知的。

其中 `[*] const u8` 可以看作是 C 中的 `*const char`。这类似于 C 语言中的 `const char*`，因为在 C 中，一个普通指针既可以指向单个字符，也可以指向一个字符数组。Zig 则通过 `[*]T` 这种专门的语法来明确表示指向多个元素的情况，避免了歧义。

## 指针和整数互转

[`@ptrFromInt`](https://ziglang.org/documentation/master/#ptrFromInt) 可以将一个整数值当作内存地址来创建一个指针，而 [`@intFromPtr`](https://ziglang.org/documentation/master/#intFromPtr) 可以将指针转换为整数：

<<<@/code/release/pointer.zig#ptr2int

## 指针强制转换

内置函数 [`@ptrCast`](https://ziglang.org/documentation/master/#ptrCast) 可以将一个指针的类型强制转换为另一个指针类型，即改变指针所指向的数据类型。

一般情况下，应当尽量避免使用 `@ptrCast`。这会创建一个新的指针，通过它进行的加载和存储操作可能会导致难以检测的非法行为。

<<<@/code/release/pointer.zig#ptr_cast

## 额外特性

以下是指针的一些额外特性。初学者可以暂时跳过这些内容，在需要时再来学习。

### `volatile`

> 如果你不知道指针操作的“副作用”是什么，可以暂时跳过本节，在需要时再来查看。

对指针的操作通常被假定为没有副作用。但如果存在副作用，例如在使用内存映射输入输出（Memory Mapped Input/Output）时，就需要使用 `volatile` 关键字来修饰指针。

在以下代码中，`volatile` 确保了对 `mmio_ptr` 的每次访问都会直接读写内存，而不是从缓存中读取。当与硬件交互时，编译器可能会将值缓存在寄存器中，而 `volatile` 则强制每次都从内存中读取，以确保“副作用”能够正确触发，并保证了代码的执行顺序。

<<<@/code/release/pointer.zig#volatile

本节仅简要介绍，如果要了解更多，你可能需要查看[官方文档](https://ziglang.org/documentation/master/#toc-volatile)。

### 对齐

> 如果你不知道内存对齐的含义，可以暂时跳过本节，在需要时再来查看。

每种类型都有一个对齐方式，即一个字节数。当从内存中加载或存储该类型的值时，其内存地址必须是该字节数的整数倍。我们可以使用 `@alignOf` 来获取任何类型的内存对齐大小。

内存对齐大小取决于 CPU 架构，但始终是 2 的幂，并且小于 `1 << 29`。

:::info

`align(0)` 表示无需对齐，这在高性能、内存紧迫的场景下非常有用。
参考：[allow align(0) on struct fields](https://github.com/ziglang/zig/issues/3802)

:::

在 Zig 中，指针类型也具有对齐值。如果该值等于其基础类型的对齐方式，则可以从类型声明中省略它：

<<<@/code/release/pointer.zig#align

:::info 🅿️ 提示

和 `*i32` 类型可以隐式转换为 `*const i32` 类型类似，具有更严格（更大）对齐要求的指针可以隐式转换为对齐要求更宽松（更小）的指针，但反之则不行。

如果有一个指针或切片的对齐方式较小，但我们确定它实际上满足更严格的对齐要求，可以使用 `@alignCast` 将其转换成具有更严格对齐的指针类型，例如：`@as([]align(4) u8, @alignCast(slice4))`。这个转换在运行时没有开销，但会插入一个安全检查。

:::details 示例

<<<@/code/release/pointer.zig#align_cast

:::

如果有一个指针或切片，它的对齐要求很宽松，但我们知道它实际上有一个更严格的对齐方式，那么可以使用 [`@alignCast`](https://ziglang.org/documentation/master/#alignCast) 来获得一个对齐要求更严格的指针。这在运行时没有开销，但会额外加入一个[安全检查](https://ziglang.org/documentation/master/#Incorrect-Pointer-Alignment)：

> 例如，以下代码是错误的，不会被正常执行：

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

将零地址转换为指针通常是未定义行为（[Pointer Cast Invalid Null](https://ziglang.org/documentation/master/#Pointer-Cast-Invalid-Null)），但如果我们为指针类型添加 `allowzero` 修饰符，那么值为零的指针就成为合法的了。

:::warning 关于零指针的使用

请只在目标 OS 为 `freestanding` 时使用零指针。如果想表示 `null` 指针，请使用[可选类型](/basic/optional_type)。

:::

<<<@/code/release/pointer.zig#zero_pointer

### 编译期

只要代码不依赖于运行时才确定的内存布局，指针也可以在编译期使用。

<<<@/code/release/pointer.zig#comptime_pointer

只要指针从未被解引用，Zig 就能在 `comptime` 代码中保留其内存地址：

<<<@/code/release/pointer.zig#comp_pointer
