---
outline: deep
---

# 构建系统

zig 本身就是一套完整的工具链，它可以作为任何语言的构建系统（类似Makefile一样的存在，但更加的现代化），不仅仅是 zig、C、CPP。

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

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);

    // zig 提供了一个方便的函数允许我们直接运行构建结果 // [!code focus]
    const run_exe = b.addRunArtifact(exe); // [!code focus]

    // 注意：这个步骤不是必要的，显示声明运行依赖于构建 // [!code focus]
    // 这会使运行是从构建输出目录（默认为 zig-out/bin ）运行而不是构建缓存中运行 // [!code focus]
    // 不过，如果应用程序运行依赖于其他已存在的文件（例如某些 ini 配置文件）// [!code focus]
    // 这可以确保它们正确的运行 // [!code focus]
    run_exe.step.dependOn(b.getInstallStep()); // [!code focus]

    // 注意：此步骤不是必要的
    // 此操作允许用户通过构建系统的命令传递参数，例如 zig build  -- arg1 arg2
    // 当前是将参数传递给运行构建结果
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // 指定一个 step 为 run // [!code focus]
    const run_step = b.step("run", "Run the application"); // [!code focus]

    // 指定该 step 依赖于 run_exe，即实际的运行 // [!code focus]
    run_step.dependOn(&run_exe.step); // [!code focus]
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

    // 使用 option 来获取命令参数决定是否剥离调试信息 // [!code focus]
    const is_strip = b.option(bool, "is_strip", "whether strip executable") orelse false; // [!code focus]

    // 设置 exe 的 strip // [!code focus]
    exe.strip = is_strip; // [!code focus]

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

    // 通过标准库获取时间戳 // [!code focus]
    const timestamp = std.time.timestamp(); // [!code focus]

    // 创建一个 options // [!code focus]
    const options = b.addOptions(); // [!code focus]

    // 向 options 添加 option, 变量名是time_stamp // [!code focus]
    options.addOption(i64, "time_stamp", timestamp); // [!code focus]

    // 向 exe 中添加 options // [!code focus]
    exe.addOptions("timestamp", options); // [!code focus]

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

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的构建目标，支持我们从命令行构建时指定构建目标（架构、系统、abi等等）
    const target = b.standardTargetOptions(.{});

    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 尝试添加一个静态库 // [!code focus]
    const lib = b.addStaticLibrary(.{ // [!code focus]
        // 库的名字 // [!code focus]
        .name = "example", // [!code focus]
        // 源文件地址 // [!code focus]
        .root_source_file = .{ .path = "src/main.zig" }, // [!code focus]
        // 构建目标 // [!code focus]
        .target = target, // [!code focus]
        // 构建模式 // [!code focus]
        .optimize = optimize, // [!code focus]
    }); // [!code focus]

    // 这代替原本的 lib.install，在构建时自动构建 lib // [!code focus]
    // 但其实这是不必要的，因为如果有可执行二进制程序构建使用了 lib，那么它会自动被构建 // [!code focus]
    b.installArtifact(lib); // [!code focus]

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 链接 lib // [!code focus]
    exe.linkLibrary(lib); // [!code focus]

    // 添加到顶级 install step 中作为依赖，构建 exe
    b.installArtifact(exe);
}
```

通常，二进制可执行程序的构建结果会输出在 `zig-out/bin` 下，而链接库的构建结果会输出在 `zig-out/lib` 下。

如果要连接到系统的库，则使用 `exe.linkSystemLibrary`，例如：

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zip",
        .root_source_file = .{ .path = "zip.zig" },
    });

    // 链接到系统的 libz // [!code focus]
    exe.linkSystemLibrary("z"); // [!code focus]

    // 链接到 libc // [!code focus]
    exe.linkLibC(); // [!code focus]

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

    // 添加 step // [!code focus]
    const docs_step = b.step("docs", "Emit docs"); // [!code focus]

    // 构建文档 // [!code focus]
    const docs_install = b.addInstallDirectory(.{ // [!code focus]
        // lib 库 // [!code focus]
        .source_dir = lib.getEmittedDocs(), // [!code focus]
        .install_dir = .prefix, // [!code focus]
        // 文档子文件夹 // [!code focus]
        .install_subdir = "docs", // [!code focus]
    }); // [!code focus]

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

    // 此处开始构建单元测试 // [!code focus]

    // 构建一个单元测试的 Compile // [!code focus]
    const exe_unit_tests = b.addTest(.{ // [!code focus]
        .root_source_file = .{ .path = "src/main.zig" }, // [!code focus]
        .target = target, // [!code focus]
        .optimize = optimize, // [!code focus]
    }); // [!code focus]

    // 执行单元测试 // [!code focus]
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests); // [!code focus]

    // 如果想要跳过外部来自于其他包的单元测试（例如依赖中的包），可以使用 skip_foreign_checks // [!code focus]
    run_unit_tests.skip_foreign_checks = true; // [!code focus]

    // 构建一个 step，用于执行测试 // [!code focus]
    const test_step = b.step("test", "Run unit tests"); // [!code focus]

    // 测试 step 依赖上方构建的 run_exe_unit_tests // [!code focus]
    test_step.dependOn(&run_exe_unit_tests.step); // [!code focus]
}

```

