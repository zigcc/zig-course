const std = @import("std");

pub fn main(init: std.process.Init) !void {
    try GetIo.main(init);
    try AsyncAwait.main(init);
    try AsyncNotConcurrent.main();
    try Concurrent.main(init);
    try Cancel.main(init);
    try GroupExample.main(init);
    try SelectExample.main(init);
    try MutexExample.main(init);
    try SimIoExample.main(init);
}

const GetIo = struct {
    // #region get_io
    // 方式一：使用 `std.process.Init`，由运行时选好默认的 std.Io 实现
    pub fn mainWithInit(init: std.process.Init) !void {
        const io = init.io;
        try std.Io.File.stdout().writeStreamingAll(io, "hello from init.io\n");
    }

    // 方式二：自己创建一个 std.Io 实现（这里是基于线程池的 `std.Io.Threaded`）
    pub fn mainWithThreaded() !void {
        var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();

        try std.Io.File.stdout().writeStreamingAll(io, "hello from std.Io.Threaded\n");
    }
    // #endregion get_io

    pub fn main(init: std.process.Init) !void {
        try mainWithInit(init);
        try mainWithThreaded();
    }
};

const VTableCall = struct {
    // #region vtable_call
    fn sleepTwice(io: std.Io) !void {
        // 平时的写法
        try io.sleep(.fromMilliseconds(10), .awake);

        // 与上一行完全等价：std.Io.sleep 所做的，只是把参数打包成 Timeout，
        // 再把 userdata 连同参数一起交给 vtable 中的函数
        try io.vtable.sleep(io.userdata, .{ .duration = .{
            .raw = .fromMilliseconds(10),
            .clock = .awake,
        } });
    }
    // #endregion vtable_call
};

const AsyncAwait = struct {
    // #region async_await
    /// 模拟一个耗时的 I/O 操作，例如网络请求
    fn fetch(io: std.Io, id: u32, delay_ms: i64) !u32 {
        try io.sleep(.fromMilliseconds(delay_ms), .awake);
        return id * 10;
    }

    pub fn main(init: std.process.Init) !void {
        // init.io 是运行时为 main 准备的默认 std.Io 实现，即基于线程池的 std.Io.Threaded，
        // 因此下面的两个任务会被分配到不同的线程上同时执行
        const io = init.io;

        const start = std.Io.Clock.awake.now(io);

        // 发起两个异步任务，它们返回 `std.Io.Future(T)`
        var a = io.async(fetch, .{ io, 1, 100 });
        // 无论从哪条路径离开作用域，都要确保任务被取消、资源被回收；
        // 这里有意丢弃 cancel 返回的结果，原因见正文
        defer _ = a.cancel(io) catch {};

        var b = io.async(fetch, .{ io, 2, 100 });
        defer _ = b.cancel(io) catch {};

        // 等待结果；await 是幂等的，之后再调用 cancel 只会直接返回结果
        const ra = try a.await(io);
        const rb = try b.await(io);

        const elapsed = start.untilNow(io, .awake).toMilliseconds();
        std.debug.print("async_await: a = {d}, b = {d}, 耗时约 {d} ms\n", .{ ra, rb, elapsed });
    }
    // #endregion async_await
};

const AsyncNotConcurrent = struct {
    // #region async_not_concurrent
    fn fetch(io: std.Io, id: u32, delay_ms: i64) !u32 {
        try io.sleep(.fromMilliseconds(delay_ms), .awake);
        return id * 10;
    }

    pub fn main() !void {
        // 单线程、阻塞式的 std.Io 实现：不提供任何并发能力
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const start = std.Io.Clock.awake.now(io);

        // 代码和上一个例子完全一样，但 `async` 会直接就地执行函数
        var a = io.async(fetch, .{ io, 1, 50 });
        defer _ = a.cancel(io) catch {};
        var b = io.async(fetch, .{ io, 2, 50 });
        defer _ = b.cancel(io) catch {};

        _ = try a.await(io);
        _ = try b.await(io);

        // 结果依然正确，只不过耗时是两次 sleep 之和
        const elapsed = start.untilNow(io, .awake).toMilliseconds();
        std.debug.print("async_not_concurrent: 耗时约 {d} ms\n", .{elapsed});
    }
    // #endregion async_not_concurrent
};

