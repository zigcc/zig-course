// #region Defer
const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    defer print("exec third\n", .{});

    if (false) {
        defer print("will not exec\n", .{});
    }

    defer {
        print("exec second\n", .{});
    }
    defer {
        print("exec first\n", .{});
    }
}
// #endregion Defer
