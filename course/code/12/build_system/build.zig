const std = @import("std");
const ChildProcess = std.process.Child;

const args = [_][]const u8{ "zig", "build" };

const sys = [_][]const u8{
    "basic",
    "cli",
    "docs",
    "lib",
    "options",
    "step",
    "system_lib",
    "test",
};

pub fn build(b: *std.Build) !void {
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
