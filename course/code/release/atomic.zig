pub fn main() !void {
    // #region atomic_value
    const std = @import("std");
    const RefCount = struct {
        count: std.atomic.Value(usize),
        dropFn: *const fn (*RefCount) void,

        const RefCount = @This();

        fn ref(rc: *RefCount) void {
            // no synchronization necessary; just updating a counter.
            _ = rc.count.fetchAdd(1, .monotonic);
        }

        fn unref(rc: *RefCount) void {
            // release ensures code before unref() happens-before the
            // count is decremented as dropFn could be called by then.
            if (rc.count.fetchSub(1, .release) == 1) {
                // seeing 1 in the counter means that other unref()s have happened,
                // but it doesn't mean that uses before each unref() are visible.
                // The load acquires the release-sequence created by previous unref()s
                // in order to ensure visibility of uses before dropping.
                _ = rc.count.load(.acquire);
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
