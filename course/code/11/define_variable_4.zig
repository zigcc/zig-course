// #region top-level
//! 顶层文档注释
//! 顶层文档注释

const S = struct {
    //! 顶层文档注释
};
// #endregion top-level

// #region doc-comment
/// 存储时间戳的结构体，精度为纳秒
/// (像这里就是多行文档注释)
const Timestamp = struct {
    /// 自纪元开始后的秒数 (此处也是一个文档注释).
    seconds: i64, // 我们可以以此代表1970年前 (此处是普通注释)

    /// 纳秒数 (文档注释).
    nanos: u32,

    /// 返回一个 Timestamp 结构体代表 unix 纪元;
    /// 1970年 1月1日 00:00:00 UTC (文档注释).
    pub fn unixEpoch() Timestamp {
        return Timestamp{
            .seconds = 0,
            .nanos = 0,
        };
    }
};
// #endregion doc-comment

pub fn main() void {
    _ = Timestamp{
        .seconds = 0,
        .nanos = 0,
    }; // autofix
}
