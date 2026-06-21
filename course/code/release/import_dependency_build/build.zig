const std = @import("std");
const args = [_][]const u8{ "zig", "build" };

pub fn build(b: *std.Build) !void {
    const io = b.graph.io;
    const full_path = try std.process.currentPathAlloc(io, b.allocator);
    defer b.allocator.free(full_path);

    var dir = std.Io.Dir.openDirAbsolute(io, full_path, .{ .iterate = true }) catch |err| {
        std.log.err("open path failed {s}, err is {}", .{ full_path, err });
        std.process.exit(1);
    };
    defer dir.close(io);

    var iterate = dir.iterate();

    while (iterate.next(io) catch |err| {
        std.log.err("iterate examples_path failed, err is {}", .{err});
        std.process.exit(1);
    }) |entry| {
        // get the entry name, entry can be file or directory
        const name = entry.name;
        if (entry.kind == .directory) {
            if (eqlu8(name, ".zig-cache") or eqlu8(name, "zig-out") or eqlu8(name, "zig-cache"))
                continue;

            // build cwd
            const cwd = std.fs.path.join(b.allocator, &[_][]const u8{
                full_path,
                name,
            }) catch |err| {
                std.log.err("fmt path failed, err is {}", .{err});
                std.process.exit(1);
            };

            // open entry dir
            const entry_dir = std.Io.Dir.openDirAbsolute(io, cwd, .{}) catch unreachable;
            defer entry_dir.close(io);

            entry_dir.access(io, "build.zig", .{}) catch {
                std.log.err("not found build.zig in path {s}", .{cwd});
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

fn eqlu8(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
