const std = @import("std");
const hello = @embedFile("hello");
// const hello = @embedFile("hello.txt"); 均可以

pub fn main() !void {
    std.debug.print("{s}\n", .{hello});
}
