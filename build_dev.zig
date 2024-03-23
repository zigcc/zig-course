const std = @import("std");
const Build = std.Build;
const ChildProcess = std.ChildProcess;

const log = std.log.scoped(.For_dev);

const args = [_][]const u8{ "zig", "build" };

const latest_release_minor_version = "11";
const latest_dev_minor_version = "12";

const relative_path_release = "course/code/" ++ latest_release_minor_version;
const relative_path_dev = "course/code/" ++ latest_dev_minor_version;

pub fn build_dev(b: *Build) void {
    // get target and optimize
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // get rlease path and dev path
    var lazy_path_release = Build.LazyPath{ .path = relative_path_release };
    var lazy_path_dev = Build.LazyPath{ .path = relative_path_dev };

    // get absolute path
    const full_path_release = lazy_path_release.getPath(b);
    const full_path_dev = lazy_path_dev.getPath(b);

    // open release dir
    var dir_release = std.fs.openDirAbsolute(full_path_release, .{ .iterate = true }) catch |err| {
        log.err("open release path failed, err is {}", .{err});
        std.process.exit(1);
    };
    defer dir_release.close();

    // open dev dir
    var dir_dev = std.fs.openDirAbsolute(full_path_dev, .{}) catch |err| {
        log.err("open dev path failed, err is {}", .{err});
        std.process.exit(1);
    };
    defer dir_dev.close();

    // make a iterate for release ath
    var iterate_release = dir_release.iterate();

    while (iterate_release.next()) |val| {
        if (val) |entry| {
            // get the entry name, entry can be file or directory
            const name = entry.name;
            if (entry.kind == .file) {
                // This variable records whether the corresponding file exists in the dev folder
                var is_there_dev: bool = true;
                dir_dev.access(name, .{}) catch {
                    log.info("file {s} not dev version", .{name});
                    is_there_dev = false;
                };

                // connect path
                const path = std.fs.path.join(b.allocator, &[_][]const u8{ if (is_there_dev) relative_path_dev else relative_path_release, name }) catch |err| {
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
                // This variable records whether there is a corresponding folder in the dev folder
                var is_there_dev: bool = true;
                dir_dev.access(name, .{}) catch {
                    log.info("directory {s} not dev version", .{name});
                    is_there_dev = false;
                };

                // build child process
                var child = ChildProcess.init(&args, b.allocator);

                // build cwd
                const cwd = std.fs.path.join(b.allocator, &[_][]const u8{
                    if (is_there_dev) full_path_dev else full_path_release,
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
