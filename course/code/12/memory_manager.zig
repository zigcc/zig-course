const builtin = @import("builtin");
pub fn main() !void {
    try GPA.main();
    try FixedBufferAllocator.main();
    try ThreadSafeFixedBufferAllocator.main();
    try ArenaAllocator.main();
    if (builtin.os.tag == .windows) {
        try HeapAllocator.main();
    }
    try c_allocaotr.main();
    try page_allocator.main();
    try StackFallbackAllocator.main();
    try MemoryPool.main();
}

const GPA = struct {
    // #region GeneralPurposeAllocator
    const std = @import("std");

    pub fn main() !void {
        // 使用模型，一定要是变量，不能是常量
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        // 拿到一个allocator
        const allocator = gpa.allocator();

        // defer 用于执行general_purpose_allocator善后工作
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
    // #endregion GeneralPurposeAllocator
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

const HeapAllocator = struct {
    // #region HeapAllocator
    const std = @import("std");

    pub fn main() !void {
        // 获取分配器模型
        var heap = std.heap.HeapAllocator.init();
        // 善后工作，但有一点需要注意
        // 这个善后工作只有在你手动指定 heapallocaotr 的 heap_handle 字段时，才有效
        defer heap.deinit();

        // 获取分配器
        const allocator = heap.allocator();

        // 分配内存
        const num = try allocator.alloc(u8, 1);
        // free 内存
        defer allocator.free(num);
    }
    // #endregion HeapAllocator
};

const c_allocaotr = struct {
    // #region c_allocator
    const std = @import("std");

    pub fn main() !void {
        // 用起来和 C 一样纯粹
        const c_allocator = std.heap.c_allocator;
        const num = try c_allocator.alloc(u8, 1);
        defer c_allocator.free(num);
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
        var pool = std.heap.MemoryPool(u32).init(std.heap.page_allocator);
        defer pool.deinit();

        // 连续申请三个对象
        const p1 = try pool.create();
        const p2 = try pool.create();
        const p3 = try pool.create();

        // 回收p2
        pool.destroy(p2);
        // 再申请一个新的对象
        const p4 = try pool.create();

        // 注意，此时p2和p4指向同一块内存
        _ = p1;
        _ = p3;
        _ = p4;
    }
    // #endregion MemoryPool
};
