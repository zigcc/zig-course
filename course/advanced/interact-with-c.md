---
outline: deep
---

# 与 C 交互

zig 作为一个可以独立于 C 的语言，不依赖 libc，但 zig 仍然具有非常强大的与 C 直接交互的能力，并远超其他语言。

> [!TIP] 什么是 libc
> libc 是 C 语言的标准库，它提供了许多基本的程序功能，如输入 / 输出处理、字符串操作、内存管理等。在 Unix 和 Linux 系统中，libc 通常是操作系统的核心部分，它提供了系统调用的接口，使得应用程序可以使用操作系统的服务。在 Windows 系统中，类似的库是 msvcrt 库。

::: info 🅿️ 提示

zig 所指的交互并不仅仅是使用 C 的库，zig 还可以作为 C 的编译器，导出 C ABI 兼容的库供其他程序使用。

并且 zig 使用 C 并不是通过 [FFI](https://en.wikipedia.org/wiki/Foreign_function_interface) / bindings 实现，而是近乎原生的调用，这归功于 zig 实现了一套 C 的 [编译器](https://github.com/ziglang/zig/tree/master/lib/compiler/aro) 并且支持将 C 代码翻译为 zig 代码！

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

对应 C `void` 类型的时候，使用 `anyopaque` (大小未知的类型)。

## C Header 导入

C 语言共享类型通常是通过引入头文件实现，这点在 zig 中可以无缝做到，得益于 zig 的 **translate-c** 功能。

接下来展示一个例子，简单地引入 c 标准库的 `printf` 函数：

<<<@/code/release/interact_with_c.zig#cHeaderImport

::: info 🅿️ 提示

注意：为了构建这个，我们需要引入 `libc`，可以在 `build.zig` 中添加 `exe.linkLibC` 函数，`exe` 是默认的构建变量。

或者我们可以手动执行构建：`zig build-exe source.zig -lc`

:::

[`@cImport`](https://ziglang.org/documentation/master/#cImport) 函数接受一个表达式作为参数，该表达式会在编译期执行，用于控制预处理器指令并引入头文件。

::: info 🅿️ 提示

表达式内应仅包含 [`@cInclude`](https://ziglang.org/documentation/master/#cInclude)、[`@cDefine`](https://ziglang.org/documentation/master/#cDefine)、[`@cUndef`](https://ziglang.org/documentation/master/#cUndef)，它们会在编译时进行解析并转换为 C 代码。

通常情况下，应当只存在一个 `@cImport`，这是防止编译器重复调用 clang，并且避免内联函数被重复，只有为了避免符号冲突（两个文件均定义了相同的标识符）和分析具有不同预处理定义的代码时才出现多个 `@cImport`。

:::

## vcpkg C Lib 导入

> [!IMPORTANT]
> 该部分示例代码暂无 CI 测试，可能存在过期情况，请注意！

既然可以引入头文件，那么毫无疑问同样可以引入由第三方写好的二进制 lib 库。

以微软开发的跨平台开源 c/c++ 包管理器 _vcpkg_ 的库导入为例，具体安装以及设置环境变量的教程不在这里赘叙，只讲怎么 zig 使用已经编译好的 lib。

假如你所处的开发环境系统为 "Windows"、处理器架构为 "x64"、vcpkg 安装目录为 "D:\vcpkg"、并且操作模式为 classic（Classic Mode）、要使用并且已安装的库为 c 运算库 `gsl`。

那么在 `build.zig` 文件中，

<<<@/code/release/import_vcpkg/build.zig#c_import

假设你想要借用 `gsl` 库来对数值进行傅里叶变换，那么可以先导入

<<<@/code/release/import_vcpkg/src/main.zig#import_gsl

然后使用 `gsl_fft_complex_radix2_forward` 函数计算从 1 到 n 的复数数组的离散傅里叶变换

<<<@/code/release/import_vcpkg/src/main.zig#use_gsl_fft

::: info 🅿️ 提示

zig 使用 c++ 库的方式同 c 一样，需要保证该库 `extern "C"`，并且在需要使用动态库的时候也同样不能少。

:::

## `C Translation CLI`

zig 提供了一个命令行工具 `zig translate-c` 供我们使用，它可以将 C 的代码翻译为 zig 的代码，并将其输出到标准输出。

### 命令行参数

- `-I`：指定 `include` 文件的搜索目录，可多次使用，相当于 clang 的 `-I` 标志，默认不包含当前目录（仅添加参数 `-I` 来添加当前目录）。
- `-D`：定义预处理器宏，相当于 clang 的 `-D` 标志。
- `-cflags [flags] --`：将任意附加命令行参数传递给 clang（注意：最后一定要加 `--`）。
- `-target`：zig 的构建目标三元组，缺省则使用本机作为构建目标。

::: info 🅿️ 提示

完整的构架目标三元组可以通过 `zig targets` 命令查看。

在使用翻译功能时，需要保证 target 和传递的 cflags 是正确的，否则可能会出现解析失败或者与 C 代码链接时出现微妙的 ABI 不兼容问题。

:::

### `@cImport` vs `translate-c`

事实上，这两者底层实现是一样的，`@cImport` 一般用于使用 C 库时引入头文件，而 `translate-c` 通常是为了修改翻译后的代码，例如：将 `anytype` 修改为更加精确的类型、将 `[*c]T` 指针修改为 `[*]T` 或者 `*T` 来提高类型安全性、启动或者禁用某些运行时的安全性功能。

## C 翻译缓存

C 翻译功能（无论是通过 `zig translate-c` 还是 `@cImport` 使用）与 Zig 缓存系统集成。使用相同源文件、目标和 `cflags` 的后续构建将使用缓存，而不是重复翻译相同的代码。

要在编译使用 `@cImport` 引入的代码时打印缓存文件的存储位置，请使用 `--verbose-cimport` 参数：

<<<@/code/release/interact_with_c.zig#cTranslate

```sh
$ zig build-exe test.zig -lc --verbose-cimport
info(compilation): C import source: /home/username/.cache/zig/o/6f35761b17b87ee4c9f26e643a06e289/cimport.h
info(compilation): C import .d file: /home/username/.cache/zig/o/6f35761b17b87ee4c9f26e643a06e289/cimport.h.d
info(compilation): C import output: /home/username/.cache/zig/o/86899cd499e4c3f94aa141e400ac265f/cimport.zig
```

`cimport.h` 包含要翻译的文件（通过调用 `@cInclude`、`@cDefine` 和 `@cUndef` 构建），`cimport.h.d` 是文件依赖项列表，`cimport.zig` 包含翻译后的代码。

## C 翻译错误

针对某些 C 的结构，zig 会无法翻译，如：`goto`、使用位域（**bitfields**）的结构体、拼接（**token-pasting**）宏，zig 会暂时简单处理一下它们以继续翻译任务。

处理方式有三种：`opaque`、`extern`、`@compileError`。

1. 无法被正确翻译的 C 结构体和联合类型会被翻译为 [`opaque{}`](../basic/advanced_type/opaque)。
2. 包含 `opaque` 类型或者代码结构无法被翻译的函数会使用 `extern` 标记为外部连接函数，仅存在函数的声明，没有具体的定义。只要编译器知道去哪里找到函数的具体实现，那就可以正常使用。
3. 当顶层空间（全局变量、函数原型、宏）无法转换或处理时，zig 会使用 `@compileError` ，但得益于 zig 针对顶级声明使用惰性分析，故只有在使用它们时才会报告编译错误。

## C Macro

关于 C 中的宏，zig 会尽量将类似函数的宏定义转为对应的 zig 函数，但由于宏是在词法分析的级别上生效，并非所有宏均可以转为函数。无法翻译的宏会被转为 `@compileError` 错误。

::: info 🅿️ 提示

请注意，使用了宏的 C 代码转换并不会出问题，这是因为 zig 会在经过预处理器加工后的代码上进行翻译，只是翻译宏可能失败（但不排除当前因为 bug 导致翻译出错）。

```c
#define MAKELOCAL(NAME, INIT) int NAME = INIT
int foo(void) {
   MAKELOCAL(a, 1);
   MAKELOCAL(b, 2);
   return a + b;
}
```

经过翻译后变为如下代码，函数 `foo` 是正常可以工作的，仅仅是宏 `MAKELOCAL` 无法正常使用！

```zig
pub export fn foo() c_int {
    var a: c_int = 1;
    _ = &a;
    var b: c_int = 2;
    _ = &b;
    return a + b;
}
pub const MAKELOCAL =
    @compileError("unable to translate C expr: unexpected token .Equal");
```

:::

## C 指针

应尽量避免使用此类型，通常它仅出现在翻译输出代码中。

导入 C 头文件后，zig 并不知道如何处理指针（因为 C 的指针可以同时作为单项指针和多项指针使用），这会导致歧义，故 zig 引入一种新类型 `[*c]T`，作为一种折中方案，新类型 `[*c]T` 具有以下特点：

1. 支持 zig 普通指针（`*T` 和 `[*]T`）的全部语法。
2. 可以强制转换为其他的任意指针类型，当然也包括可选指针类型（当被转换为非可选指针时，如果地址为 0，此时会触发安全检查的保护机制，报错并通知出现了未定义行为）。
3. 允许地址为 0，在非 `freestanding`（可以简单看作裸机器，通常编写内核会使用这个）目标上，不允许取消引用地址为 0 的指针（会触发未定义行为）。可选的 C 指针引入一个位来跟踪 `null`，但通常无需这样做，可以直接使用普通的可选指针。
4. 支持与整数进行强制转换。
5. 支持和整数进行比较。
6. 不支持 zig 的指针特性，例如对齐（align）方式，如果要设置这些，请转换为普通指针后再进行操作！

当 C 指针指向一个结构体时，此时它是单项指针，则可以这样解引用：

```zig
ptr_to_struct.*.struct_member
```

当 C 指针指向一个数组时，此时它是一个多项指针，则可以这样解引用：

```zig
ptr_to_struct_array[index].struct_member
```

## C 可变参数函数

zig 支持外部（`extern`）可变参数函数：

<<<@/code/release/interact_with_c.zig#external_func

可变参数的访问可以使用 [`@cVaStart`](https://ziglang.org/documentation/master/#cVaStart)、[`@cVaEnd`](https://ziglang.org/documentation/master/#cVaEnd)、[`@cVaArg`](https://ziglang.org/documentation/master/#cVaArg) 和 [`@cVaCopy`](https://ziglang.org/documentation/master/#cVaCopy) 来实现：

<<<@/code/release/interact_with_c.zig#external

## 额外内容

以下是经过实践和总结出来的额外信息，zig 官方的手册并未提供！

### 为什么 zig 可以做到比 c 更好的编译

实际上，zig 本身实现了一个 C 的编译器（目前仅限 linux，其他平台仍使用 llvm），当然不仅仅如此，zig 还提供了一个比较 **_magic_** 的东西—— [`glibc-abi-tool`](https://github.com/ziglang/glibc-abi-tool)，这是一个收集每个版本的 glibc 的 `.abilist` 文件的存储库，还包含一个将它们组合成一个数据集的工具。

所以，zig 本身所谓的“**_ships with libc_**”并不准确，它的确分发 libc，但它只携带每个版本的符号库，仅依赖这个符号库，zig 就可以实现在没有 libc 的情况下仍然正确地进行动态链接！

::: info 🅿️ 提示

由于这种特性，这导致 zig 尽管携带了 40 个 libc，却仍然能保持 45MB（linux-x86-64）左右的大小，作为对比 llvm 分发的 clang 完整的工具链的大小多达好几百 M。

关于更多的细节，你可以参考以下链接：

- [process_headers tool](https://github.com/ziglang/zig/blob/0.4.0/libc/process_headers.zig)
- [Updating libc](https://github.com/ziglang/zig/wiki/Updating-libc)
- [hacker news](https://news.ycombinator.com/item?id=29538264)

:::

### zig 能静态链接 libc 吗？

能，又不能！

zig 支持静态链接 musl（针对 linux 的另一个 libc，目标为嵌入式系统与移动设备），其他仅支持动态链接。受益于这种特性，我们可以将它作为 C 编译器的替代品使用，它可以提供更加完善的工具链。

举个比较 _剑走偏锋_ 的例子，go 的 cgo 特性一直为人们所吐槽，一旦使用了它，就要和 go 宣称的非常方便的交叉编译说拜拜了，但我们可以使用 zig 来帮助我们实现 cgo 的交叉编译：

```sh
CC='zig cc -target x86_64-linux-gnu' CXX='zig cc -target x86_64-linux-gnu' go build
```

设置 zig 作为 C 编译器来供 go 使用，只要对 zig 和 go 设置正确的 target，就可以在本机实现完善的交叉编译。

再进一步，我们还可以构建出 linux 的使用 cgo 的静态链接的二进制可执行文件：

```sh
CC='zig cc -target x86_64-linux-musl' \
CXX='zig cc -target x86_64-linux-musl' \
CGO_CFLAGS='-D_LARGEFILE64_SOURCE' \
go build -ldflags='-linkmode=external -extldflags -static'
```

`CGO_CFLAGS` 是为了防止编译失败，`ldflags` 是为了指定静态链接！
