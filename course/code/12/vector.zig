pub fn main() !void {
    Basic.main();
    Splat.main();
    Reduce.main();
    Shuffle.main();
    Select.main();
}

const Basic = struct {
    // #region basic
    const std = @import("std");
    const print = std.debug.print;

    pub fn main() void {
        const ele_4 = @Vector(4, i32);

        // 向量必须拥有编译期已知的长度和类型
        const a = ele_4{ 1, 2, 3, 4 };
        const b = ele_4{ 5, 6, 7, 8 };

        // 执行相加的操作
        const c = a + b;

        print("Vector c is {any}\n", .{c});
        // 以数组索引的语法来访问向量的元素
        print("the third element of Vector c is {}\n", .{c[2]});

        // 定义一个数组，注意我们这里使用的是浮点类型
        var arr1: [4]f32 = [_]f32{ 1.1, 3.2, 4.5, 5.6 };
        // 直接转换成为一个向量
        const vec: @Vector(4, f32) = arr1;

        print("Vector vec is {any}\n", .{vec});

        // 将一个切片转换为向量
        const vec2: @Vector(2, f32) = arr1[1..3].*;
        print("Vector vec2 is {any}\n", .{vec2});
    }
    // #endregion basic
};

const Splat = struct {
    pub fn main() void {
        // #region splat
        const scalar: u32 = 5;
        const result: @Vector(4, u32) = @splat(scalar);
        // #endregion splat
        _ = result;
    }
};

const Reduce = struct {
    const std = @import("std");
    const print = std.debug.print;

    pub fn main() void {
        // #region reduce
        const V = @Vector(4, i32);
        const value = V{ 1, -1, 1, -1 };

        const result = value > @as(V, @splat(0));
        // result 是 { true, false, true, false };

        const is_all_true = @reduce(.And, result);
        // is_all_true 是 false
        // #endregion reduce
        print("is_all_true is {}\n", .{is_all_true});
    }
};
const Shuffle = struct {
    const std = @import("std");
    const print = std.debug.print;

    pub fn main() void {
        //#region shuffle
        const a = @Vector(7, u8){ 'o', 'l', 'h', 'e', 'r', 'z', 'w' };
        const b = @Vector(4, u8){ 'w', 'd', '!', 'x' };

        const mask1 = @Vector(5, i32){ 2, 3, 1, 1, 0 };
        const res1: @Vector(5, u8) = @shuffle(u8, a, undefined, mask1);
        // res1 的值是 hello

        // Combining two vectors
        const mask2 = @Vector(6, i32){ -1, 0, 4, 1, -2, -3 };
        const res2: @Vector(6, u8) = @shuffle(u8, a, b, mask2);
        // res2 的值是 world!
        //#endregion shuffle
        _ = res1;
        _ = res2;
    }
};

const Select = struct {
    pub fn main() void {

        //#region select
        const ele_4 = @Vector(4, i32);

        // 向量必须拥有编译期已知的长度和类型
        const a = ele_4{ 1, 2, 3, 4 };
        const b = ele_4{ 5, 6, 7, 8 };

        const pred = @Vector(4, bool){
            true,
            false,
            false,
            true,
        };

        const c = @select(i32, pred, a, b);
        // c 是 { 1, 6, 7, 4 }
        //#endregion select

        _ = c;
    }
};
