pub fn main() !void {
    // #region unreachable
    const x = 1;
    const y = 2;
    if (x + y != 3) {
        unreachable;
    }
    // #endregion unreachable
}
