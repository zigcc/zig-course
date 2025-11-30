pub fn main() !void {
    try DebugAllocator.main();
    try SmpAllocator.main();
    try BestAllocator.main();
    try FixedBufferAllocator.main();
    try ThreadSafeFixedBufferAllocator.main();
    try ArenaAllocator.main();
    try c_allocator.main();
    try page_allocator.main();
    try StackFallbackAllocator.main();
    try MemoryPool.main();
}

const DebugAllocator = struct {
    // #region DebugAllocator
    const std = @import("std");

    pub fn main() !void {
        // 使用模型，一定要是变量，不能是常量
        var gpa = std.heap.DebugAllocator(.{}){};
        // 拿到一个allocator
        const allocator = gpa.allocator();

        // defer 用于执行debug_allocator善后工作
        defer {
            // 尝试进行 deinit 操作
            const deinit_status = gpa.deinit();

            // 检测是否发生内存泄漏
            if (deinit_status == .leak) @panic("TEST FAIL");
        }

        //申请内存
        const bytes = try allocator.alloc(u8, 100);
        // 延后释放内存
        defer allocator.free(bytes);
    }
    // #endregion DebugAllocator
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
        const allocator = fba.allocator();

        // 使用 ThreadSafeAllocator 包裹, 你需要设置使用的内存分配器，还可以配置使用的mutex
        var thread_safe_fba = std.heap.ThreadSafeAllocator{ .child_allocator = allocator };

        // 获取线程安全的内存allocator
        const thread_safe_allocator = thread_safe_fba.allocator();

        // 申请内存
        const memory = try thread_safe_allocator.alloc(u8, 100);
        // 释放内存
        defer thread_safe_allocator.free(memory);
    }
    // #endregion ThreadSafeFixedBufferAllocator
};

const BestAllocator = struct {
    const std = @import("std");
    const builtin = @import("builtin");
    var debug_allocator: std.heap.DebugAllocator(.{}) = .{};

    pub fn main() !void {
        const allocator, const is_debug = allocator: {
            if (builtin.os.tag == .wasi) break :allocator .{ std.heap.wasm_allocator, false };
            break :allocator switch (builtin.mode) {
                .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
                .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
            };
        };
        defer if (is_debug) {
            _ = debug_allocator.deinit();
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
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        // 拿到一个allocator
        const allocator = gpa.allocator();

        // defer 用于执行general_purpose_allocator善后工作
        defer {
            const deinit_status = gpa.deinit();

            if (deinit_status == .leak) @panic("TEST FAIL");
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

const StackFallbackAllocator = struct {
    // #region stack_fallback_allocator
    const std = @import("std");

    pub fn main() !void {
        // 初始化一个优先使用栈区的分配器
        // 栈区大小为256个字节，如果栈区不够用，就会使用page allocator
        var stack_alloc = std.heap.stackFallback(
            256 * @sizeOf(u8),
            std.heap.page_allocator,
        );
        // 获取分配器
        const stack_allocator = stack_alloc.get();
        // 申请内存
        const memory = try stack_allocator.alloc(u8, 100);
        // 释放内存
        defer stack_allocator.free(memory);
    }
    // #endregion stack_fallback_allocator
};

const MemoryPool = struct {
    // #region MemoryPool
    const std = @import("std");

    pub fn main() !void {
        // 此处为了演示，直接使用page allocator
        // Zig 0.16 中 MemoryPool 使用 .empty 常量初始化
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
