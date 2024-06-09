const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // #region create_module
    const lib_module = b.addModule("package", .{
        .root_source_file = b.path("src/root.zig"),
    });
    _ = lib_module;
    // #endregion create_module

    const lib = b.addStaticLibrary(.{
        .name = "package_management",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    // #region import_module
    // 标准的构建 exe 过程
    const exe = b.addExecutable(.{
        .name = "package_management",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 通过 dependency 函数获取到依赖
    const msgpack = b.dependency("zig-msgpack", .{
        .target = target,
        .optimize = optimize,
    });

    // 将 module 添加到 exe 的 root module 中
    exe.root_module.addImport("msgpack", msgpack.module("msgpack"));
    // #endregion import_module

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
