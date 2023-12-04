---
outline: deep
---

# 与 C 交互

zig 作为一个可以独立于的语言，并且不依赖于 libc，但 zig 仍然具有非常强大的与 c 直接交互的能力，并远超其他语言。

::: info 🅿️ 提示

zig 所指的交互并不仅仅是使用 C 的库，zig 还可以作为 C 的编译器，导出 C ABI 兼容的库供其他程序使用。

并且 zig 使用 C 并不是通过 [FFI](https://en.wikipedia.org/wiki/Foreign_function_interface)/bindings 实现，而是近乎原生的调用，这归功于 zig 实现了一套 C 的编译器并且支持将 C 代码翻译为 zig 代码！

:::

## C ABI 类型

zig 定义了几个对应 C ABI 的基本类型：

- `c_char`
- `c_short`
- `c_ushort`
- `c_int`
- `c_uint`
- `c_long`
- `c_ulong`
- `c_longlong`
- `c_ulonglong`
- `c_longdouble`

对应 C `void` 类型的时候，使用 `anyopaque` (大小为止的类型)。

## 导入 C Header

C 语言共享类型通常是通过引入头文件实现，这点在 zig 中可以无缝做到，得益于 zig 的 **translate-c** 功能。

接下来展示一个例子，简单地引入 c 标准库的 `printf` 函数：

```zig
const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
});
pub fn main() void {
    _ = c.printf("hello\n");
}
```

::: info 🅿️ 提示

注意：为了构建这个，我们需要引入 `libc`，可以在 `build.zig` 中添加 `exe.linkLibC` 函数，`exe` 是默认的构建变量。

或者我们可以手动执行构建：`zig build-exe source.zig -lc`

:::

[`@cImport`](https://ziglang.org/documentation/master/#cImport) 函数接受一个表达式作为参数，该表达式会在编译期执行，用于控制预处理器指令并引入头文件。

::: info 🅿️ 提示

表达式内应仅包含 [`@cInclude`](https://ziglang.org/documentation/master/#cInclude)、[`@cDefine`](https://ziglang.org/documentation/master/#cDefine)、[`@cUndef`](https://ziglang.org/documentation/master/#cUndef)，它们会在编译时进行解析并转换为 C 代码。

通常情况下，应当只存在一个 `@cImport`，这是防止编译器重复调用 clang，并且避免内联函数被重复，只有为了避免符号冲突（两个文件均定义了相同的标识符）和分析具有不同预处理定义的代码时才出现多个 `@cImport`。

:::

## `C Translation CLI`

TODO

