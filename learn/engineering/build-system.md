---
outline: deep
---

# 构建系统

zig 本身就是一套完整的工具链，它可以用于任何语言的构建，不仅仅是 zig、C、CPP。

::: info 🅿️ 提示

当前 zig 的标准构建器位置：[Github](https://github.com/ziglang/zig/blob/master/lib/build_runner.zig)

:::

## 构建模式

zig 提供了四种构建模式（**Build Mode**）：

- _Debug_
- _ReleaseFast_
- _ReleaseSafe_
- _ReleaseSmall_

如果在 `build.zig` 中使用了 `standardOptimizeOption`，则构建系统会接收命令行的参数来决定实际构建模式（缺省时为 Debug），参数类型为 `-Doptimize`，例如 `zig build -Doptimize=Debug` 就是以 Debug 模式构建。

以下讲述四种构建模式的区别：

| Debug          | ReleaseFast    | ReleaseSafe    | ReleaseSmall   |
| -------------- | -------------- | -------------- | -------------- |
| 构建速度很快   | 构建速度慢     | 构建速度慢     | 构建速度慢     |
| 启用安全检查   | 启用安全检查   | 启用安全检查   | 禁用安全检查   |
| 较差的运行效率 | 很好的运行效率 | 中等的运行效率 | 中等的运行效率 |
| 二进制体积大   | 二进制体积大   | 二进制体积大   | 二进制体积小   |
| 无复现构建     | 可复现构建     | 可复现构建     | 可复现构建     |

:::details 关于 Debug 不可复现的原因

关于为什么 Debug 是不可复现的，ziglang 的文档并未给出具体说明：

效果是在 Debug 构建模式下，编译器会添加一些随机因素进入到程序中（例如内存结构不同），所以任何没有明确说明内存布局的容器在 Debug 构建下可能会有所不同，这便于我们在 Debug 模式下快速暴露某些错误。有意思的是，这并不会影响程序正常运行，除非你的程序逻辑有问题。

**_这是 zig 加强安全性的一种方式（尽可能提高安全性但又不至于造成类似 Rust 开发时过重的心智负担）。_**

:::

## 普通构建

一个最简单的 `build.zig` 是这样的：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
```

zig 会通过该文件对整个项目进行构建操作，包含一个对外暴露的 `build` 函数：

```zig
pub fn build(b: *std.Build) void
```

zig 的标准构建器会以此为入口点，创建一个节点均为 [`std.Build.Step`](https://ziglang.org/documentation/master/std/#A;std:Build.Step) 的有向无环图，其中的每个节点（`Step`）均是我们构建的一部分。

例如以上示例中的 `installArtifact`，会给顶层的 **install step** 添加一个依赖项（构建 exe ），并且使用默认的 options。

以上构建的其他说明：

- `b.standardTargetOptions`: 允许构建器读取来自命令行参数的**构建目标三元组**。
- `b.standardOptimizeOption`： 允许构建器读取来自命令行参数的**构建优化模式**。
- `b.addExecutable`：创建一个 [`Build.Step.Compile`](https://ziglang.org/documentation/master/std/#A;std:Build.Step.Compile) 并返回对应的指针，其参数为 [`std.Build.ExecutableOptions`](https://ziglang.org/documentation/master/std/#A;std:Build.ExecutableOptions)。

以上的 `addExecutable` 通常仅使用 `name`、`root_source_file`、`target`、`optimize` 这几个字段。

::: info 🅿️ 提示

标准构建会产生两个目录，一个是 `zig-cache`、一个是 `zig-out`，第一个是缓存目录（这有助于加快下次构建），第二个是安装目录，不是由项目决定，而是由用户决定（通过 `zig build --prefix` 参数），默认为 `zig-out`。

:::

## Step

Step 可以称之为构建时的步骤，它们可以构成一个有向无环图，我们可以通过 Step 来指定构建过程之间的依赖管理，例如要构建的二进制程序 **A** 依赖一个库 **B**，那么我们可以在构建 **A** 前先构建出 **B**，而 **B** 的构建依赖于 另一个程序生成的数据 **C**，此时我们可以再指定构建库 **B** 前先构建出数据 **C**，大致的图如下：

```
数据C
|
C --> B --> A
      |     |
      |     程序A
      |
      库B
```

例如我们可以在 `build.zig` 中添加一个运行程序的步骤：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = .{ .path = "hello.zig" },
    });

    // 构建并 install
    b.installArtifact(exe);

    // zig 提供了一个方便的函数允许我们直接运行构建结果
    const run_exe = b.addRunArtifact(exe);

    // 注意：这个步骤不是必要的，显示声明运行依赖于构建
    // 这会使运行是从构建输出目录（默认为 zig-out/bin ）运行而不是构建缓存中运行
    // 不过，如果应用程序运行依赖于其他已存在的文件（例如某些 ini 配置文件），这可以确保它们正确的运行
    run_exe.step.dependOn(b.getInstallStep());

    // 注意：此步骤不是必要的
    // 此操作允许用户通过构建系统的命令传递参数，例如 zig build  -- arg1 arg2
    // 当前是将参数传递给运行构建结果
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // 指定一个 step 为 run
    const run_step = b.step("run", "Run the application");

    // 指定该 step 依赖于 run_exe，即实际的运行
    run_step.dependOn(&run_exe.step);
}
```

## CLI 参数

通过 `b.option` 使构建脚本部分配置由用户决定（通过命令行参数传递），这也可用于依赖于当前包的其他包。

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 使用 option 来获取命令参数决定是否剥离调试信息
    const is_strip = b.option(bool, "is_strip", "whether strip executable") orelse false;

    // 设置 exe 的 strip
    exe.strip = is_strip;

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
```

以上，我们通过使用 `b.option` 来实现从命令行读取一个参数决定是否剥离二进制程序的调试信息，使用 `zig build --help` 可以看到输出多了一行：

```sh
Project-Specific Options:
  -Dis_strip=[bool]            whether strip executable
```

## Options 编译期配置

**Options** 允许我们将一些信息传递到项目中，例如我们可以以此实现让程序打印构建时的时间戳：

:::code-group

```zig [main.zig]
const std = @import("std");
const timestamp = @import("timestamp");

pub fn main() !void {
    std.debug.print("build time stamp is {}\n", .{timestamp.time_stamp});
}
```

```zig [build.zig]
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 通过标准库获取时间戳
    const timestamp = std.time.timestamp();

    // 创建一个 options
    const options = b.addOptions();

    // 向 options 添加 option, 变量名是time_stamp,
    options.addOption(i64, "time_stamp", timestamp);

    // 向 exe 中添加 options
    exe.addOptions("timestamp", options);

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
```

:::

可以发现，我们使用 `b.addOptions` 创建了一个 **options**，并且向其中添加了 **option**，最后将整个 **options** 塞入二进制程序的构建中，这会允许我们通过 `@import` 来将 **options** 作为包导入。

::: info 🅿️ 提示

事实上，在 `build.zig` 中的 options，会在编译时转为一个规范的 zig 包传递给程序，这就是我们为何能够像普通包一样 `import` 它们的原因。

:::

## 构建静/动态链接库

通常我们定义一个 `lib` 的方式如下：

:::code-group

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
    // 但其实这是不必要的，因为如果有可执行二进制程序构建使用了 lib，那么它会自动被构建
    b.installArtifact(lib);

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 链接 lib
    exe.linkLibrary(lib);

    // 添加到顶级 install step 中作为依赖，构建 exe
    b.installArtifact(exe);
}
```

```zig [0.11]
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 尝试添加一个静态库
    // 动态链接库则是 addSharedLibrary
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

    // TODO
}
```

:::

通常，二进制可执行程序的构建结果会输出在 `zig-out/bin` 下，而链接库的构建结果会输出在 `zig-out/lib` 下。

如果要连接到系统的库，则使用 `exe.linkSystemLibrary`，例如：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zip",
        .root_source_file = .{ .path = "zip.zig" },
    });

    // 链接到系统的 libz
    exe.linkSystemLibrary("z");
    // 链接到 libc
    exe.linkLibC();

    b.installArtifact(exe);
}
```

这会链接一个名为 libz 的库，约定库的名字不包含 “lib”。

## 构建 api 文档

zig 本身提供了一个实验性的文档生成器，它支持搜索查询，操作如下：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // ...

    // 添加 step
    const docs_step = b.step("docs", "Emit docs");

    // 构建文档
    const docs_install = b.addInstallDirectory(.{
        // lib 库
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        // 文档子文件夹
        .install_subdir = "docs",
    });

    // 依赖step
    docs_step.dependOn(&docs_install.step);
    // ...
}
```

