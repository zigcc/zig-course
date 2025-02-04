---
outline: deep
---

# 构建系统

Zig 除了是一门编程语言外，本身还是一套完整的工具链，例如：

- `zig cc`、`zig c++` C/C++ 编译器
- `zig build` 适用于 Zig/C/C++ 的构建系统

本章节就来介绍 Zig 的构建系统。

## 理念

Zig 使用 `build.zig` 文件来描述一个项目的构建步骤。

如其名字所示，该文件本身就是一个 Zig 程序，而不是类似 `Cargo.toml` 或 `CMakeLists.txt` 这样的领域特定语言（DSL）。

这样的好处很明显，表达能力更强，开发者只需要使用同一门语言即可进行项目构建，减轻了用户心智。

一个典型的构建文件如下：

<<<@/code/release/build_system/basic/build.zig

`build` 是构建的入口函数，而不是常见的 `main`，真正的 `main` 函数定义在 [`build_runner.zig`](https://github.com/ziglang/zig/blob/master/lib/compiler/build_runner.zig#L15) 中，这是由于 Zig 的构建分为两个阶段：

1. 生成由 [`std.Build.Step`](https://ziglang.org/documentation/master/std/#std.Build.Step) 构成有向无环图（DAG）
2. 执行真正的构建逻辑

> [!TIP]
> 第一次接触 Zig 的构建流程，可能会觉得复杂，尤其是构建 Step 的依赖关系，但这是为了后续并发编译作基础。
>
> 如果没有 `build_runner.zig` ，让开发者自己去处理并发编译，将会是件繁琐且容易出错的事情。

`Step` 会在下一小节中会重点讲述，这里介绍一下上面这个构建文件的其他部分：

- `b.standardTargetOptions`: 允许构建器读取来自命令行参数的**构建目标三元组**。
- `b.standardOptimizeOption`：允许构建器读取来自命令行参数的**构建优化模式**。
- `b.addExecutable`：创建一个 [`Build.Step.Compile`](https://ziglang.org/documentation/master/std/#std.Build.Step.Compile) 并返回对应的指针，其参数为 [`std.Build.ExecutableOptions`](https://ziglang.org/documentation/master/std/#std.Build.ExecutableOptions)。
- `b.path`：该函数用于指定获取当前项目的源文件路径，请勿手动为 `root_source_file` 赋值！

::: info 🅿️ 提示

标准构建会产生两个目录，一个是 `zig-cache`、一个是 `zig-out`，第一个是缓存目录（这有助于加快下次构建），第二个是安装目录，不是由项目决定，而是由用户决定（通过 `zig build --prefix` 参数），默认为 `zig-out`。

:::

### Step

Step 可以称为构建时的步骤，它们将构成一个有向无环图。可以通过 Step 来指定构建过程之间的依赖管理，例如要构建的二进制程序 **A** 依赖一个库 **B**，那么我们可以在构建 **A** 前先构建出 **B**，而 **B** 的构建依赖于 另一个程序生成的数据 **C**，此时我们可以再指定构建库 **B** 前先构建出数据 **C**，大致的图如下：

```sh
数据C
|
C --> B --> A
      |     |
      |     程序A
      |
      库B
```

例如我们可以在 `build.zig` 中添加一个运行程序的步骤：

<<<@/code/release/build_system/step/build.zig

以上代码中，我们可以使用 `zig build run -- arg1` 向构建产物传递参数！

::: info 🅿️ 提示

值得注意的是，`b.installArtifact` 是将构建放入 `install` 这一默认的 step 中。

如果我们想要重新创建一个全新的 install，可以使用 [`b.addInstallArtifact`](https://ziglang.org/documentation/master/std/#std.Build.addInstallArtifact)。

它会返回一个新的 [`InstallArtifact`](https://ziglang.org/documentation/master/std/#std.Build.Step.InstallArtifact)，让对应的 step 依赖它即可！

:::

## 基本使用

### 构建模式

zig 提供了四种构建模式（**Build Mode**）：

- _Debug_
- _ReleaseFast_
- _ReleaseSafe_
- _ReleaseSmall_

如果在 `build.zig` 中使用了 [`standardOptimizeOption`](https://ziglang.org/documentation/master/std/#std.Build.standardOptimizeOption)，则构建系统会接收命令行的参数来决定实际构建模式（缺省时为 Debug），参数类型为 `-Doptimize`，例如 `zig build -Doptimize=Debug` 就是以 Debug 模式构建。

以下讲述四种构建模式的区别：

| Debug          | ReleaseFast    | ReleaseSafe    | ReleaseSmall   |
| -------------- | -------------- | -------------- | -------------- |
| 构建速度很快   | 构建速度慢     | 构建速度慢     | 构建速度慢     |
| 启用安全检查   | 启用安全检查   | 启用安全检查   | 禁用安全检查   |
| 较差的运行效率 | 很好的运行效率 | 中等的运行效率 | 中等的运行效率 |
| 二进制体积大   | 二进制体积大   | 二进制体积大   | 二进制体积小   |
| 无复现构建     | 可复现构建     | 可复现构建     | 可复现构建     |

:::details 关于 Debug 不可复现的原因

关于为什么 Debug 是不可复现的，zig 官方手册并未给出具体说明，以下内容为询问社区获得：

在 Debug 构建模式下，编译器会添加一些随机因素进入到程序中（例如内存结构不同），所以任何没有明确说明内存布局的容器在 Debug 构建下可能会有所不同，这便于我们在 Debug 模式下快速暴露某些错误。

有意思的是，这并不会影响程序正常运行，除非你的程序逻辑有问题。

**_这是 zig 加强安全性的一种方式（尽可能提高安全性但又不至于造成类似 Rust 开发时过重的心智负担）。_**

:::

### CLI 参数

通过 `b.option` 使构建脚本部分配置由用户决定（通过命令行参数传递），这也可用于依赖于当前包的其他包。

<<<@/code/release/build_system/cli/build.zig

以上，我们通过使用 `b.option` 来实现从命令行读取一个参数决定是否剥离二进制程序的调试信息，使用 `zig build --help` 可以看到输出多了一行：

```sh
Project-Specific Options:
  -Dis_strip=[bool]            whether strip executable
```

### Options 编译期配置

**Options** 允许我们将一些信息传递到项目中，例如我们可以以此实现让程序打印构建时的时间戳：

:::code-group

<<<@/code/release/build_system/options/src/main.zig [main.zig]

<<<@/code/release/build_system/options/build.zig [build.zig]

:::

可以发现，我们使用 `b.addOptions` 创建了一个 **options**，并且向其中添加了 **option**，最后将整个 **options** 塞入二进制程序的构建中，这会允许我们通过 `@import` 来将 **options** 作为包导入。

::: info 🅿️ 提示

事实上，在 `build.zig` 中的 options，会在编译时转为一个规范的 zig 包传递给程序，这就是我们为何能够像普通包一样 `import` 它们的原因。

:::

### 构建静/动态链接库

通常我们定义一个 `lib` 的方式如下：

<<<@/code/release/build_system/lib/build.zig

对应地，如果要构建动态库可以使用 `b.addSharedLibrary`。

通常，二进制可执行程序的构建结果会输出在 `zig-out/bin` 下，而链接库的构建结果会输出在 `zig-out/lib` 下。

如果要连接到系统的库，则使用 `exe.linkSystemLibrary`，Zig 内部借助 pkg-config 实现该功能。示例：

<<<@/code/release/build_system/system_lib/build.zig

这会链接一个名为 libz 的库，约定库的名字不包含“lib”。

### 生成文档

zig 本身提供了一个实验性的文档生成器，它支持搜索查询，操作如下：

<<<@/code/release/build_system/docs/build.zig

以上代码定义了一个名为 `docs` 的 Step，并将 `addInstallDirectory` 操作作为依赖添加到 `docs` Step 上。

### 单元测试

每个文件可以使用 `zig test` 命令来执行测试，但实际开发中这样很不方便，zig 的构建系统提供了另外一种方式来处理当项目变得复杂时的测试。

使用构建系统执行单元测试时，构建器和测试器会通过 stdin 和 stdout 进行通信，以便同时运行多个测试，并且可以有效地报告错误（不会将错误混到一起），但这导致了无法 [在单元测试中写入 stdin](https://github.com/ziglang/zig/issues/15091)，这会扰乱测试器的正常工作。另外，zig 将引入一个额外的机制，允许 [预测 `panic`](https://github.com/ziglang/zig/issues/1356)。

<<<@/code/release/build_system/test/build.zig

以上代码中，先通过 `b.addTest` 构建一个单元测试的 `Compile`，随后进行执行并将其绑定到 `test` Step 上。

## 高级功能

### 交叉编译

得益于 LLVM 的存在，zig 支持交叉编译到任何 LLVM 的目标代码，zig 可以很方便的处理交叉编译，只需要指定好恰当的 target 即可。

关于所有的 target，可以使用 `zig targets` 查看。

最常用的一个 target 设置可能是 `b.standardTargetOptions`，它会允许读取命令行输入来决定构建目标 target，它返回一个 [`ResolvedTarget`](https://ziglang.org/documentation/master/std/#std.Build.ResolvedTarget)。

如果需要手动指定一个 target，可以手动构建一个 `std.Target.Query` 传递给构建（`addExecutable` 和 `addStaticLibrary` 等），如：

<<<@/code/release/build_system/build.zig#crossTarget

值得注意的是，目前 zig 已经将 `target query` 和 `resolved target` 完全分开，如果要手动指定构建目标，需要先创建一个 `Query`，再使用 `b.resolveTargetQuery` 进行解析。

关于该部分的变动可以参考此处的 PR：[Move many settings from being per-Compilation to being per-Module](https://github.com/ziglang/zig/pull/18160).

### `embedFile`

[`@embedFile`](https://ziglang.org/documentation/master/#embedFile) 是由 zig 提供的一个内嵌文件的方式，它的引入规则与 `@import` 相同。

在 `build.zig` 直接使用 [`addAnonymousImport`](https://ziglang.org/documentation/master/std/#std.Build.Module.addAnonymousImport) 添加一个匿名模块即可，如：

::: code-group

<<<@/code/release/build_system/embedfile/src/main.zig

<<<@/code/release/build_system/embedfile/src/hello.txt

<<<@/code/release/build_system/embedfile/build.zig

:::

不仅仅是以上两种方式，匿名模块还支持直接使用其他程序输出，具体可参考下面一小节。

### 执行外部命令

zig 的构建系统还允许我们执行一些额外的命令，录入根据 json 生成某些特定的文件（例如 zig 源代码），构建其他的编程语言（不只是 C / C++），如 Golang、Rust、前端项目构建等等！

例如我们可以让 zig 在构建时调用系统的 sh 来输出 hello 并使用 `@embedFile` 传递给包：

:::code-group

<<<@/code/release/build_system/externalfile/src/main.zig

<<<@/code/release/build_system/externalfile/build.zig

:::

### 构建纯 C++ 项目

由于 GTK 的 C++ 构建过于复杂（需要手动编译 gtkmm），故我们这里选择构建一个 [tinytetris](https://github.com/taylorconor/tinytetris):

::: warning

注意：由于依赖了 curses 库，故只能在 linux 进行编译！

:::

::: code-group

<<<@/code/release/build_system/tinytetris/build.zig

<<<@/code/release/build_system/tinytetris/src/main.cc{cpp}

:::

::: info 🅿️ 提示

关于头文件的引入，可以使用 `addIncludePath`

针对多个 C 源代码文件，zig 提供了函数 `addCSourceFiles` 用于便捷地添加多个源文件。

:::

::: warning 关于 `libc++` 的问题

zig 的工具链使用的是 `libc++`（LLVM ABI），而 GNU 的则是 `libstdc++`，两者的标准库实现略有不同，这会导致混用可能出现问题！

正确的做法是，手动编译依赖的源代码（一般是出现问题的），或者使用 `-nostdinc++ -nostdlib++` 指示不使用默认标准库，并链接 GNU 的标准库，具体可以参考该 [issue](https://github.com/ziglang/zig/issues/18300)。

:::

## 更多参考

- [Zig Build System ⚡ Zig Programming Language](https://ziglang.org/learn/build-system/)
