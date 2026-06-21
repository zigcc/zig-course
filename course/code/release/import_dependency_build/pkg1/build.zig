const std = @import("std");

pub fn build(b: *std.Build) void {
    @import("pkg2").helperFunction(b);
}
