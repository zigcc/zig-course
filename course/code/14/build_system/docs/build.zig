const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});
    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 构建一个 object，用于生成文档
    const object = b.addObject(.{
        .name = "object",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 创建一个 step
    const docs_step = b.step("docs", "Generate docs");

    // 生成文档
    const docs_install = b.addInstallDirectory(.{
        // 指定文档来源
        .source_dir = object.getEmittedDocs(),
        // 指定安装目录
        .install_dir = .prefix,
        // 指定文档子文件夹
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs_install.step);
}
