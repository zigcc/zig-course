const std = @import("std");

// #region import_gsl
const gsl = @cImport({
    @cInclude("gsl/gsl_fft_complex.h");
});
// #endregion import_gsl

pub fn main() !void {
    const n = 8;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // #region use_gsl_fft
    // [实数0,虚数0,实数1,虚数1,实数2,虚数2,...]
    var data: []f64 = try allocator.alloc(f64, n * 2);
    // 虚数恒为0，实数为0,1,2,...
    for (0..n) |i| data[i * 2] = @floatFromInt(i);
    // 快速离散傅里叶变换
    _ = gsl.gsl_fft_complex_radix2_forward(data.ptr, 1, n);
    // 输出结果
    try std.io.getStdOut().writer().print("\n{any}\n", .{data});
    // #endregion use_gsl_fft
}
