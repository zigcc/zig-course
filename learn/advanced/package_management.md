---
outline: deep
---

# 包管理

随着 `0.11` 的发布，zig 终于迎来了一个正式的官方包管理器，此前已知是通过第三方包管理器下载并处理包。

zig 当前并没有一个中心化存储库，包可以来自任何来源，无论是本地还是网络上。

## 新的文件结构

`build.zig.zon` 这个文件存储了包的信息，它是 zig 新引入的一种简单数据交换格式，使用了 zig 的匿名结构和数组初始化语法。

```zig
.{
    .name = "my_package_name",
    .version = "0.1.0",
    .dependencies = .{
        .dep_name = .{
            .url = "https://link.to/dependency.tar.gz",
            .hash = "12200f41f9804eb9abff259c5d0d84f27caa0a25e0f72451a0243a806c8f94fdc433",
        },
    },
    // 这里的 paths 字段是当前 nightly 版本新引入的
    // 它用于显式声明包含的源文件，如果包含全部则指定为空
    .paths = .{
        "",
    },
}
```

以上字段含义为：

- `name`：当前你所开发的包的名字
- `version`：包的版本，使用 [Semantic Version](https://semver.org/)。
- `dependencies`：依赖项，内部是一连串的匿名结构体，字段 `dep_name` 是依赖包的名字，`url` 是源代码地址，`hash` 是对应的 hash（源文件内容的 hash）。
- `paths`：显式声明包含的源文件，包含所有则指定为空，当前仅 `nightly` 可用。

目前为止，`0.11` 版本支持两种打包格式的源文件：`tar.gz` 和 `tar.xz`。

::: info 🅿️ 提示

小技巧：如何直接使用指定分支的源码？

如果代码托管平台提供分支源码打包直接返回功能，就支持，例如 github 的源码分支打包返回的 url 格式为：

`https://github.com/username/repo-name/archive/branch.tar.gz`

其中的 `username` 就是组织名或者用户名，`repo-name` 就是对应的仓库名，`branch` 就是分支名。

例如 `https://github.com/limine-bootloader/limine-zig/archive/trunk.tar.gz` 就是获取 [limine-zig](https://github.com/limine-bootloader/limine-zig) 这个包的主分支源码打包。

:::

::: info 🅿️ 提示

当前 `nightly` 的 zig 支持了通过 [`zig fetch`](../environment/zig-command#zig-fetch) 来获取 hash 并写入到 `.zon` 中！

:::

## 编写包

::: info 🅿️ 提示

zig 支持在一个 `build.zig` 中对外暴露出多个模块，也就是说一个包本身可以包含多个模块，并且 `lib` 和 `executable` 两种是完全可以共存的！

:::

如何将模块对外暴露呢？

可以使用 `build` 函数传入的参数 `b: *std.Build`，它包含一个方法 [`addModule`](https://ziglang.org/documentation/master/std/#A;std:Build.addModule)， 它的原型如下：

```zig
fn addModule(b: *Build, name: []const u8, options: CreateModuleOptions) *Module
```

使用起来也很简单，例如：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib_module = b.addModule("package", .{ .source_file = .{ .path = "lib.zig" } });
    _ = lib_module;
}
```

这就是一个最基本的包暴露实现，通过 `addModule` 函数暴露的模块是完全公开的。

::: info 🅿️ 提示

如果需要使用私有的模块，请使用 [`std.Build.createModule`](https://ziglang.org/documentation/master/std/#A;std:Build.createModule)，使用方式和 `addModule` 同理。

关于二进制构建结果（例如动态链接库和静态链接库），任何被执行 `install` 操作的构建结果均会被暴露出去（即引入该包的项目均可看到该包的构建结果，但需要手动 link ）。

:::

## 引入包

可以使用 `build` 函数传入的参数 `b: *std.Build`，它包含一个方法 [`dependency`](https://ziglang.org/documentation/master/std/#A;std:Build.dependency)， 它的原型如下：

```zig
fn dependency(b: *Build, name: []const u8, args: anytype) *Dependency
```

其中 `name` 是在在 `.zon` 中的包名字，它返回一个 [`*std.Build.Dependency`](https://ziglang.org/documentation/master/std/#A;std:Build.Dependency)，可以使用 `artifact` 和 `module` 方法来访问包的链接库和暴露的 `module`。

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {

    // 默认构建目标
    const target = b.standardTargetOptions(.{});
    // 默认优化模式
    const optimize = b.standardOptimizeOption(.{});

    // ...

    // 获取包
    const package = b.dependency("package_name", .{});

    // 获取包构建的library，例如链接库
    const library_name = package.artifact("library_name");


    // 获取包提供的模块
    const module_name = package.module("module_name");

    // ...

    const exe = try b.addExecutable(.{
        .name = "my_binary",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 链接依赖提供的库
    exe.linkLibrary(library_name);
}

```

如果需要引入一个本地包（且该包自己有 `build.zig`），那么可以使用 [`std.Build.anonymousDependency`](https://ziglang.org/documentation/master/std/#A;std:Build.anonymousDependency)， 它的原型为：

```zig
fn anonymousDependency(b: *Build, relative_build_root: []const u8, comptime build_zig: type, args: anytype) *Dependency
```

参数为包的包构建根目录和通过 `@import` 导入的包的 `build.zig` 。

::: info 🅿️ 提示

`dependency` 和 `anonymousDependency` 都包含一个额外的参数 `args`，这是传给对应的包构建的参数（类似在命令行构建时使用的 `-D` 参数，通过 [`std.Build.option`](https://ziglang.org/documentation/master/std/#A;std:Build.option) 实现），当前包的参数并不会向包传递，需要手动显式指定转发。

:::
