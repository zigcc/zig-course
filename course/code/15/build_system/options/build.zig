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

    // 通过标准库获取时间戳
    const timestamp = std.time.timestamp();

    // 创建一个 options
    const options = b.addOptions();

    // 向 options 添加 option, 变量名是time_stamp
    options.addOption(i64, "time_stamp", timestamp);

    // 向 exe 中添加 options
    exe.root_module.addOptions("timestamp", options);

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
