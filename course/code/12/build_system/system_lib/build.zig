const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的构建目标，支持我们从命令行构建时指定构建目标（架构、系统、abi等等）
    const target = b.standardTargetOptions(.{});

    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zip",
        .root_source_file = b.path("src/main.zig"),
        // 构建目标
        .target = target,
        // 构建模式
        .optimize = optimize,
    });

    if (target.result.os.tag == .windows)
        // 连接到系统的 ole32
        exe.linkSystemLibrary("ole32")
    else
        // 链接到系统的 libz
        exe.linkSystemLibrary("z");

    // 链接到 libc
    exe.linkLibC();

    b.installArtifact(exe);
}
