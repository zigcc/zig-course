const builtin = @import("builtin");
const std = @import("std");
const Build = std.Build;

const current_zig = builtin.zig_version;

pub fn build(b: *Build) void {
    switch (current_zig.minor) {
        11 => @import("build/0.11.zig").build(b),
        12 => @import("build/0.12.zig").build(b),
        13 => @import("build/0.13.zig").build(b),
        14 => @import("build/0.14.zig").build(b),
        else => @compileError("unknown zig version"),
    }
}
