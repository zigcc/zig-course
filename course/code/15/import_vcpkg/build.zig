const std = @import("std");
pub fn build(_: *std.Build) void {}

const Build = struct {
    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

        const exe = b.addExecutable(.{
            .name = "c_lib_import_gsl_windows-x64",
            .root_source_file = b.path("c_lib_import_gsl_fft.zig"),
            .target = target,
            .optimize = optimize,
        });

        // #region c_import
        // 增加 include 搜索目录
        exe.addIncludePath(.{ .cwd_relative = "D:\\vcpkg\\installed\\windows-x64\\include" });
        // 增加 lib 搜索目录
        exe.addLibraryPath(.{ .cwd_relative = "D:\\vcpkg\\installed\\windows-x64\\lib" });
        // 链接标准c库
        exe.linkLibC();
        // 链接第三方库gsl
        exe.linkSystemLibrary("gsl");
        // #endregion c_import

        b.installArtifact(exe);
    }
};
