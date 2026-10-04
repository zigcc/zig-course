const std = @import("std");

// 该示例依赖 Windows 下通过 vcpkg 安装的 gsl，仅用于文档展示，默认构建为空操作
pub fn build(_: *std.Build) void {}

const Build = struct {
    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

        // #region translate_c
        // 0.17 移除了 @cImport，内置的 addTranslateC 也已弃用，
        // 推荐使用官方 translate-c 包把 C 头文件翻译为 Zig 模块。
        // 先执行：zig fetch --save git+https://codeberg.org/ziglang/translate-c#2.0.0
        const Translator = @import("translate_c").Translator;
        const translate_c = b.dependency("translate_c", .{});

        const gsl: Translator = .init(translate_c, .{
            // src/gsl.h 中只有一行 #include <gsl/gsl_fft_complex.h>
            .c_source_file = b.path("src/gsl.h"),
            .target = target,
            .optimize = optimize,
        });
        // 翻译阶段同样需要能找到 gsl 的头文件
        gsl.addIncludePath(.{ .cwd_relative = "D:\\vcpkg\\installed\\windows-x64\\include" });
        // #endregion translate_c

        const exe = b.addExecutable(.{
            .name = "c_lib_import_gsl_windows-x64",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                // 把翻译结果作为名为 gsl 的模块导入
                .imports = &.{
                    .{ .name = "gsl", .module = gsl.mod },
                },
            }),
        });

        // #region c_import
        // 增加 lib 搜索目录
        exe.root_module.addLibraryPath(.{ .cwd_relative = "D:\\vcpkg\\installed\\windows-x64\\lib" });
        // 链接标准c库
        exe.root_module.linkSystemLibrary("c", .{});
        // 链接第三方库gsl
        exe.root_module.linkSystemLibrary("gsl", .{});
        // #endregion c_import

        b.installArtifact(exe);
    }
};
