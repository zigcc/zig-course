const std = @import("std");
const Build = std.Build;

const log = std.log.scoped(.For_11);

pub fn build_11(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var lazy_path = Build.LazyPath{
        .path = "11",
    };

    const path_11 = lazy_path.getPath(b);
    var iter_dir =
        std.fs.openIterableDirAbsolute(path_11, .{}) catch |err| {
        log.err("open 11 path failed, err is {}", .{err});
        std.os.exit(1);
    };
    defer iter_dir.close();

    var itera = iter_dir.iterate();

    while (itera.next()) |ff| {
        if (ff) |entry| {
            if (entry.kind == .file) {
                const name = entry.name;
                const path = std.fmt.allocPrint(b.allocator, "11/{s}", .{name}) catch |err| {
                    log.err("fmt path for examples failed, err is {}", .{err});
                    std.os.exit(1);
                };

                const exe = b.addExecutable(.{
                    .name = name,
                    .root_source_file = .{ .path = path },
                    .target = target,
                    .optimize = optimize,
                });

                b.installArtifact(exe);

                const unit_tests = b.addTest(.{
                    .root_source_file = .{ .path = path },
                    .target = target,
                    .optimize = optimize,
                });

                b.getInstallStep().dependOn(&b.addRunArtifact(unit_tests).step);
            } else if (entry.kind == .directory) {
                const name = entry.name;
                const ChildProcess = std.ChildProcess;
                const args = [_][]const u8{ "zig", "build" };
                var child = ChildProcess.init(&args, b.allocator);

                const cwd = std.fmt.allocPrint(b.allocator, "{s}/{s}", .{
                    path_11,
                    name,
                }) catch |err| {
                    log.err("fmt path for examples failed, err is {}", .{err});
                    std.os.exit(1);
                };

                const dd = std.fs.openDirAbsolute(cwd, .{}) catch unreachable;
                const file = dd.openFile("build.zig", .{}) catch {
                    log.err("not found build.zig in path {s}", .{cwd});
                    std.os.exit(1);
                };

                file.close();

                child.cwd = cwd;

                child.spawn() catch unreachable;

                _ = child.wait() catch unreachable;
            }
        } else {
            break;
        }
    } else |err| {
        log.err("iterate examples_path failed, err is {}", .{err});
        std.os.exit(1);
    }
}
