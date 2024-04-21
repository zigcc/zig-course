const std = @import("std");
const Build = std.Build;
const ChildProcess = std.ChildProcess;

const log = std.log.scoped(.For_0_12_0);

const args = [_][]const u8{ "zig", "build" };

const version = "12";

const relative_path = "course/code/" ++ version;

pub fn build(b: *Build) void {
    // get target and optimize
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var lazy_path = Build.LazyPath{ .path = relative_path };

    const full_path = lazy_path.getPath(b);

    // open dir
    var dir = std.fs.openDirAbsolute(full_path, .{ .iterate = true }) catch |err| {
        log.err("open 12 path failed, err is {}", .{err});
        std.process.exit(1);
    };
    defer dir.close();

    // make a iterate for release ath
    var iterate = dir.iterate();

    while (iterate.next()) |val| {
        if (val) |entry| {
            // get the entry name, entry can be file or directory
            const name = entry.name;
            if (entry.kind == .file) {

                // connect path
                const path = std.fs.path.join(b.allocator, &[_][]const u8{ relative_path, name }) catch |err| {
                    log.err("fmt path for examples failed, err is {}", .{err});
                    std.process.exit(1);
                };

                // build exe
                const exe = b.addExecutable(.{
                    .name = name,
                    .root_source_file = .{ .path = path },
                    .target = target,
                    .optimize = optimize,
                });
                exe.linkLibC();

                // add to default install
                b.installArtifact(exe);

                // build test
                const unit_tests = b.addTest(.{
                    .root_source_file = .{ .path = path },
                    .target = target,
                    .optimize = optimize,
                });

                // add to default install
                b.getInstallStep().dependOn(&b.addRunArtifact(unit_tests).step);
            } else if (entry.kind == .directory) {

                // build child process
                var child = ChildProcess.init(&args, b.allocator);

                // build cwd
                const cwd = std.fs.path.join(b.allocator, &[_][]const u8{
                    full_path,
                    name,
                }) catch |err| {
                    log.err("fmt path for examples failed, err is {}", .{err});
                    std.process.exit(1);
                };

                // open entry dir
                const entry_dir = std.fs.openDirAbsolute(cwd, .{}) catch unreachable;
                entry_dir.access("build.zig", .{}) catch {
                    log.err("not found build.zig in path {s}", .{cwd});
                    std.process.exit(1);
                };

                // set child cwd
                // this api maybe changed in the future
                child.cwd = cwd;

                // spawn and wait child process
                _ = child.spawnAndWait() catch unreachable;
            }
        } else {
            // Stop endless loop
            break;
        }
    } else |err| {
        log.err("iterate examples_path failed, err is {}", .{err});
        std.process.exit(1);
    }
}
