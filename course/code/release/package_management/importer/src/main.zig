const std = @import("std");
const pe = @import("path_exporter");
const te = @import("tarball_exporter");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\Result of 1 + 1
        \\Local-Exporter: {}
        \\Web-Expoter: {}
    , .{
        pe.add(1, 1),
        te.add(1, 1),
    });
}
