const std = @import("std");

pub fn build(b: *std.Build) void {
    const target_query: std.Target.Query = .{
        .os_tag = .windows,
    };
    // const target = b.standardTargetOptions(.{});
    const resolved_target: std.Build.ResolvedTarget = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "echo_tcp_server",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = resolved_target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
