const std = @import("std");

pub fn main() void {
    var variable: u16 = undefined;

    variable = 666;

    std.debug.print("变量 variable 是{}\n", .{variable});
}
