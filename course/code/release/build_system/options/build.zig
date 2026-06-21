const std = @import("std");

pub fn build(b: *std.Build) void {
    // 标准构建目标
    const target = b.standardTargetOptions(.{});

    // 标准构建模式
    const optimize = b.standardOptimizeOption(.{});

    // 添加一个二进制可执行程序构建
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // 获取一个简单的时间值用于演示 options 功能
    // 注意：Zig 0.16 移除了 std.time.timestamp()，这里使用示例值
    const timestamp: i64 = 1700000000; // 示例时间戳

    // 创建一个 options
    const options = b.addOptions();

    // 向 options 添加 option, 变量名是time_stamp
    options.addOption(i64, "time_stamp", timestamp);

    // 向 exe 中添加 options
    exe.root_module.addOptions("timestamp", options);

    // 添加到顶级 install step 中作为依赖
    b.installArtifact(exe);
}
