const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);

    // zig 提供了一个方便的函数允许我们直接运行构建结果
    const run_exe = b.addRunArtifact(exe);

    // 注意：该步骤可选，显式声明运行依赖于构建
    // 这会使运行是从构建输出目录（默认为 zig-out/bin ）运行而不是构建缓存中运行
    // 不过，如果应用程序运行依赖于其他已存在的文件（例如某些 ini 配置文件）
    // 这可以确保它们正确的运行
    run_exe.step.dependOn(b.getInstallStep());

    // 注意：此步骤可选
    // 此操作允许用户通过构建系统的命令传递参数，例如 zig build  -- arg1 arg2
    // 当前是将参数传递给运行构建结果
    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    // 指定一个 step 为 run
    const run_step = b.step("run", "Run the application");

    // 指定该 step 依赖于 run_exe，即实际的运行
    run_step.dependOn(&run_exe.step);
}