const Concurrent = struct {
    // #region concurrent
    fn producer(io: std.Io, queue: *std.Io.Queue(u32)) !void {
        // 函数返回时关闭队列，通知消费者不会再有新数据
        defer queue.close(io);
        for (1..11) |i| {
            // 队列满时，putOne 会阻塞，直到消费者取走数据
            try queue.putOne(io, @intCast(i));
        }
    }

    fn consumer(io: std.Io, queue: *std.Io.Queue(u32)) !u32 {
        var sum: u32 = 0;
        while (true) {
            const value = queue.getOne(io) catch |err| switch (err) {
                // 队列已关闭并且数据已经取完
                error.Closed => return sum,
                error.Canceled => |e| return e,
            };
            sum += value;
        }
    }

    pub fn main(init: std.process.Init) !void {
        const io = init.io; // 默认的 std.Io.Threaded，支持真正的并发

        // 队列容量只有 2，生产者和消费者必须“同时”运行才能完成任务
        var buffer: [2]u32 = undefined;
        var queue: std.Io.Queue(u32) = .init(&buffer);

        // concurrent 要求 std.Io 实现必须真正并发地执行任务，否则返回 error.ConcurrencyUnavailable
        var p = try io.concurrent(producer, .{ io, &queue });
        defer p.cancel(io) catch {};
        var c = try io.concurrent(consumer, .{ io, &queue });
        defer _ = c.cancel(io) catch {};

        try p.await(io);
        const sum = try c.await(io);
        std.debug.print("concurrent: sum = {d}\n", .{sum});
    }
    // #endregion concurrent

    // #region concurrent_unavailable
    pub fn unavailable() !void {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        var buffer: [2]u32 = undefined;
        var queue: std.Io.Queue(u32) = .init(&buffer);

        // 单线程实现无法提供并发能力，这里会直接得到错误，而不是死锁
        const result = io.concurrent(producer, .{ io, &queue });
        try std.testing.expectError(error.ConcurrencyUnavailable, result);
    }
    // #endregion concurrent_unavailable
};

const Cancel = struct {
    // #region cancel
    fn slowTask(io: std.Io) !void {
        // sleep 是一个“取消点”（cancelation point）：
        // 当任务被取消时，它会返回 error.Canceled
        try io.sleep(.fromSeconds(10), .awake);
        std.debug.print("这一行不会被执行\n", .{});
    }

    pub fn main(init: std.process.Init) !void {
        const io = init.io; // 默认的 std.Io.Threaded，支持真正的并发
        var task = try io.concurrent(slowTask, .{io});

        try io.sleep(.fromMilliseconds(10), .awake);

        // cancel 会请求取消并等待任务结束，返回任务的结果
        const result = task.cancel(io);
        if (result) |_| {
            std.debug.print("cancel: 任务正常完成\n", .{});
        } else |err| {
            std.debug.print("cancel: 任务结束，结果为 {t}\n", .{err});
        }
    }
    // #endregion cancel

    // #region cancel_protection
    fn criticalSection(io: std.Io) !void {
        // 在这段代码中屏蔽取消请求，保证它能完整地执行完毕
        const old = io.swapCancelProtection(.blocked);
        defer _ = io.swapCancelProtection(old);

        io.sleep(.fromMilliseconds(1), .awake) catch |err| switch (err) {
            // 取消已被屏蔽，不可能收到 error.Canceled
            error.Canceled => unreachable,
        };
    }
    // #endregion cancel_protection
};

const GroupExample = struct {
    // #region group
    fn worker(io: std.Io, id: usize, results: []u64) std.Io.Cancelable!void {
        try io.sleep(.fromMilliseconds(10), .awake);
        // 每个任务只写自己的那一格，因此不需要加锁
        results[id] = id * id;
    }

    pub fn main(init: std.process.Init) !void {
        const io = init.io; // 默认的 std.Io.Threaded，支持真正的并发
        var results: [8]u64 = undefined;

        var group: std.Io.Group = .init;
        // 如果中途出错，取消组内所有任务
        defer group.cancel(io);

        for (0..results.len) |i| {
            group.async(io, worker, .{ io, i, &results });
        }

        // 等待组内全部任务完成
        try group.await(io);

        var sum: u64 = 0;
        for (results) |r| sum += r;
        std.debug.print("group: sum = {d}\n", .{sum});
    }
    // #endregion group
};

