const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的构建目标，支持我们从命令行构建时指定构建目标（架构、系统、abi等等）
    const target = b.standardTargetOptions(.{});

    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 尝试添加一个静态库
    const lib = b.addLibrary(.{ .name = "example", .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    }) });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibrary(lib);

    b.installArtifact(exe);
}
