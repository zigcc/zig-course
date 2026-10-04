const std = @import("std");

// #region import_gsl
// 0.17 移除了 @cImport，gsl 头文件在 build.zig 中由 translate-c 翻译为模块
const gsl = @import("gsl");
// #endregion import_gsl

pub fn main(init: std.process.Init) !void {
    const n = 8;

    const allocator = init.arena.allocator();

    // #region use_gsl_fft
    // [实数0,虚数0,实数1,虚数1,实数2,虚数2,...]
    var data: []f64 = try allocator.alloc(f64, n * 2);
    @memset(data, 0);
    // 虚数恒为0，实数为0,1,2,...
    for (0..n) |i| data[i * 2] = @floatFromInt(i);
    // 快速离散傅里叶变换
    _ = gsl.gsl_fft_complex_radix2_forward(data.ptr, 1, n);
    // 输出结果
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("\n{any}\n", .{data});
    try stdout.flush();
    // #endregion use_gsl_fft
}