const SelectExample = struct {
    // #region select
    fn slowQuery(io: std.Io) std.Io.Cancelable!u32 {
        try io.sleep(.fromSeconds(5), .awake);
        return 42;
    }

    pub fn main(init: std.process.Init) !void {
        const io = init.io; // 默认的 std.Io.Threaded，支持真正的并发

        // 每个字段对应一种任务，字段类型就是对应函数的返回类型
        const Result = union(enum) {
            query: std.Io.Cancelable!u32,
            timeout: std.Io.Cancelable!void,
        };

        var buffer: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(io, &buffer);
        // 取消剩余的任务，并丢弃它们的结果
        defer select.cancelDiscard();

        try select.concurrent(.query, slowQuery, .{io});
        try select.concurrent(.timeout, std.Io.sleep, .{ io, .fromMilliseconds(20), .awake });

        // 等待第一个完成的任务
        switch (try select.await()) {
            .query => |r| std.debug.print("select: 查询结果 {d}\n", .{try r}),
            .timeout => std.debug.print("select: 查询超时\n", .{}),
        }
    }
    // #endregion select
};

const MutexExample = struct {
    // #region mutex
    const Counter = struct {
        mutex: std.Io.Mutex = .init,
        value: u64 = 0,

        fn add(counter: *Counter, io: std.Io, n: u64) std.Io.Cancelable!void {
            // std.Io.Mutex 的加锁同样需要传入 io，并且是一个取消点
            try counter.mutex.lock(io);
            defer counter.mutex.unlock(io);
            counter.value += n;
        }
    };

    fn worker(io: std.Io, counter: *Counter) std.Io.Cancelable!void {
        for (0..1000) |_| try counter.add(io, 1);
    }

    pub fn main(init: std.process.Init) !void {
        const io = init.io; // 默认的 std.Io.Threaded，支持真正的并发
        var counter: Counter = .{};

        var group: std.Io.Group = .init;
        defer group.cancel(io);
        for (0..4) |_| group.async(io, worker, .{ io, &counter });
        try group.await(io);

        std.debug.print("mutex: counter = {d}\n", .{counter.value});
    }
    // #endregion mutex
};

