pub fn main() !void {
    cHeaderImport.main();
}

const cHeaderImport = struct {
    // #region cHeaderImport
    // 使用 build.zig 的 addTranslateC 生成名为 "c" 的模块后导入
    const c = @import("c");
    pub fn main() void {
        _ = c.printf("hello\n");
    }
    // #endregion cHeaderImport
};

const cTranslate = struct {
    // #region cTranslate
    // 使用 build.zig 的 addTranslateC 生成名为 "c" 的模块后导入
    const c = @import("c");
    pub fn main() void {
        _ = c;
    }
    // #endregion cTranslate
};

const external = struct {
    // #region external_func
    // 这是对应 C printf 的声明
    pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;
    // #endregion external_func

    // #region external
    // 使用 callconv 声明函数调用约定为 C
    fn add(count: c_int, ...) callconv(.C) c_int {
        // 对应 C 的宏 va_start
        var ap = @cVaStart();
        // 对应 C 的宏 va_end
        defer @cVaEnd(&ap);
        var i: usize = 0;
        var sum: c_int = 0;
        while (i < count) : (i += 1) {
            // 对应 C 的宏 va_arg
            sum += @cVaArg(&ap, c_int);
        }
        return sum;
    }
    // #endregion external
};
