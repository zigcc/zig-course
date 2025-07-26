const std = @import("std");

pub fn build(b: *std.Build) void {
    // 使用默认提供的构建目标，支持我们从命令行构建时指定构建目标（架构、系统、abi等等）
    const target = b.standardTargetOptions(.{});

    // 使用默认提供的优化方案，支持我们从命令行构建时指定构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 尝试添加一个静态库
    const lib = b.addStaticLibrary(.{
        // 库的名字
        .name = "example",
        // 源文件地址
        .root_source_file = b.path("src/root.zig"),
        // 构建目标
        .target = target,
        // 构建模式
        .optimize = optimize,
    });

    // 这代替原本的 lib.install，在构建时自动构建 lib
    // 但其实这是不必要的，因为如果有可执行二进制程序构建使用了 lib，那么它会自动被构建
    b.installArtifact(lib);

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 链接 lib
    exe.linkLibrary(lib);

    // 添加到顶级 install step 中作为依赖，构建 exe
    b.installArtifact(exe);
}