const SimIoExample = struct {
    // #region sim_io
    /// 一个极简的 `std.Io` 实现：
    /// * 标准输入来自一段预设的字符串，标准输出与标准错误写入内存
    /// * 拥有一个“虚拟时钟”，sleep 会立刻返回并把时钟向前拨
    /// * async 直接就地执行（不提供并发），concurrent 返回 error.ConcurrencyUnavailable
    /// * 随机数来自固定种子的伪随机数生成器
    /// 其余所有操作都沿用 `std.Io.failing` 的行为（模拟一个“什么都没有”的系统）。
    const SimIo = struct {
        stdin: []const u8,
        stdout: std.Io.Writer,
        now_ns: i96 = 0,
        prng: std.Random.DefaultPrng = .init(0),
        cancel_protection: std.Io.CancelProtection = .unblocked,

        pub fn init(stdin: []const u8, stdout_buffer: []u8) SimIo {
            return .{ .stdin = stdin, .stdout = .fixed(stdout_buffer) };
        }

        /// 已经写入“虚拟终端”的内容
        pub fn output(sim: *const SimIo) []const u8 {
            return sim.stdout.buffered();
        }

        pub fn io(sim: *SimIo) std.Io {
            return .{ .userdata = sim, .vtable = &vtable };
        }

        // 以 `std.Io.failing` 为模板，只覆盖我们关心的函数
        const vtable: std.Io.VTable = vt: {
            var v = std.Io.failing.vtable.*;
            v.async = std.Io.noAsync; // 就地执行，返回 null 表示结果已经就绪
            v.groupAsync = std.Io.noGroupAsync;
            v.recancel = recancel;
            v.swapCancelProtection = swapCancelProtection;
            v.checkCancel = checkCancel;
            v.operate = operate;
            v.fileWritePositional = fileWritePositional;
            v.fileReadPositional = fileReadPositional;
            v.now = now;
            v.sleep = sleep;
            v.random = random;
            break :vt v;
        };

        fn cast(userdata: ?*anyopaque) *SimIo {
            return @ptrCast(@alignCast(userdata.?));
        }

        // 只有一个任务在运行，也就不会有人来取消它
        fn recancel(_: ?*anyopaque) void {}

        fn swapCancelProtection(userdata: ?*anyopaque, new: std.Io.CancelProtection) std.Io.CancelProtection {
            const sim = cast(userdata);
            defer sim.cancel_protection = new;
            return sim.cancel_protection;
        }

        fn checkCancel(_: ?*anyopaque) std.Io.Cancelable!void {}

        /// 所有“流式”读写最终都会走到这里
        fn operate(userdata: ?*anyopaque, operation: std.Io.Operation) std.Io.Cancelable!std.Io.Operation.Result {
            const sim = cast(userdata);
            switch (operation) {
                .file_write_streaming => |op| {
                    if (op.file.handle != std.Io.File.stdout().handle and
                        op.file.handle != std.Io.File.stderr().handle)
                        return .{ .file_write_streaming = error.NotOpenForWriting };
                    const n = sim.stdout.writeSplatHeader(op.header, op.data, op.splat) catch
                        return .{ .file_write_streaming = error.NoSpaceLeft };
                    return .{ .file_write_streaming = n };
                },
                .file_read_streaming => |op| {
                    if (op.file.handle != std.Io.File.stdin().handle)
                        return .{ .file_read_streaming = error.NotOpenForReading };
                    if (sim.stdin.len == 0)
                        return .{ .file_read_streaming = error.EndOfStream };
                    var n: usize = 0;
                    for (op.data) |buf| {
                        const len = @min(buf.len, sim.stdin.len - n);
                        @memcpy(buf[0..len], sim.stdin[n..][0..len]);
                        n += len;
                    }
                    sim.stdin = sim.stdin[n..];
                    return .{ .file_read_streaming = n };
                },
                else => return std.Io.failingOperate(userdata, operation),
            }
        }

        // 终端不支持定位读写，返回 Unseekable 后，File.Reader/Writer 会自动退回流式模式
        fn fileWritePositional(
            _: ?*anyopaque,
            _: std.Io.File,
            _: []const u8,
            _: []const []const u8,
            _: usize,
            _: u64,
        ) std.Io.File.WritePositionalError!usize {
            return error.Unseekable;
        }

        fn fileReadPositional(
            _: ?*anyopaque,
            _: std.Io.File,
            _: []const []u8,
            _: u64,
        ) std.Io.File.ReadPositionalError!usize {
            return error.Unseekable;
        }

        // 无论哪种时钟，都返回同一个虚拟时间
        fn now(userdata: ?*anyopaque, _: std.Io.Clock) std.Io.Timestamp {
            return .fromNanoseconds(cast(userdata).now_ns);
        }

        // 不真正等待，只是把虚拟时钟拨到超时时刻
        fn sleep(userdata: ?*anyopaque, timeout: std.Io.Timeout) std.Io.Cancelable!void {
            const sim = cast(userdata);
            switch (timeout) {
                // 永远等待：单任务的系统中没有人能唤醒我们
                .none => unreachable,
                .duration => |d| sim.now_ns += d.raw.nanoseconds,
                .deadline => |d| sim.now_ns = @max(sim.now_ns, d.raw.nanoseconds),
            }
        }

        fn random(userdata: ?*anyopaque, buffer: []u8) void {
            cast(userdata).prng.fill(buffer);
        }
    };
    // #endregion sim_io

    // #region sim_io_app
    /// 一段普通的“业务代码”：它只依赖 `std.Io` 接口，并不知道底层是哪种实现
    fn app(io: std.Io) !void {
        var in_buffer: [64]u8 = undefined;
        var stdin_reader = std.Io.File.stdin().reader(io, &in_buffer);
        const stdin = &stdin_reader.interface;

        var out_buffer: [64]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writer(io, &out_buffer);
        const stdout = &stdout_writer.interface;

        const start = std.Io.Clock.awake.now(io);

        // 逐行读取输入，处理后写回输出
        while (try stdin.takeDelimiter('\n')) |line| {
            try io.sleep(.fromSeconds(1), .awake); // 模拟一个耗时的处理过程
            var task = io.async(countVowels, .{line});
            try stdout.print("{s}: {d} vowels\n", .{ line, task.await(io) });
        }

        const elapsed = start.untilNow(io, .awake);
        try stdout.print("elapsed: {d}s\n", .{elapsed.toSeconds()});
        try stdout.flush();
    }

    fn countVowels(text: []const u8) usize {
        var n: usize = 0;
        for (text) |c| {
            if (std.mem.indexOfScalar(u8, "aeiouAEIOU", c) != null) n += 1;
        }
        return n;
    }

    pub fn main(init: std.process.Init) !void {
        var buffer: [256]u8 = undefined;
        var sim: SimIo = .init("hello\nzig\nasync io\n", &buffer);

        // 在模拟系统中运行业务代码：瞬间完成，输出被捕获到内存里
        try app(sim.io());

        // 再用真正的 std.Io 把捕获的结果打印出来
        try std.Io.File.stdout().writeStreamingAll(init.io, sim.output());
    }
    // #endregion sim_io_app
};

