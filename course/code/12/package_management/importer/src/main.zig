const std = @import("std");
const pe = @import("path_exporter");
const te = @import("tarball_exporter");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const str2: te.Str = .{ .str = "2" };

    try stdout.print(
        \\Result of 1 + 1
        \\Path-Exporter: {}
        \\Tarball-Expoter: {s}
    , .{
        pe.add(1, 1),
        str2.value(),
    });
}
