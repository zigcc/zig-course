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

    {
        const std = @import("std");
        const print = std.debug.print;

        // #region complex
        const Complex = std.math.Complex(f64);
        const i = Complex.init(0, 1);

        // 虚数单位的平方
        const z1 = i.mul(i);
        print("i * i = ({d:.1},{d:.1})\n", .{ z1.re, z1.im });
        // i * i = (-1.0,0.0)

        // 使用常见函数
        const z2 = std.math.complex.pow(i, Complex.init(2, 0));
        print("pow(i, 2) = ({d:.1},{d:.1})\n", .{ z2.re, z2.im });
        // pow(i, 2) = (-1.0,0.0)

        // 欧拉公式
        const z3 = std.math.complex.exp(i.mul(Complex.init(std.math.pi, 0)));
        print("exp(i, pi) = ({d:.1},{d:.1})\n", .{ z3.re, z3.im });
        // exp(i, pi) = (-1.0,0.0)

        // 共轭复数
        const z4 = Complex.init(1, 2).mul(Complex.init(1, -2));
        print("(1 + 2i) * (1 - 2i) = ({d:.1},{d:.1})\n", .{ z4.re, z4.im });
        // (1 + 2i) * (1 - 2i) = (5.0,0.0)
        // #endregion complex
    }
}