test "vtable call" {
    try VTableCall.sleepTwice(std.testing.io);
}

test "async await" {
    const io = std.testing.io;
    var a = io.async(AsyncAwait.fetch, .{ io, 1, 1 });
    defer _ = a.cancel(io) catch {};
    var b = io.async(AsyncAwait.fetch, .{ io, 2, 1 });
    defer _ = b.cancel(io) catch {};
    try std.testing.expectEqual(@as(u32, 10), try a.await(io));
    try std.testing.expectEqual(@as(u32, 20), try b.await(io));
}

test "async without concurrency" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var a = io.async(AsyncNotConcurrent.fetch, .{ io, 1, 1 });
    defer _ = a.cancel(io) catch {};
    try std.testing.expectEqual(@as(u32, 10), try a.await(io));
}

test "concurrent producer consumer" {
    const io = std.testing.io;
    var buffer: [2]u32 = undefined;
    var queue: std.Io.Queue(u32) = .init(&buffer);
    var p = try io.concurrent(Concurrent.producer, .{ io, &queue });
    defer p.cancel(io) catch {};
    var c = try io.concurrent(Concurrent.consumer, .{ io, &queue });
    defer _ = c.cancel(io) catch {};
    try p.await(io);
    try std.testing.expectEqual(@as(u32, 55), try c.await(io));
}

test "concurrent unavailable" {
    try Concurrent.unavailable();
}

test "cancel" {
    const io = std.testing.io;
    var task = try io.concurrent(Cancel.slowTask, .{io});
    try std.testing.expectError(error.Canceled, task.cancel(io));
}

test "cancel protection" {
    try Cancel.criticalSection(std.testing.io);
}

test "group" {
    const io = std.testing.io;
    var results: [8]u64 = undefined;
    var group: std.Io.Group = .init;
    defer group.cancel(io);
    for (0..results.len) |i| group.async(io, GroupExample.worker, .{ io, i, &results });
    try group.await(io);
    for (results, 0..) |r, i| try std.testing.expectEqual(i * i, r);
}

test "select timeout" {
    const io = std.testing.io;
    const Result = union(enum) {
        query: std.Io.Cancelable!u32,
        timeout: std.Io.Cancelable!void,
    };
    var buffer: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(io, &buffer);
    defer select.cancelDiscard();
    try select.concurrent(.query, SelectExample.slowQuery, .{io});
    try select.concurrent(.timeout, std.Io.sleep, .{ io, .fromMilliseconds(1), .awake });
    try std.testing.expect(try select.await() == .timeout);
}

test "mutex" {
    const io = std.testing.io;
    var counter: MutexExample.Counter = .{};
    var group: std.Io.Group = .init;
    defer group.cancel(io);
    for (0..4) |_| group.async(io, MutexExample.worker, .{ io, &counter });
    try group.await(io);
    try std.testing.expectEqual(@as(u64, 4000), counter.value);
}

test "sim io" {
    var buffer: [256]u8 = undefined;
    var sim: SimIoExample.SimIo = .init("hello\nzig\nasync io\n", &buffer);
    const io = sim.io();

    try SimIoExample.app(io);
    try std.testing.expectEqualStrings(
        \\hello: 2 vowels
        \\zig: 1 vowels
        \\async io: 3 vowels
        \\elapsed: 3s
        \\
    , sim.output());

    // 虚拟时钟确实被拨快了 3 秒，但测试本身瞬间完成
    try std.testing.expectEqual(@as(i64, 3), std.Io.Clock.awake.now(io).toSeconds());

    // 不支持并发
    try std.testing.expectError(error.ConcurrencyUnavailable, io.concurrent(SimIoExample.countVowels, .{"x"}));
}
