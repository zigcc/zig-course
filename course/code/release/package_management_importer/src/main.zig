const std = @import("std");
const pe = @import("path_exporter");
const te = @import("tarball_exporter");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    const str2: te.Str = .{ .str = "2" };

    try stdout.print(
        \\Result of 1 + 1
        \\Path-Exporter: {}
        \\Tarball-Expoter: {s}
    , .{
        pe.add(1, 1),
        str2.value(),
    });
    try stdout.flush();
}
