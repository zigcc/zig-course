const std = @import("std");

pub fn main() !void {
    var out = std.io.getStdOut().writer();
    var err = std.io.getStdErr().writer();

    try out.print("Hello {s}!\n", .{"out"});
    try err.print("Hello {s}!\n", .{"err"});
}
