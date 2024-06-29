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

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
