pub fn main() !void {
    try SafeAllocator.main();
    try SmpAllocator.main();
    try BestAllocator.main();
    try FixedBufferAllocator.main();
    try ThreadSafeFixedBufferAllocator.main();
    try ArenaAllocator.main();
    try c_allocator.main();
    try page_allocator.main();
    try BufferFirstAllocator.main();
    try MemoryPool.main();
}

const SafeAllocator = struct {
    // #region SafeAllocator
    const std = @import("std");

    pub fn main() !void {
        // 0.17 使用 SafeAllocator 取代了 DebugAllocator
        // 它需要一个后备分配器（backing allocator），一定要是变量，不能是常量
        var safe: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});
        // 拿到一个allocator
        const allocator = safe.allocator();

        // defer 用于执行 SafeAllocator 善后工作
        defer {
            // deinit 会报告并释放所有泄漏的内存，返回值为泄漏的数量
            const leaks = safe.deinit();

            // 检测是否发生内存泄漏
            if (leaks != 0) @panic("TEST FAIL");
        }

        //申请内存
        const bytes = try allocator.alloc(u8, 100);
        // 延后释放内存
        defer allocator.free(bytes);
    }
    // #endregion SafeAllocator
};

const SmpAllocator = struct {
    // #region SmpAllocator
    const std = @import("std");

    pub fn main() !void {
        // 无需任何初始化，拿来就可以使用
        const allocator = std.heap.smp_allocator;

        //申请内存
        const bytes = try allocator.alloc(u8, 100);
        // 延后释放内存
        defer allocator.free(bytes);
    }
    // #endregion SmpAllocator
};

const FixedBufferAllocator = struct {
    // #region FixedBufferAllocator
    const std = @import("std");

    pub fn main() !void {
        var buffer: [1000]u8 = undefined;
        // 一块内存区域，传入到fixed buffer中
        var fba = std.heap.FixedBufferAllocator.init(&buffer);

        // 获取内存allocator
        const allocator = fba.allocator();

        // 申请内存
        const memory = try allocator.alloc(u8, 100);
        // 释放内存
        defer allocator.free(memory);
    }
    // #endregion FixedBufferAllocator
};

const ThreadSafeFixedBufferAllocator = struct {
    // #region ThreadSafeFixedBufferAllocator
    const std = @import("std");

    pub fn main() !void {
        var buffer: [1000]u8 = undefined;
        // 一块内存区域，传入到fixed buffer中
        var fba = std.heap.FixedBufferAllocator.init(&buffer);

        // 获取内存allocator
        // 通用的 ThreadSafeAllocator 包装器已被移除，
        // FixedBufferAllocator 自身提供了线程安全的分配器接口
        // 注意：不要同时混用 allocator() 和 threadSafeAllocator() 返回的接口
        const allocator = fba.threadSafeAllocator();

        // 申请内存
        const memory = try allocator.alloc(u8, 100);
        // 释放内存
        defer allocator.free(memory);
    }
    // #endregion ThreadSafeFixedBufferAllocator
};

const BestAllocator = struct {
    const std = @import("std");
    const builtin = @import("builtin");
    var safe_allocator: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});

    pub fn main() !void {
        const allocator, const is_debug = allocator: {
            if (builtin.target.os.tag == .wasi) break :allocator .{ std.heap.wasm_allocator, false };
            // 0.17 中优化模式的标签改为 .debug、.safe、.fast、.small
            break :allocator switch (builtin.mode) {
                .debug, .safe => .{ safe_allocator.allocator(), true },
                .fast, .small => .{ std.heap.smp_allocator, false },
            };
        };
        defer if (is_debug) {
            _ = safe_allocator.deinit();
        };
        //申请内存
        const bytes = try allocator.alloc(u8, 100);
        // 延后释放内存
        defer allocator.free(bytes);
    }
};

const ArenaAllocator = struct {
    // #region ArenaAllocator
    const std = @import("std");

    pub fn main() !void {
        // 使用模型，一定要是变量，不能是常量
        var safe: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});
        // 拿到一个allocator
        const allocator = safe.allocator();

        // defer 用于执行 SafeAllocator 善后工作
        defer {
            if (safe.deinit() != 0) @panic("TEST FAIL");
        }

        // 对通用内存分配器进行一层包裹
        var arena = std.heap.ArenaAllocator.init(allocator);

        // defer 最后释放内存
        defer arena.deinit();

        // 获取分配器
        const arena_allocator = arena.allocator();

        _ = try arena_allocator.alloc(u8, 1);
        _ = try arena_allocator.alloc(u8, 10);
        _ = try arena_allocator.alloc(u8, 100);
    }
    // #endregion ArenaAllocator
};

const c_allocator = struct {
    // #region c_allocator
    const std = @import("std");

    pub fn main() !void {
        // 用起来和 C 一样纯粹
        const allocator = std.heap.c_allocator;
        const num = try allocator.alloc(u8, 1);
        defer allocator.free(num);
    }
    // #endregion c_allocator
};

const page_allocator = struct {
    // #region page_allocator
    const std = @import("std");

    pub fn main() !void {
        const allocator = std.heap.page_allocator;
        const memory = try allocator.alloc(u8, 100);
        defer allocator.free(memory);
    }
    // #endregion page_allocator
};

const BufferFirstAllocator = struct {
    // #region buffer_first_allocator
    const std = @import("std");

    pub fn main() !void {
        // 0.17 中 stackFallback 被重做为 BufferFirstAllocator，缓冲区改为由调用者传入
        // 先在栈上准备 256 个字节的缓冲区
        var buffer: [256]u8 = undefined;
        // 优先从缓冲区分配，如果缓冲区不够用，就会使用 page allocator
        var bfa: std.heap.BufferFirstAllocator = .init(&buffer, std.heap.page_allocator);
        // 获取分配器，和其他分配器一样调用 allocator()
        const allocator = bfa.allocator();
        // 申请内存
        const memory = try allocator.alloc(u8, 100);
        // 释放内存
        defer allocator.free(memory);
    }
    // #endregion buffer_first_allocator
};

const MemoryPool = struct {
    // #region MemoryPool
    const std = @import("std");

    pub fn main() !void {
        // 此处为了演示，直接使用page allocator
        // Zig 0.16 起 MemoryPool 使用 .empty 常量初始化
        var pool: std.heap.MemoryPool(u32) = .empty;
        defer pool.deinit(std.heap.page_allocator);

        // 连续申请三个对象
        const p1 = try pool.create(std.heap.page_allocator);
        const p2 = try pool.create(std.heap.page_allocator);
        const p3 = try pool.create(std.heap.page_allocator);

        // 回收p2
        pool.destroy(p2);
        // 再申请一个新的对象
        const p4 = try pool.create(std.heap.page_allocator);

        // 注意，此时p2和p4指向同一块内存
        _ = p1;
        _ = p3;
        _ = p4;
    }
    // #endregion MemoryPool
};

test "allocators" {
    try SafeAllocator.main();
    try SmpAllocator.main();
    try BestAllocator.main();
    try FixedBufferAllocator.main();
    try ThreadSafeFixedBufferAllocator.main();
    try ArenaAllocator.main();
    try c_allocator.main();
    try page_allocator.main();
    try BufferFirstAllocator.main();
    try MemoryPool.main();
}
