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

    // 此处开始构建单元测试

    // 构建一个单元测试的 Compile
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 执行单元测试
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // 如果想要跳过外部来自于其他包的单元测试（例如依赖中的包）
    // 可以使用 skip_foreign_checks
    run_exe_unit_tests.skip_foreign_checks = true;

    // 构建一个 step，用于执行测试
    const test_step = b.step("test", "Run unit tests");

    // 测试 step 依赖上方构建的 run_exe_unit_tests
    test_step.dependOn(&run_exe_unit_tests.step);
}
