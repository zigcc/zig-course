pub fn main() void {
    // #region type
    // 下划线可以放在数字之间作为视觉分隔符
    const one_billion = 1_000_000_000;
    const binary_mask = 0b1_1111_1111;
    const permissions = 0o7_5_5;
    const big_address = 0xFF80_0000_0000_0000;
    // #endregion type

    _ = one_billion;
    _ = binary_mask;
    _ = permissions;
    _ = big_address;

    {
        // #region float
        const std = @import("std");

        const inf = std.math.inf(f32);
        const negative_inf = -std.math.inf(f64);
        const nan = std.math.nan(f128);
        // #endregion float

        _ = inf;
        _ = negative_inf;
        _ = nan;
    }
}
