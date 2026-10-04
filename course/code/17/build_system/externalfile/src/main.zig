const std = @import("std");
const hello = @embedFile("hello");

pub fn main() !void {
    std.debug.print("{s}", .{hello});
}
