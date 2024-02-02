const std = @import("std");

pub fn main() void {
    // 声明变量 variable 类型为u16, 并指定值为 666
    var variable: u16 = 0;
    variable = 666;

    std.debug.print("变量 variable 是{}\n", .{variable});
}
