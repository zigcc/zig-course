---
outline: deep
---

# 构建系统

TODO

## 构建静态链接库

通常我们定义一个 `lib` 的方式如下：

:::code-group

```zig [0.11]
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 尝试添加一个静态库
    const lib = b.addStaticLibrary(.{
        // 库的名字
        .name = "example",
        // 源文件地址
        .root_source_file = .{ .path = "src/main.zig" },
        // 优化模式
        .optimize = optimize,
    });

    // 在构建时自动构建 lib
    lib.install();
}
```

```zig [nightly]
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的构建目标，支持我们从命令行构建时指定构建目标（架构、系统、abi等等）
    const target = b.standardTargetOptions(.{});

    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 尝试添加一个静态库
    const lib = b.addStaticLibrary(.{
        // 库的名字
        .name = "example",
        // 源文件地址
        .root_source_file = .{ .path = "src/main.zig" },
        // 构建目标
        .target = target,
        // 构建模式
        .optimize = optimize,
    });

    // 这代替原本的 lib.install，在构建时自动构建 lib
    b.installArtifact(lib);
}
```

:::

## 构建 api 文档

zig 本身提供了一个实验性的文档生成器，它支持搜索查询，操作如下：

```zig
    // 添加 step
    const docs_step = b.step("docs", "Emit docs");

    const docs_install = b.addInstallDirectory(.{
        // lib 库
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        // 文档子文件夹
        .install_subdir = "docs",
    });
    // 依赖step
    docs_step.dependOn(&docs_install.step);
```

TODO