以上代码中，先通过 `b.addTest` 构建一个单元测试的 `Compile`，随后进行执行并将其绑定到 `test` Step 上。

## 交叉编译

得益于 LLVM 的存在，zig 支持交叉编译到任何 LLVM 的目标代码，zig 可以很方便的处理交叉编译，只需要指定好恰当的 target 即可。

关于所有的 target，可以在此处 [查看](https://ziglang.org/documentation/master/#Targets)。

最常用的一个 target 设置可能是 `b.standardTargetOptions`，它会允许读取命令行输入来决定构建目标 target，它返回一个 [`CrossTarget`](https://ziglang.org/documentation/master/std/#A;std:zig.CrossTarget)。

如果需要手动指定一个 target，可以手动构建一个 `CrossTarget` 传递给构建（`addExecutable` 和 `addStaticLibrary` 等），如:

```zig
var target: std.zig.CrossTarget = .{
    .cpu_arch = .x86_64,
    .os_tag = .freestanding,
    .abi = .none,
};

const exe = b.addExecutable(.{
    .name = "zig",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
});
```

## `embedFile`

[`@embedFile`](https://ziglang.org/documentation/master/#embedFile) 是由 zig 提供的一个内嵌文件的方式，它的引入规则与 `@import` 相同。

在 `build.zig` 直接使用 [`b.anonymousDependency`](https://ziglang.org/documentation/master/std/#A;std:Build.anonymousDependency) 添加一个匿名模块即可，如：

::: code-group

```zig [main.zig]
const std = @import("std");
const hello = @embedFile("hello"); // [!code focus]
// const hello = @embedFile("hello.txt"); 均可以 // [!code focus]

pub fn main() !void {
    std.debug.print("{s}", .{hello}); // [!code focus]
}
```

```txt [hello.txt]
Hello, World!
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

    // 添加一个匿名的依赖 // [!code focus]
    exe.addAnonymousModule("hello", .{ .source_file = .{ .path = "src/hello.txt" } }); // [!code focus]

    // 添加到顶级 install step 中作为依赖 
    b.installArtifact(exe);

    // zig 提供了一个方便的函数允许我们直接运行构建结果
    const run_cmd = b.addRunArtifact(exe);

    // 指定依赖
    run_cmd.step.dependOn(b.getInstallStep());

    // 传递参数
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // 指定一个 step 为 run
    const run_step = b.step("run", "Run the app");

    // 指定该 step 依赖于 run_exe，即实际的运行
    run_step.dependOn(&run_cmd.step);
}
```

:::

不仅仅是以上两种方式，匿名模块还支持直接使用其他程序输出,见下方执行其他命令部分！

## 执行其他命令

zig 的构建系统还允许我们执行一些额外的命令，录入根据 json 生成某些特定的文件（例如 zig 源代码），构建其他的编程语言（不只是 C / C++），如Golang、Rust、前端项目构建等等！

例如我们可以让 zig 在构建时调用系统的 sh 来输出 hello 并使用 `@embedFile` 传递给包：

:::code-group

```zig [main.zig]
const std = @import("std");
const hello = @embedFile("hello"); // [!code focus]

pub fn main() !void {
    std.debug.print("{s}", .{hello}); // [!code focus]
}
```

```zig [build.zig]
const std = @import("std");

pub fn build(b: *std.Build) !void {
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

    // 构建一个运行命令 // [!code focus]
    const run_sys_cmd = b.addSystemCommand(&.{ // [!code focus]
        "/bin/sh", // [!code focus]
        "-c", // [!code focus]
    }); // [!code focus]

    // 添加参数，此方法允许添加多个参数 // [!code focus]
    // 也可以使用 addArg 来添加单个参数 // [!code focus]
    run_sys_cmd.addArgs(&.{ // [!code focus]
        "echo hello", // [!code focus]
    }); // [!code focus]

    // 尝试运行命令并捕获标准输出 // [!code focus]
    // 也可以使用 captureStdErr 来捕获标准错误输出 // [!code focus]
    const output = run_sys_cmd.captureStdOut(); // [!code focus]

    // 添加一个匿名的依赖 // [!code focus]
    exe.addAnonymousModule("hello", .{ .source_file = output }); // [!code focus]

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);

    // zig 提供了一个方便的函数允许我们直接运行构建结果
    const run_cmd = b.addRunArtifact(exe);

   // 指定依赖
    run_cmd.step.dependOn(b.getInstallStep());

    // 传递参数
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // 指定一个 step 为 run
    const run_step = b.step("run", "Run the app");

    // 指定该 step 依赖于 run_exe，即实际的运行
    run_step.dependOn(&run_cmd.step);
}
```

:::

### 构建纯 C 项目

在这里我们使用 [GTK4](https://www.gtk.org/) 的官方示例 [Hello-World](https://www.gtk.org/docs/getting-started/hello-world/) 来作为演示：

:::code-group

```zig [build.zig]
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 构建目标
    const target = b.standardTargetOptions(.{});

    // 构建优化模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建 // [!code focus]
    // 注意：我们在这里并没有使用 root_source_file 字段 // [!code focus]
    // 该字段是为 zig 源文件准备的 // [!code focus]
    const exe = b.addExecutable(.{ // [!code focus]
        .name = "zig", // [!code focus]
        .target = target, // [!code focus]
        .optimize = optimize, // [!code focus]
    }); // [!code focus]

    // 添加 C 源代码文件，两个参数： // [!code focus]
    // 源代码路径（相对于build.zig） // [!code focus]
    // 传递的 flags // [!code focus]
    exe.addCSourceFile(.{ // [!code focus]
        .file = .{ // [!code focus]
            .path = "src/main.c", // [!code focus]
        }, // [!code focus]
        .flags = &[_][]const u8{}, // [!code focus]
    }); // [!code focus]

    // 链接标准 C 库 // [!code focus]
    exe.linkLibC(); // [!code focus]

    // 链接系统的GTK4库 // [!code focus]
    exe.linkSystemLibrary("gtk4"); // [!code focus]

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);

    // 创建一个运行
    const run_cmd = b.addRunArtifact(exe);

    // 依赖于构建
    run_cmd.step.dependOn(b.getInstallStep());

    // 运行时参数传递
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // 运行的 step
    const run_step = b.step("run", "Run the app");
    // 依赖于前面的运行
    run_step.dependOn(&run_cmd.step);
}
```

```c [src/main.c]
// 待添加详细注释
#include <gtk/gtk.h>

static void
print_hello (GtkWidget *widget,
             gpointer   data)
{
  g_print ("Hello World\n");
}

static void
activate (GtkApplication *app,
          gpointer        user_data)
{
  GtkWidget *window;
  GtkWidget *button;

  window = gtk_application_window_new (app);
  gtk_window_set_title (GTK_WINDOW (window), "Hello");
  gtk_window_set_default_size (GTK_WINDOW (window), 200, 200);

  button = gtk_button_new_with_label ("Hello World");
  g_signal_connect (button, "clicked", G_CALLBACK (print_hello), NULL);
  gtk_window_set_child (GTK_WINDOW (window), button);

  gtk_window_present (GTK_WINDOW (window));
}

int
main (int    argc,
      char **argv)
{
  GtkApplication *app;
  int status;

  app = gtk_application_new ("org.gtk.example", G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect (app, "activate", G_CALLBACK (activate), NULL);
  status = g_application_run (G_APPLICATION (app), argc, argv);
  g_object_unref (app);

  return status;
}
```

:::

以上构建中我们先使用了 `addCSourceFile` 来添加 C 源代码，再使用 `linkLibC` 和 `linkSystemLibrary` 来链接 C 标准库和 GTK 库。

::: info 🅿️ 提示

关于头文件的引入，可以使用 `exe.addIncludePath(.{ .path = "path" });`

针对多个 C 源代码文件，zig 提供了函数 `exe.addCSourceFiles` 用于便捷地添加多个源文件。

:::

### 构建纯 C++ 项目

由于 GTK 的 C++ 构建过于复杂（需要手动编译gtkmm），故我们这里选择构建一个 [tinytetris](https://github.com/taylorconor/tinytetris):

::: code-group

```zig [build.zig]
const std = @import("std");

pub fn build(b: *std.Build) void {
    // 构建目标
    const target = b.standardTargetOptions(.{});

    // 构建优化模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建 // [!code focus]
    // 注意：我们在这里并没有使用 root_source_file 字段 // [!code focus]
    // 该字段是为 zig 源文件准备的 // [!code focus]
    const exe = b.addExecutable(.{ // [!code focus]
        .name = "zig", // [!code focus]
        .target = target, // [!code focus]
        .optimize = optimize, // [!code focus]
    }); // [!code focus]

    // 添加 C 源代码文件，两个参数： // [!code focus]
    // 源代码路径（相对于build.zig） // [!code focus]
    // 传递的 flags // [!code focus]
    // 多个 C 源代码文件可以使用 addCSourceFiles // [!code focus]
    exe.addCSourceFile(.{ // [!code focus]
        .file = .{ // [!code focus]
            .path = "src/main.cc", // [!code focus]
        }, // [!code focus]
        .flags = &.{}, // [!code focus]
    }); // [!code focus]

    // 链接C++ 标准库 // [!code focus]
    exe.linkLibCpp(); // [!code focus]

    // 链接系统库 ncurses // [!code focus]
    exe.linkSystemLibrary("ncurses"); // [!code focus]

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);

    // 创建一个运行
    const run_cmd = b.addRunArtifact(exe);

    // 依赖于构建
    run_cmd.step.dependOn(b.getInstallStep());

    // 运行时参数传递
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // 运行的 step
    const run_step = b.step("run", "Run the app");
    // 依赖于前面的运行
    run_step.dependOn(&run_cmd.step);
}
```

```cpp [main.cc]
#include <ctime>
#include <curses.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

// block layout is: {w-1,h-1}{x0,y0}{x1,y1}{x2,y2}{x3,y3} (two bits each)
int x = 431424, y = 598356, r = 427089, px = 247872, py = 799248, pr,
    c = 348480, p = 615696, tick, board[20][10],
    block[7][4] = {{x, y, x, y},
                   {r, p, r, p},
                   {c, c, c, c},
                   {599636, 431376, 598336, 432192},
                   {411985, 610832, 415808, 595540},
                   {px, py, px, py},
                   {614928, 399424, 615744, 428369}},
    score = 0;

// extract a 2-bit number from a block entry
int NUM(int x, int y) { return 3 & block[p][x] >> y; }

// create a new piece, don't remove old one (it has landed and should stick)
void new_piece() {
  y = py = 0;
  p = rand() % 7;
  r = pr = rand() % 4;
  x = px = rand() % (10 - NUM(r, 16));
}

// draw the board and score
void frame() {
  for (int i = 0; i < 20; i++) {
    move(1 + i, 1); // otherwise the box won't draw
    for (int j = 0; j < 10; j++) {
      board[i][j] && attron(262176 | board[i][j] << 8);
      printw("  ");
      attroff(262176 | board[i][j] << 8);
    }
  }
  move(21, 1);
  printw("Score: %d", score);
  refresh();
}

// set the value fo the board for a particular (x,y,r) piece
void set_piece(int x, int y, int r, int v) {
  for (int i = 0; i < 8; i += 2) {
    board[NUM(r, i * 2) + y][NUM(r, (i * 2) + 2) + x] = v;
  }
}

// move a piece from old (p*) coords to new
void update_piece() {
  set_piece(px, py, pr, 0);
  set_piece(px = x, py = y, pr = r, p + 1);
}

// remove line(s) from the board if they're full
void remove_line() {
  for (int row = y; row <= y + NUM(r, 18); row++) {
    c = 1;
    for (int i = 0; i < 10; i++) {
      c *= board[row][i];
    }
    if (!c) {
      continue;
    }
    for (int i = row - 1; i > 0; i--) {
      memcpy(&board[i + 1][0], &board[i][0], 40);
    }
    memset(&board[0][0], 0, 10);
    score++;
  }
}

// check if placing p at (x,y,r) will be a collision
int check_hit(int x, int y, int r) {
  if (y + NUM(r, 18) > 19) {
    return 1;
  }
  set_piece(px, py, pr, 0);
  c = 0;
  for (int i = 0; i < 8; i += 2) {
    board[y + NUM(r, i * 2)][x + NUM(r, (i * 2) + 2)] && c++;
  }
  set_piece(px, py, pr, p + 1);
  return c;
}

// slowly tick the piece y position down so the piece falls
int do_tick() {
  if (++tick > 30) {
    tick = 0;
    if (check_hit(x, y + 1, r)) {
      if (!y) {
        return 0;
      }
      remove_line();
      new_piece();
    } else {
      y++;
      update_piece();
    }
  }
  return 1;
}

// main game loop with wasd input checking
void runloop() {
  while (do_tick()) {
    usleep(10000);
    if ((c = getch()) == 'a' && x > 0 && !check_hit(x - 1, y, r)) {
      x--;
    }
    if (c == 'd' && x + NUM(r, 16) < 9 && !check_hit(x + 1, y, r)) {
      x++;
    }
    if (c == 's') {
      while (!check_hit(x, y + 1, r)) {
        y++;
        update_piece();
      }
      remove_line();
      new_piece();
    }
    if (c == 'w') {
      ++r %= 4;
      while (x + NUM(r, 16) > 9) {
        x--;
      }
      if (check_hit(x, y, r)) {
        x = px;
        r = pr;
      }
    }
    if (c == 'q') {
      return;
    }
    update_piece();
    frame();
  }
}

// init curses and start runloop
int main() {
  srand(time(0));
  initscr();
  start_color();
  // colours indexed by their position in the block
  for (int i = 1; i < 8; i++) {
    init_pair(i, i, 0);
  }
  new_piece();
  resizeterm(22, 22);
  noecho();
  timeout(0);
  curs_set(0);
  box(stdscr, 0, 0);
  runloop();
  endwin();
}
```

:::

::: info 🅿️ 提示

关于头文件的引入，可以使用 `exe.addIncludePath(.{ .path = "path" });`

针对多个 C 源代码文件，zig 提供了函数 `exe.addCSourceFiles` 用于便捷地添加多个源文件。

:::

::: warning 关于 `libc++` 的问题

zig 的工具链使用的是 `libc++`（LLVM ABI），而GNU的则是 `libstdc++`，两者的标准库实现略有不同，这会导致混用可能出现问题！

正确的做法是，手动编译依赖的源代码（一般是出现问题的），或者使用 `-nostdinc++ -nostdlib++` 指示不使用默认标准库，并链接 GNU 的标准库，具体可以参考该 [issue](https://github.com/ziglang/zig/issues/18300)。

:::

### 文件生成

TODO
