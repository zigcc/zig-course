const std = @import("std");

pub fn build(b: *std.Build) void {
    // 构建目标
    const target = b.standardTargetOptions(.{});

    // 构建优化模式
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.os.tag == .windows) {
        return;
    }

    // 添加一个二进制可执行程序构建
    // 注意：我们在这里并没有使用 root_source_file 字段
    // 该字段是为 zig 源文件准备的
    const exe = b.addExecutable(.{
        .name = "zig",
        .target = target,
        .optimize = optimize,
    });

    // 添加 C 源代码文件，两个参数：
    // 源代码路径（相对于build.zig）
    // 传递的 flags
    // 多个 C 源代码文件可以使用 addCSourceFiles
    exe.addCSourceFile(.{
        .file = b.path("src/main.cc"),
        .flags = &.{},
    });

    // 链接C++ 标准库
    // 同理对于 C 标准库可以使用 linkLibC
    exe.linkLibCpp();

    // 链接系统库 ncurses
    exe.linkSystemLibrary("ncurses");

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
