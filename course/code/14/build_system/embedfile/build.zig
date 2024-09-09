const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addAnonymousImport(
        "hello",
        .{ .root_source_file = b.path("src/hello.txt") },
    );

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
