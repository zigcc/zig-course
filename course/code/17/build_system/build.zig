const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const io = b.graph.io;
    // #region crossTarget
    // 构建一个target
    const target_query = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    };

    const ResolvedTarget = std.Build.ResolvedTarget;

    // 解析的target
    const resolved_target: ResolvedTarget = b.resolveTargetQuery(target_query);

    // 解析结果
    const target: std.Target = resolved_target.result;
    _ = target;

    // 构建 exe
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_module = b.addModule("zig", .{
            .root_source_file = b.path("main.zig"),
            // 实际使用的是resolved_target
            .target = resolved_target,
            .optimize = optimize,
        }),
    });
    // #endregion crossTarget

    b.installArtifact(exe);

    // 0.17 起 configure 阶段的结果会被缓存，遍历目录前需要声明对目录内容的依赖
    b.dependOnDirectoryContents(b.path("."));

    // `b.root` 是当前构建根目录（Cache.Path），取代了旧的 `b.build_root`
    var dir = try b.root.openDir(io, ".", .{ .iterate = true });
    defer dir.close(io);

    var iterate = dir.iterate();
    while (try iterate.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        if (entry.name[0] == '.' or std.mem.eql(u8, entry.name, "zig-out")) continue;

        // 0.17 将 configure 与 make 拆成了两个进程，不能再在 build 函数中直接 spawn 子进程，
        // 而是把子项目的 `zig build` 声明为 Run 步骤，交给 make 阶段执行
        const sub_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
        sub_build.setName(b.fmt("zig build ({s})", .{entry.name}));
        sub_build.setCwd(b.path(entry.name));
        sub_build.stdio = .inherit;
        b.getInstallStep().dependOn(&sub_build.step);

        // 演示单元测试的子项目额外执行一次 `zig build test`，确保示例中的测试代码同样能通过
        if (std.mem.eql(u8, entry.name, "test")) {
            const sub_test = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "test" });
            sub_test.setName(b.fmt("zig build test ({s})", .{entry.name}));
            sub_test.setCwd(b.path(entry.name));
            sub_test.stdio = .inherit;
            sub_test.step.dependOn(&sub_build.step);
            b.getInstallStep().dependOn(&sub_test.step);
        }
    }
}
