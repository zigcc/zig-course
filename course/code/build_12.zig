const std = @import("std");
const Build = std.Build;

pub fn build_12(b: *Build) void {
    _ = b;
    // const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});
    //
    // const exe = b.addExecutable(.{
    //     .name = "12",
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // b.installArtifact(exe);
    //
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    //
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
