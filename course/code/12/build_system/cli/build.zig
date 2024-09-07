const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 使用 option 来获取命令参数决定是否剥离调试信息
    const is_strip =
        b.option(bool, "is_strip", "whether strip executable") orelse
        false;

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // 设置 exe 的 strip
        .strip = is_strip,
    });

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