以上代码定义了一个名为 `docs` 的 Step，并将 `addInstallDirectory` 操作作为依赖添加到 `docs` Step 上。

## Test

每个文件可以使用 `zig test` 命令来执行测试，但实际开发中这样很不方便，zig 的构建系统提供了另外一种方式来处理当项目变得复杂时的测试。

使用构建系统执行单元测试时，构建器和测试器会通过 stdin 和 stdout 进行通信，以便同时运行多个测试，并且可以有效地报告错误（不会将错误混到一起），但这导致了无法[在单元测试中写入 stdin](https://github.com/ziglang/zig/issues/15091)，这会扰乱测试器的正常工作。另外， zig 将引入一个额外的机制，允许[预测 `panic`](https://github.com/ziglang/zig/issues/1356)。

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);

    // 此处开始构建单元测试

    // 构建一个单元测试的 Compile
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 执行单元测试
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // 如果想要跳过外部来自于其他包的单元测试（例如依赖中的包），可以使用 skip_foreign_checks
    run_unit_tests.skip_foreign_checks = true;

    // 构建一个 step，用于执行测试
    const test_step = b.step("test", "Run unit tests");

    // 测试 step 依赖上方构建的 run_exe_unit_tests
    test_step.dependOn(&run_exe_unit_tests.step);
}

```

以上代码中，先通过 `b.addTest` 构建一个单元测试的 `Compile`，随后进行执行并将其绑定到 `test` Step 上。

## 交叉编译

TODO

## `embedFile`

TODO

## 执行其他命令

zig 的构建系统还允许我们执行一些额外的命令，录入根据 json 生成某些特定的文件（例如 zig 源代码），构建其他的编程语言（不只是 C / C++），如Golang、Rust、前端项目构建等等！

### 文件生成

TODO

### 构建纯 C 项目

TODO

### 构建纯 C++ 项目

TODO
