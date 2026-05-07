const std = @import("std");
const Build = std.Build;
const log = std.log.scoped(.For_0_16_0);
const version = "16";

const args = [_][]const u8{ "zig", "build" };

const relative_path = "course/code/" ++ version;

pub fn build(b: *Build) void {
    // get target and optimize
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const io = b.graph.io;

    var lazy_path = b.path(relative_path);

    const full_path = lazy_path.getPath(b);

    // open dir
    var dir = std.Io.Dir.openDirAbsolute(io, full_path, .{ .iterate = true }) catch |err| {
        log.err("open 16 path failed, err is {}", .{err});
        std.process.exit(1);
    };
    defer dir.close(io);

    // make a iterate for release ath
    var iterate = dir.iterate();

    while (iterate.next(io) catch |err| {
        log.err("iterate examples_path failed, err is {}", .{err});
        std.process.exit(1);
    }) |entry| {
            // get the entry name, entry can be file or directory
            const output_name = if (std.mem.endsWith(u8, entry.name, ".zig"))
                entry.name[0 .. entry.name.len - ".zig".len]
            else
                entry.name;
            if (entry.kind == .file) {
                // connect path
                const path = std.fs.path.join(b.allocator, &[_][]const u8{ relative_path, entry.name }) catch |err| {
                    log.err("fmt path for examples failed, err is {}", .{err});
                    std.process.exit(1);
                };

                // build exe
                const exe = b.addExecutable(.{
                    .name = output_name,
                    .root_module = b.addModule(output_name, .{
                        .root_source_file = b.path(path),
                        .target = target,
                        .optimize = optimize,
                    }),
                });
                exe.root_module.linkSystemLibrary("c", .{});

                if (exe.root_module.resolved_target.?.result.os.tag == .windows and std.mem.eql(u8, "echo_tcp_server.zig", entry.name)) {
                    std.log.info("link ws2_32 for {s}", .{entry.name});
                    exe.root_module.linkSystemLibrary("ws2_32", .{});
                }
                // add to default install
                b.installArtifact(exe);

                // build test
                const test_name = std.fmt.allocPrint(b.allocator, "{s}_test", .{output_name}) catch |err| {
                    log.err("fmt test name failed, err is {}", .{err});
                    std.process.exit(1);
                };
                const unit_tests = b.addTest(.{
                    .root_module = b.addModule(test_name, .{
                        .root_source_file = b.path(path),
                        .target = target,
                        .optimize = optimize,
                    }),
                });

                // add to default install
                b.getInstallStep().dependOn(&b.addRunArtifact(unit_tests).step);
            } else if (entry.kind == .directory) {

                // build child process
                // build cwd
                const cwd = std.fs.path.join(b.allocator, &[_][]const u8{
                    full_path,
                    entry.name,
                }) catch |err| {
                    log.err("fmt path for examples failed, err is {}", .{err});
                    std.process.exit(1);
                };

                // open entry dir
                const entry_dir = std.Io.Dir.openDirAbsolute(io, cwd, .{}) catch unreachable;
                defer entry_dir.close(io);

                entry_dir.access(io, "build.zig", .{}) catch {
                    log.err("not found build.zig in path {s}", .{cwd});
                    std.process.exit(1);
                };

                var child = std.process.spawn(io, .{
                    .argv = &args,
                    .cwd = .{ .path = cwd },
                }) catch unreachable;
                _ = child.wait(io) catch unreachable;
            }
    }
}
