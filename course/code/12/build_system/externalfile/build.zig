const std = @import("std");

pub fn build(b: *std.Build) !void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 在 windows 平台无法使用 bash，故我们直接返回
    if (target.result.os.tag == .windows) {
        return;
    }

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 构建一个运行命令
    const run_sys_cmd = b.addSystemCommand(&.{
        "/bin/sh",
        "-c",
    });

    // 添加参数，此方法允许添加多个参数
    // 也可以使用 addArg 来添加单个参数
    run_sys_cmd.addArgs(&.{
        "echo hello",
    });

    // 尝试运行命令并捕获标准输出
    // 也可以使用 captureStdErr 来捕获标准错误输出
    const output = run_sys_cmd.captureStdOut();

    // 添加一个匿名的依赖
    exe.root_module.addAnonymousImport("hello", .{ .root_source_file = output });

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
