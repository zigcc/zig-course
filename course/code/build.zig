const builtin = @import("builtin");
const std = @import("std");
const Build = std.Build;

const current_zig = builtin.zig_version;

const build_11 = @import("build_11.zig").build_11;
const build_12 = @import("build_12.zig").build_12;

pub fn build(b: *Build) void {
    if (current_zig.minor == 11) {
        build_11(b);
    } else if (current_zig.minor == 12) {
        build_12(b);
    }
}
