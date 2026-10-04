// #region opaque
const Derp = opaque {};
const Wat = opaque {};

extern fn bar(d: *Derp) void;
fn foo(w: *Wat) callconv(.c) void {
    bar(w);
}
// #endregion opaque

pub fn main() !void {}
