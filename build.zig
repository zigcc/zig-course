const builtin = @import("builtin");
const std = @import("std");
const Build = std.Build;

const current_zig = builtin.zig_version;

const build_release = @import("build_release.zig").build_release;
const build_dev = @import("build_dev.zig").build_dev;

pub fn build(b: *Build) void {
    if (current_zig.minor == 11) {
        build_release(b);
    } else if (current_zig.minor == 12) {
        build_dev(b);
    }
}
