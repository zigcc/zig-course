const std = @import("std");

pub fn build(b: *std.Build) !void {
    const io = b.graph.io;

    // 0.17 起 configure 阶段的结果会被缓存，遍历目录前需要声明对目录内容的依赖
    b.dependOnDirectoryContents(b.path("."));

    // `b.root` 是当前构建根目录（Cache.Path），不依赖命令执行时所在的目录
    var dir = try b.root.openDir(io, ".", .{ .iterate = true });
    defer dir.close(io);

    var iterate = dir.iterate();
    while (try iterate.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        if (entry.name[0] == '.' or std.mem.eql(u8, entry.name, "zig-out")) continue;

        // 每个子目录都应当是一个带 build.zig 的包
        var entry_dir = try dir.openDir(io, entry.name, .{});
        defer entry_dir.close(io);
        entry_dir.access(io, "build.zig", .{}) catch {
            std.debug.panic("not found build.zig in {s}", .{entry.name});
        };

        // 0.17 将 configure 与 make 拆成了两个进程，不能再在 build 函数中直接 spawn 子进程，
        // 而是把子项目的 `zig build` 声明为 Run 步骤，并使用当前正在运行的 zig，交给 make 阶段执行
        const sub_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
        sub_build.setName(b.fmt("zig build ({s})", .{entry.name}));
        sub_build.setCwd(b.path(entry.name));
        sub_build.stdio = .inherit;
        b.getInstallStep().dependOn(&sub_build.step);
    }
}
