---
outline: deep
---

# `zig` 命令

安装好 Zig 和编辑器后，我们来了解一下 `zig` 命令行的基本用法。

这个命令非常强大，它不仅涵盖了项目的创建、构建、测试和运行，甚至还能用于部署，或作为 C/C++ 的编译器及依赖管理工具。这一切都得益于 Zig 强大的自举编译器。

以下列出一些常用命令：

## `zig build`

构建项目。该命令会自动在当前及父目录中查找 `build.zig` 文件并执行构建流程。

## `zig build-obj`

将指定的 Zig 源文件编译成对象文件（`.o` 文件）。

## `zig build test`

编译并执行 `build.zig` 中定义的 "test" 步骤。通常用于运行整个项目的测试。

## `zig init`

初始化一个新的 Zig 项目。此命令会在当前目录下创建 `build.zig`、`build.zig.zon` 和 `src` 目录（包含 `main.zig` 和 `root.zig`）。

> **注意**：在 Zig 0.12+ 版本中，原来的 `zig init-exe` 和 `zig init-lib` 命令已合并为统一的 `zig init` 命令。新的模板同时包含可执行文件和静态库的配置，用户可以根据需要删除不需要的部分。

```sh
.                               # 项目根目录
├── build.zig                   # Zig 构建脚本：定义如何编译、测试和打包项目
├── build.zig.zon               # 项目清单文件 (zon 是 Zig Object Notation)：声明项目元数据和依赖项
└── src                         # 源代码目录
    ├── main.zig                # 程序主入口文件（可执行文件）
    └── root.zig                # 库的根文件（静态库）
```

## `zig ast-check`

对指定的源文件或从标准输入读取的代码进行 AST (抽象语法树) 级别的语法检查。

## `zig fmt`

格式化 Zig 源代码文件。支持指定文件路径，也支持从标准输入（`stdin`）读取内容。

## `zig test`

编译并运行指定源文件中的测试用例。非常适用于单元测试。

## `zig run`

编译并立即运行一个 Zig 程序。该命令对于快速测试代码片段非常有用。

## `zig cc`

使用 Zig 的内置 C 编译器来编译 C 代码。可以看作是 `gcc` 或 `clang` 的直接替代品。

## `zig c++`

使用 Zig 的内置 C++ 编译器来编译 C++ 代码。可以看作是 `g++` 或 `clang++` 的直接替代品。

## `zig translate-c`

将 C 代码自动转换为 Zig 代码。这是一个强大的功能，可以极大地帮助开发者将现有的 C 代码库迁移到 Zig。

## `zig targets`

列出 Zig 编译器支持的所有目标架构、操作系统和 ABI (应用程序二进制接口)。

## `zig version`

显示当前安装的 Zig 编译器版本。

## `zig zen`

输出 Zig 的设计哲学。

## `zig fetch`

此命令用于获取包的哈希值，或直接将包添加为项目的依赖项并记录在 `build.zig.zon` 文件中。

```sh
# 仅获取包的哈希值
$ zig fetch https://github.com/webui-dev/zig-webui/archive/main.tar.gz
12202809180bab2c7ae3382781b2fc65395e74b49d99ff2595f3fea9f7cf66cfa963
```

如果你希望将包直接添加为依赖项，可以附加 `--save` 参数：

```sh
# 获取哈希值，并将其作为依赖项保存到 build.zig.zon
zig fetch --save https://github.com/webui-dev/zig-webui/archive/main.tar.gz
# 或者使用 git+https 形式，会自动更新到 build.zig.zon
zig fetch --save git+https://github.com/david-vanderson/dvui.git#main
```

当包在其 `build.zig.zon` 中定义了 `name` 字段时，`zig fetch` 会自动使用该名称。你也可以使用 `--save=<custom-name>` 来指定一个自定义的依赖名称，例如 `--save=webuizig`。

除了以上介绍的命令，`zig` 还提供了许多其他命令和选项。随着 Zig 语言的不断发展，新的功能和命令也会持续加入，建议您定期查阅 [Zig 官方文档](https://ziglang.org/documentation/master/) 以获取最新信息。
