const std = @import("std");
const Build = std.Build;
const log = std.log.scoped(.For_0_17_0);
const version = "17";

const relative_path = "course/code/" ++ version;

/// 需要链接 libc 的单文件示例，其余示例一律不链接 libc
const libc_examples = [_][]const u8{
    "interact_with_c.zig",
    "memory_manager.zig",
    "pointer.zig",
};

pub fn build(b: *Build) void {
    // get target and optimize
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const io = b.graph.io;

    // 0.17 起 configure 阶段（运行 build.zig 的过程）的结果会被缓存。
    // 这里在 configure 阶段遍历了示例目录，因此需要显式声明对该目录内容的依赖，
    // 这样新增、删除或重命名示例后才会重新执行 configure。
    b.dependOnDirectoryContents(b.path(relative_path));

    // 0.17 移除了 `b.build_root` 与 `LazyPath.getPath`，改用 `b.root`（`Cache.Path`）
    var dir = b.root.openDir(io, relative_path, .{ .iterate = true }) catch |err| {
        log.err("open {s} path failed, err is {t}", .{ relative_path, err });
        std.process.exit(1);
    };
    defer dir.close(io);

    var iterate = dir.iterate();

    while (iterate.next(io) catch |err| {
        log.err("iterate examples_path failed, err is {t}", .{err});
        std.process.exit(1);
    }) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
                addSingleFileExample(b, entry.name, target, optimize);
            },
            .directory => {
                if (entry.name[0] == '.' or std.mem.eql(u8, entry.name, "zig-out")) continue;
                addProjectExample(b, entry.name);
            },
            else => {},
        }
    }
}

/// 单文件示例：编译为可执行文件，并运行其中的单元测试
fn addSingleFileExample(
    b: *Build,
    file_name: []const u8,
    target: Build.ResolvedTarget,
    optimize: std.lang.Optimize,
) void {
    const output_name = file_name[0 .. file_name.len - ".zig".len];
    const path = b.fmt("{s}/{s}", .{ relative_path, file_name });

    const imports: []const Build.Module.Import = if (std.mem.eql(u8, file_name, "interact_with_c.zig")) imports: {
        const c_header = b.addWriteFiles().add("interact_with_c.h",
            \\#define _NO_CRT_STDIO_INLINE 1
            \\#include <stdio.h>
        );
        // `std.Build.Step.TranslateC` 在 0.17 中已被标记为 deprecated，
        // 官方推荐改为依赖 translate-c 包；为了让仓库根构建保持零依赖，这里暂时沿用内置步骤。
        const translate_c = b.addTranslateC(.{
            .root_source_file = c_header,
            .target = target,
            .optimize = optimize,
        });
        break :imports b.allocator.dupe(Build.Module.Import, &.{
            .{ .name = "c", .module = translate_c.createModule() },
        }) catch @panic("OOM");
    } else &.{};

    const link_libc: ?bool = for (libc_examples) |name| {
        if (std.mem.eql(u8, name, file_name)) break true;
    } else null;

    // build exe
    const exe = b.addExecutable(.{
        .name = output_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
            .link_libc = link_libc,
        }),
    });

    // add to default install
    b.installArtifact(exe);

    // build test
    const unit_tests = b.addTest(.{
        .name = b.fmt("{s}_test", .{output_name}),
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
            .link_libc = link_libc,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    // 交叉编译（例如 -Dtarget=x86_64-windows）时跳过无法在宿主机运行的测试
    run_unit_tests.skip_foreign_checks = true;

    // add to default install
    b.getInstallStep().dependOn(&run_unit_tests.step);
}

/// 项目类示例：子目录中带有独立的 build.zig，在 make 阶段执行 `zig build`
///
/// 0.17 将 configure 与 make 拆成了两个进程，configure 结果还会被缓存，
/// 因此不能再像旧版本那样在 build.zig 里直接 spawn 子进程，而要交给 Run 步骤。
fn addProjectExample(b: *Build, dir_name: []const u8) void {
    const sub_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    sub_build.setName(b.fmt("zig build ({s}/{s})", .{ relative_path, dir_name }));
    sub_build.setCwd(b.path(b.fmt("{s}/{s}", .{ relative_path, dir_name })));
    sub_build.stdio = .inherit;

    b.getInstallStep().dependOn(&sub_build.step);
}
