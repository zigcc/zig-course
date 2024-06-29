const std = @import("std");
const ChildProcess = std.process.Child;

const args = [_][]const u8{ "zig", "build" };

const sys = [_][]const u8{
    "basic",
    "cli",
    "docs",
    "embedfile",
    "externalfile",
    "lib",
    "options",
    "step",
    "system_lib",
    "test",
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
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
        .root_source_file = b.path("main.zig"),
        // 实际使用的是resolved_target
        .target = resolved_target,
        .optimize = optimize,
    });
    // #endregion crossTarget

    b.installArtifact(exe);

    for (sys) |name| {
        var child = ChildProcess.init(&args, b.allocator);

        const full_path = try std.process.getCwdAlloc(b.allocator);
        // build cwd
        const cwd = std.fs.path.join(b.allocator, &[_][]const u8{
            full_path,
            name,
        }) catch |err| {
            std.log.err("fmt path for examples failed, err is {}", .{err});
            std.process.exit(1);
        };

        // open entry dir
        const entry_dir = std.fs.openDirAbsolute(cwd, .{}) catch unreachable;
        entry_dir.access("build.zig", .{}) catch {
            std.log.err("not found build.zig in path {s}", .{cwd});
            std.process.exit(1);
        };

        // set child cwd
        // this api maybe changed in the future
        child.cwd = cwd;

        // spawn and wait child process
        _ = child.spawnAndWait() catch unreachable;
    }
}
