---
outline: deep
---

# 包管理

随着 `0.11` 的发布，zig 终于迎来了一个正式的官方包管理器，此前已知是通过第三方包管理器下载并处理包。

zig 当前并没有一个中心化存储库，包可以来自任何来源，无论是本地还是网络上。

当前的包管理模式为，先在 `build.zig.zon` 添加包的元信息，然后在 `build.zig` 中引入包。

## 新的文件结构

`build.zig.zon` 这个文件存储了包的信息，它是 zig 新引入的一种简单数据交换格式，使用了 zig 的匿名结构和数组初始化语法。

<<<@/code/release/package_management_importer/build.zig.zon#package_management{zig}

以上字段含义为：

- `name`：当前你所开发的包的名字
- `version`：包的版本，使用 [Semantic Version](https://semver.org/)。
- `dependencies`：依赖项，内部是一连串的匿名结构体，字段
  `dep_name` 是依赖包的名字，
  `url` 是源代码地址，
  `hash` 是对应的 hash（源文件内容的 hash），
  `path`是不使用源码包而是本地目录时目录的路径。
  当使用目录方法导入包时就不能使用`url`和`hash`，反之同理。
- `paths`：显式声明包含的源文件，包含所有则指定为空。

::: info 🅿️ 提示

小技巧：如何直接使用指定分支的源码？

如果代码托管平台提供分支源码打包直接返回功能，就支持，例如 github 的源码分支打包返回的 url 格式为：

`https://github.com/username/repo-name/archive/branch.tar.gz`

其中的 `username` 就是组织名或者用户名，`repo-name` 就是对应的仓库名，`branch` 就是分支名。

例如 `https://github.com/limine-bootloader/limine-zig/archive/trunk.tar.gz` 就是获取 [limine-zig](https://github.com/limine-bootloader/limine-zig) 这个包的主分支源码打包。

而若是想要离线使用本地包时则是先下载源码包并直接使用绝对或相对路径导入，例如在下载完包之后放在项目的 deps 目录下，那么使用本地包的格式为：

`./deps/tunk.tar.gz`

:::

::: info 🅿️ 提示

目前 zig 已支持通过 [`zig fetch`](../environment/zig-command#zig-fetch) 来获取 hash 并写入到 `.zon` 中！

:::

## 编写包

::: info 🅿️ 提示

zig 支持在一个 `build.zig` 中对外暴露出多个模块，也就是说一个包本身可以包含多个模块，并且 `lib` 和 `executable` 两种是完全可以共存的！

:::

如何将模块对外暴露呢？

可以使用 `build` 函数传入的参数 `b: *std.Build`，它包含一个方法 [`addModule`](https://ziglang.org/documentation/master/std/#std.Build.addModule)，它的原型如下：

```zig
pub fn addModule(
  b: *Build,
  name: []const u8,
  options: Module.CreateOptions
) *Module
```

使用起来也很简单，例如：

<<<@/code/release/package_management_exporter/build.zig#create_module

这就是一个最基本的包暴露实现，指定了包名和包的入口源文件地址（`b.path` 是相对当前项目路径取 `Path`），通过 `addModule` 函数暴露的模块是完全公开的。

::: info 🅿️ 提示

如果需要使用私有的模块，请使用 [`std.Build.createModule`](https://ziglang.org/documentation/master/std/#std.Build.createModule)，使用方式和 `addModule` 同理。

关于二进制构建结果（例如动态链接库和静态链接库），任何被执行 `install` 操作的构建结果均会被暴露出去（即引入该包的项目均可看到该包的构建结果，但需要手动 link）。

:::

## 引入包

可以使用 `build` 函数传入的参数 `b: *std.Build`，它包含一个方法 [`dependency`](https://ziglang.org/documentation/master/std/#std.Build.dependency)，它的原型如下：

```zig
fn dependency(b: *Build, name: []const u8, args: anytype) *Dependency
```

其中 `name` 是在在 `.zon` 中的包名字，它返回一个 [`*std.Build.Dependency`](https://ziglang.org/documentation/master/std/#std.Build.Dependency)，可以使用 `artifact` 和 `module` 方法来访问包的链接库和暴露的 `module`。

<<<@/code/release/package_management_importer/build.zig#import_module

::: info 🅿️ 提示

`dependency` 包含一个额外的参数 `args`，这是传给对应的包构建的参数（类似在命令行构建时使用的 `-D` 参数，通常是我们使用 `b.options` 获取，通过 [`std.Build.option`](https://ziglang.org/documentation/master/std/#std.Build.option) 实现），当前包的参数并不会向包传递，需要手动显式指定转发。

:::
