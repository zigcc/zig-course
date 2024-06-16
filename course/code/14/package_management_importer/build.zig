const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "importer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // #region import_module
    // 通过 dependency 函数获取到依赖
    const pe = b.dependency("path-exporter", .{
        .target = target,
        .optimize = optimize,
    });
    const te = b.dependency("tarball-exporter", .{
        .target = target,
        .optimize = optimize,
    });
    // 将 module 添加到 exe 的 root module 中
    exe.root_module.addImport("path_exporter", pe.module("exporter"));
    exe.root_module.addImport("tarball_exporter", te.module("msgpack"));
    // #endregion import_module

    b.installArtifact(exe);
}
