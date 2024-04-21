const builtin = @import("builtin");
const std = @import("std");
const Build = std.Build;

const current_zig = builtin.zig_version;

const build_11 = @import("build_0.11.zig").build;
const build_12 = @import("build_0.12.zig").build;
const build_13 = @import("build_0.13.zig").build;

pub fn build(b: *Build) void {
    switch (current_zig.minor) {
        11 => build_11(b),
        12 => build_12(b),
        13 => build_13(b),
        else => @compileError("unknown zig version"),
    }
}
