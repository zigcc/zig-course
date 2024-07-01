pub fn main() !void {
    // #region atomic_value
    const std = @import("std");
    const RefCount = struct {
        count: std.atomic.Value(usize),
        dropFn: *const fn (*RefCount) void,

        const RefCount = @This();

        fn ref(rc: *RefCount) void {
            _ = rc.count.fetchAdd(1, .monotonic);
        }

        fn unref(rc: *RefCount) void {
            if (rc.count.fetchSub(1, .release) == 1) {
                rc.count.fence(.acquire);
                (rc.dropFn)(rc);
            }
        }

        fn noop(rc: *RefCount) void {
            _ = rc;
        }
    };

    var ref_count: RefCount = .{
        .count = std.atomic.Value(usize).init(0),
        .dropFn = RefCount.noop,
    };
    ref_count.ref();
    ref_count.unref();
    // #endregion atomic_value

}

test "spinLoopHint" {
    const std = @import("std");
    // #region spinLoopHint
    for (0..10) |_| {
        std.atomic.spinLoopHint();
    }
    // #endregion spinLoopHint
}
