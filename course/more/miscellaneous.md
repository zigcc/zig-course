---
outline: deep
---

# 杂项

本部分是关于 zig 一些额外知识的补充，暂时还没有决定好分类到何处！

## 容器

在 Zig 中，**容器** 是充当保存变量和函数声明的命名空间的任何语法结构。容器也是可以实例化的类型定义。结构体、枚举、联合、不透明，甚至 Zig 源文件本身都是容器，但容器并不能包含语句（语句是描述程序运行操作的一个单位）。

当然，你也可以这样理解，容器是一个只包含变量或常量定义以及函数定义的命名空间。

注意：容器和块（block）不同！

## `usingnamespace`

关键字 `usingnamespace` 可以将一个容器中的所有 `pub` 声明混入到当前的容器中。

例如，可以使用将 `usingnamespace` 将 std 标准库混入到 `main.zig` 这个容器中：

```zig
const T = struct {
    usingnamespace @import("std");
};
pub fn main() !void {
    T.debug.print("Hello, World!\n", .{});
}
```

注意：无法在结构体 `T` 内部直接使用混入的声明，需要使用 `T.debug` 这种方式才可以！

`usingnamespace` 还可以使用 `pub` 关键字进行修饰，用于转发声明，这常用于组织 API 文件和 C import。

```zig
pub usingnamespace @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("GLFW/glfw3.h");
    @cDefine("STBI_ONLY_PNG", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});
```
