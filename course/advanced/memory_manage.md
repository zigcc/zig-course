---
outline: deep
---

# 内存管理

> zig 在内存管理方面采取了类似 C 的方案，完全由程序员管理内存，这也是为什么 zig 没有运行时开销的原因，同时这也是为什么 zig 可以在如此多环境（包括实时软件、操作系统内核、嵌入式设备和低延迟服务器）中无缝工作的原因。

事实上，在 C 开发中最难以调试的 bug 往往是由于错误的内存管理引起的， zig 在此基础上给我们提供了少量的保护，但仅仅是少量的保护，这就要求程序员在需要明白数据在内存中真实存在的模样（这就涉及到计算机组成原理和操作系统的理论知识了，当然还涉及到一点点的汇编知识）。

事实上，zig 本身的标准库为我们提供了多种内存分配模型：

1. [`GeneralPurposeAllocator`](https://ziglang.org/documentation/master/std/#A;std:heap.GeneralPurposeAllocator)
2. [`FixedBufferAllocator`](https://ziglang.org/documentation/master/std/#A;std:heap.FixedBufferAllocator)
3. [`ArenaAllocator`](https://ziglang.org/documentation/master/std/#A;std:heap.ArenaAllocator)
4. [`HeapAllocator`](https://ziglang.org/documentation/master/std/#A;std:heap.HeapAllocator)
5. [`c_allocator`](https://ziglang.org/documentation/master/std/#A;std:heap.c_allocator)
6. [`page_allocator`](https://ziglang.org/documentation/master/std/#A;std:heap.page_allocator)

除了这六种内存分配模型外，还提供了内存池的功能 [`MemoryPool`](https://ziglang.org/documentation/master/std/#A;std:heap.MemoryPool)

你可能对上面的多种内存模型感到很迷惑，C 语言中不就是 `malloc` 吗，怎么到这里这么多的“模型”，这些模型均有着不同的特点，而且它们之间有一部分还可以叠加使用，zig 在这方面提供了更多的选择，而且不仅仅是这些，你还可以自己尝试实现一个内存模型。

:::info 🅿️ 提示

除了这些，还有一些你可能用不到的分配模型：

- `std.testing.FailingAllocator`
- `std.testing.allocator`
- `std.heap.LoggingAllocator`
- `std.heap.LogToWriterAllocator`
- `std.heap.SbrkAllocator`
- `std.heap.ScopedLoggingAllocator`
- `std.heap.StackFallbackAllocator`

:::

:::info 🅿️ 提示

补充一点，zig 的内存分配并不会自动进行 0 填充，并且 zig 并没有提供 `calloc` 这种函数，故我们需要手动实现初始化为 0 的操作，不过好在 zig 提供了 [`std.mem.zeroes`](https://ziglang.org/documentation/master/std/#A;std:mem.zeroes) 函数，用于直接返回某种类型的 0 值。

:::

## `GeneralPurposeAllocator`

这是一个通用的分配器，当你需要动态内存时，并且还不知道自己应该用什么分配器模型，用这个准没错！

这个分配器的目的不是为了性能，而是为了安全，它支持线程安全，安全检查，检查是否存在泄露等特性，这些特性均可手动配置是否开启。

```zig
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

    //申请内存
    const bytes = try allocator.alloc(u8, 100);
    // 延后释放内存
    defer allocator.free(bytes);
}
```

## `FixedBufferAllocator`

这个分配器是固定大小的内存缓冲区，无法扩容，常常在你需要缓冲某些东西时使用，注意默认情况下它不是线程安全的，但是存在着变体 [`ThreadSafeAllocator`](https://ziglang.org/documentation/master/std/#A;std:heap.ThreadSafeAllocator)，使用 `ThreadSafeAllocator` 包裹一下它即可。

::: code-group

```zig [default]
const std = @import("std");

pub fn main() !void {
    var buffer: [1000]u8 = undefined;
    // 一块内存区域，传入到fiexed buffer中
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    // 获取内存allocator
    const allocator = fba.allocator();

    // 申请内存
    const memory = try allocator.alloc(u8, 100);
    // 释放内存
    defer allocator.free(memory);
}
```

```zig [thread_safe]
const std = @import("std");

pub fn main() !void {
    var buffer: [1000]u8 = undefined;
    // 一块内存区域，传入到fiexed buffer中
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    // 获取内存allocator
    const allocator = fba.allocator();

    // 使用 ThreadSafeAllocator 包裹, 你需要设置使用的内存分配器，还可以配置使用的mutex
    var thread_safe_fba = std.heap.ThreadSafeAllocator{ .child_allocator = allocator };

    // 获取线程安全的内存allocator
    const thread_safe_allocator=thread_safe_fba.allocator();

    // 申请内存
    const memory = try thread_safe_allocator.alloc(u8, 100);
    // 释放内存
    defer thread_safe_allocator.free(memory);
}
```

:::

## `ArenaAllocator`

这个分配器的特点是你可以多次申请内存，并无需每次用完时进行 `free` 操作，可以使用 `deinit` 直接一次回收所有分发出去的内存，如果你的程序是一个命令行程序或者没有什么特别的循环模式，例如web server 或者游戏事件循环之类的，那么推荐你使用这个。

```zig
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
```

## `HeapAllocator`

这是一个依赖 windows 特性的分配器模型，故仅可在 windows 下可用。

关于这个模型的更多信息，可以参考这里[https://learn.microsoft.com/en-us/windows/win32/api/heapapi/](https://learn.microsoft.com/en-us/windows/win32/api/heapapi/)

```zig
const std = @import("std");

pub fn main() !void {
    // 获取分配器模型
    var heap = std.heap.HeapAllocator.init();
    // 善后工作，但有一点需要注意
    // 这个善后工作只有在你指定 heap_handle 时，才有效
    defer heap.deinit();

    // 获取分配器
    const allocator = heap.allocator();

    // 分配内存
    var n = try allocator.alloc(u8, 1);
    // free 内存
    defer allocator.free(n);
}
```

## `c_allocator`

这是纯粹的 C 的 `malloc`，它会直接尝试调用 C 库的内存分配，使用它需要在 `build.zig` 中添加上 `linkLibC` 功能：

```zig
const std = @import("std");

pub fn main() !void {
    // 用起来和 C 一样纯粹
    const c_allocator = std.heap.c_allocator;
    var n = c_allocator.alloc(u8, 1);
    defer c_allocator.free(n);
}
```

:::info 🅿️ 提示

它还有一个变体：`raw_c_allocator`。

这两者的区别仅仅是 `c_allocator` 可能会调用 `alloc_aligned `而不是 `malloc` ，会优先使用 `malloc_usable_size` 来进行一些检查。

而 `raw_c_allocator` 则是完全只使用 `malloc`。

:::

## `page_allocator`

这是最基本的分配器，它仅仅是实现了不同系统的分页申请系统调用。

每次执行分配时，它都会向操作系统申请整个内存页面。单个字节的分配可能会剩下数千的字节无法使用（现代操作系统页大小最小为4K，但有些系统还支持2M和1G的页），由于涉及到系统调用，它的速度很慢，但好处是线程安全并且无锁。

```zig
const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const memory = try allocator.alloc(u8, 100);
    defer allocator.free(memory);
}
```

## `MemoryPool`

内存池，消除频繁调用内存分配和释放函数所带来的开销问题，既然我们经常要分配内存，为什么不回收内存来给新的申请使用而不是释放内存呢？

```zig
const std = @import("std");

pub fn main() !void {
    var pool = std.heap.MemoryPool(u32).init(std.testing.allocator);
    defer pool.deinit();

    // 连续申请三块内存
    const p1 = try pool.create();
    const p2 = try pool.create();
    const p3 = try pool.create();

    // 回收p2
    pool.destroy(p2);
    // 再申请一快内存
    const p4 = try pool.create();

    // 注意，此时p2和p4指向同一块内存
    _ = p1;
    _ = p3;
    _ = p4;
}
```

除了基本的分配，内存池还支持预分配和指针对齐设置等，源代码可以参考这里[memory_pool.zig](https://github.com/ziglang/zig/blob/master/lib/std/heap/memory_pool.zig)，它的实现很巧妙，值得一看。

这里有一篇关于最初这个内存池是如何实现的文章：[Cool Zig Patterns - Gotta alloc fast](https://zig.news/xq/cool-zig-patterns-gotta-alloc-fast-23h)

## 实现内存分配器

待添加，当前你可以通过实现 `Allocator` 接口来实现自己的分配器。为了做到这一点，必须仔细阅读 [`std/mem.zig`](https://github.com/ziglang/zig/blob/master/lib/std/mem.zig) 中的文档注释，然后提供 `allocFn` 和 `resizeFn`。

有许多分配器示例可供查看以获取灵感。查看 [`std/heap.zig`](https://github.com/ziglang/zig/blob/master/lib/std/heap.zig) 和 [`std.heap.GeneralPurposeAllocator`](https://github.com/ziglang/zig/blob/master/lib/std/heap/general_purpose_allocator.zig)
