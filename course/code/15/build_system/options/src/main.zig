const std = @import("std");
// timestamp 这个包是通过 build.zig 添加的
const timestamp = @import("timestamp");

pub fn main() !void {
    std.debug.print("build time stamp is {}\n", .{timestamp.time_stamp});
}
