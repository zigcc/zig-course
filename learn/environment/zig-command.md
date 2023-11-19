---
outline: deep
---

# `zig` 命令

现在，我们已经安装了 zig ，也安装了对应的编辑器，接下来就了解一下基本的 `zig` 命令。

这单单一个命令可神了，它囊括了项目建立、构建、测试、运行，甚至你可以用它来部署你的项目，也可以用来给 C/C++ 作为编译或者依赖管理工具，非常的全面，这一切都是得益于 zig 本身的编译期。

以下仅列出常用的命令！

## `zig build`

构建项目，会自动搜索当前目录及父目录的 `build.zig` 进行构建。

## `zig init-exe`

这个命令用于初始化项目（可执行二进制文件），在当前路径下创建 `src/main.zig` 和 `build.zig` 两个文件。

关于 `build.zig` 这个文件的内容涉及到了 zig 的构建系统，我们将会单独讲述。

```sh
.
├── build.zig
└── src
    └── main.zig
```

## `zig init-lib`

如果你想写一个 zig 的库，那么可以使用该命令，在当前路径下创建 `src/main.zig` 和 `build.zig` 两个文件。

::: tip 🅿️ 提示
创建出来的 `main.zig` `build.zig` 和通过 `init-exe` 命令创建出来的 `main.zig` `build.zig` 并不相同。
:::

```sh
.
├── build.zig
└── src
    └── main.zig
```

## `zig ast-check`

对指定文件进行AST语法检查，支持指定文件和标准输入。

## `zig fmt`

用于格式化代码源文件，支持`stdin`和指定路径。

## `zig test`

对指定的源文件运行test,适用于单元测试。
