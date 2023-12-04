---
outline: deep
---

# 杂项

本部分是关于 zig 一些额外知识的补充，暂时还没有决定好分类到何处！

## 为什么 zig 可以做到比 c 更好的编译

实际上，zig 本身实现了一个 C 的编译器，当然不仅仅如此，zig 还提供了一个比较 **_magic_** 的东西—— [`glibc-abi-tool`](https://github.com/ziglang/glibc-abi-tool)，这是一个收集每个版本的 glibc 的 `.abilist` 文件的存储库，还包含一个将它们组合成一个数据集的工具。

所以，zig 本身所谓的 “**_ships with libc_**” 并不准确，它的确分发 libc，但它只携带每个版本的符号库，仅依赖这个符号库，zig 就可以实现在没有 libc 的情况下仍然正确地进行动态链接！

::: info 🅿️ 提示

由于这种特性，这导致 zig 尽管携带了 40 个 libc，却仍然能保持 45MB（linux-x86-64）左右的大小，作为对比 llvm 分发的 clang 完整的工具链的大小多达好几百 M。

关于更多的细节，你可以参考以下链接：

- [process_headers tool](https://github.com/ziglang/zig/blob/0.4.0/libc/process_headers.zig)
- [Updating libc](https://github.com/ziglang/zig/wiki/Updating-libc)
- [hacker news](https://news.ycombinator.com/item?id=29538264)

:::

## zig 能静态链接 libc 吗？

能，又不能！

zig 支持静态链接 musl（针对linux的另一个 libc，目标为嵌入式系统与移动设备），其他仅支持动态链接。受益于这种特性，我们可以将它作为 C 编译器的替代品使用，它可以提供更加完善的工具链。

举个比较*剑走偏锋*的例子，go 的 cgo 特性一直为人们所吐槽，一旦使用了它，基本就要和 go 宣称的非常方便的交叉编译说拜拜了，但我们可以使用 zig 来帮助我们实现 cgo 的交叉编译：

```sh
CC='zig cc -target x86_64-linux-gnu' CXX='zig cc -target x86_64-linux-gnu' go build
```

设置 zig 作为 C 编译器来供 go 使用，只要对 zig 和 go 设置正确的target，就可以在本机实现完善的交叉编译。

再进一步，我们还可以构建出 linux 的使用 cgo 的静态链接的二进制可执行文件：

```sh
CC='zig cc -target x86_64-linux-musl' CXX='zig cc -target x86_64-linux-musl' CGO_CFLAGS='-D_LARGEFILE64_SOURCE' go build -ldflags='-linkmode=external -extldflags -static'
```

上方的 `CGO_CFLAGS` 是为了防止编译失败，`ldfalgs` 是为了指定静态链接！
