pub fn main() !void {
    try CHAR.main();
}

const CHAR = struct {
    const print = @import("std").debug.print;
    const expect = @import("std").testing.expect;

    pub fn main() !void {
        // #region char
        // 格式化时，可以使用 u 输出对应的字符
        const me_zh = '我';
        print("{0u} = {0x}\n", .{me_zh}); // 我 = 6211

        // 如果是 ASCII 字符，还可以使用 c 进行格式化
        const me_en = 'I';
        print("{0u} = {0c} = {0x}\n", .{me_en}); // I = I = 49

        // 下面的写法会报错，因为这些 emoji 虽然看上去只有一个字，但其实需要由多个码位组合而成
        // const hand = '🖐🏽';
        // const flag = '🇨🇳';
        // #endregion char

        // #region string-literal
        // 存储的是 UTF-8 编码序列
        const bytes = "Hello, 世界！";

        print("{}\n", .{@TypeOf(bytes)}); // *const [16:0]u8
        print("{}\n", .{bytes.len}); // 16

        // 通过索引访问到的是 UTF-8 编码序列中的字节
        // 由于 UTF-8 兼容 ASCII，所以可以直接打印 ASCII 字符
        print("{c}\n", .{bytes[1]}); // 'e'

        // “世”字的 UTF-8 编码为 E4 B8 96
        try expect(bytes[7] == 0xE4);
        try expect(bytes[8] == 0xB8);
        try expect(bytes[9] == 0x96);

        // 以 NUL 结尾
        print("{d}\n", .{bytes[16]}); // 0

        // #endregion string-literal

        // #region multiline-string-literal
        // “我”字的 UTF-8 编码为 E6 88 91
        const string =
            \\I
            \\我
        ;
        try expect(string[0] == 'I');
        try expect(string[1] == '\n');
        try expect(string[2] == 0xE6);
        try expect(string[3] == 0x88);
        try expect(string[4] == 0x91);
        try expect(string[5] == 0);
        try expect(string.len == 5);

        // #endregion multiline-string-literal
    }
};
