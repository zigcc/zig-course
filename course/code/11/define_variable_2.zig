const std = @import("std");

pub fn main() void {
    const constant: u16 = 666;

    std.debug.print("常量 constant 是{}\n", .{constant});
}
