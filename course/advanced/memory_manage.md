---
outline: deep
---

# 内存管理

> Zig 在内存管理方面采取了类似 C 的方案，完全由程序员管理内存，这也是为什么 Zig 没有运行时开销的原因，同时这也是为什么 Zig 可以在如此多环境（包括实时软件、操作系统内核、嵌入式设备和低延迟服务器）中无缝工作的原因。

事实上，在 C 开发中最难以调试的 bug 往往是由于错误的内存管理引起的，Zig 在此基础上给我们提供了少量的保护，但仅仅是少量的保护，这就要求程序员在需要明白数据在内存中真实存在的模样（这就涉及到计算机组成原理和操作系统的理论知识了，当然还涉及到一点点的汇编知识）。

事实上，Zig 本身的标准库为我们提供了多种内存分配模型：

1. [`SafeAllocator`](https://ziglang.org/documentation/master/std/#std.heap.SafeAllocator)
2. [`SmpAllocator`](https://ziglang.org/documentation/master/std/#std.heap.SmpAllocator)
3. [`FixedBufferAllocator`](https://ziglang.org/documentation/master/std/#std.heap.FixedBufferAllocator)
4. [`ArenaAllocator`](https://ziglang.org/documentation/master/std/#std.heap.arena_allocator.ArenaAllocator)
5. [`c_allocator`](https://ziglang.org/documentation/master/std/#std.heap.c_allocator)
6. [`page_allocator`](https://ziglang.org/documentation/master/std/#std.heap.page_allocator)
7. [`BufferFirstAllocator`](https://ziglang.org/documentation/master/std/#std.heap.BufferFirstAllocator)

除了这七种内存分配模型外，还提供了内存池的功能 [`MemoryPool`](https://ziglang.org/documentation/master/std/#std.heap.memory_pool.MemoryPool)

你可能对上面的多种内存模型感到很迷惑，C 语言中不就是 `malloc` 吗，怎么到这里这么多的“模型”，这些模型均有着不同的特点，而且它们之间有一部分还可以叠加使用，Zig 在这方面提供了更多的选择，而且不仅仅是这些，你还可以自己尝试实现一个内存模型。

:::info 🅿️ 提示

除了这些，还有一些你可能用不到的分配模型：

- `std.testing.FailingAllocator`
- `std.testing.allocator`
- `std.heap.SbrkAllocator`

:::

:::info 🅿️ 提示

补充一点，Zig 的内存分配并不会自动进行 0 填充，并且 Zig 并没有提供 `calloc` 这种函数，故我们需要手动实现初始化为 0 的操作，不过好在 Zig 提供了 [`std.mem.zeroes`](https://ziglang.org/documentation/master/std/#std.mem.zeroes) 函数，用于直接返回某种类型的 0 值。

:::

## `SafeAllocator`

这是一个以安全为目标的分配器，适合在调试模式下使用，它的性能并不高！

Zig 0.17 用 `SafeAllocator` 取代了原来的 `DebugAllocator`（旧名称仍可使用但已被标记为 deprecated）。它不再是一个需要传入配置的泛型类型，而是一个普通结构体：

- 通过 `.init(backing_allocator, options)` 初始化，需要显式提供一个后备分配器（backing allocator），例如 `std.heap.page_allocator`；
- 始终是线程安全的；
- `deinit` 会报告并释放所有泄漏的内存，返回值为泄漏的数量（`usize`），不再是 `.ok` / `.leak` 枚举；
- 能够检测重复释放、分配大小不匹配、跨实例释放等问题，在调试模式下默认还会检测释放后写入（write after free）。

<<<@/code/release/memory_manager.zig#SafeAllocator

## `SmpAllocator`

专为 `ReleaseFast` 优化设计的分配器，启用多线程。

这个分配器是一个单例；它使用全局状态，并且整个过程只应实例化一个。

设计思路：

1. 每个线程都有独立的空闲列表（freelist），但是当线程退出时，这些数据必须是可回收的。由于我们无法直接得知线程何时退出，所以偶尔需要一个线程尝试回收其他线程的资源。

2. 超过特定大小的内存分配会直接通过内存映射（memory mapped）实现，且不存储分配元数据。这种机制之所以可行，是因为实现中禁止了将分配从小类别转移到大类别（反之亦然）的大小调整。

3. 每个分配器操作都会通过线程局部变量检查线程标识符，以确定要访问全局状态中的哪个元数据，并尝试获取其锁。通常情况下，这个操作会在没有竞争的情况下成功，除非另一个线程被分配了相同的 ID。如果发生这种竞争情况，线程会移动到下一个线程元数据槽位并重复尝试获取锁的过程。

4. 通过将线程局部元数据数组限制为与 CPU 数量相同的大小，确保了随着线程的创建和销毁，它们会循环使用整个空闲列表集合。

<<<@/code/release/memory_manager.zig#SmpAllocator

## `FixedBufferAllocator`

这个分配器是固定大小的内存缓冲区，无法扩容，常常在你需要缓冲某些东西时使用。注意 `allocator()` 返回的接口不是线程安全的。

<<<@/code/release/memory_manager.zig#FixedBufferAllocator

通用的 `ThreadSafeAllocator` 包装器在 Zig 0.16 中已被移除，如果需要跨线程共享同一个 `FixedBufferAllocator`，可以改用它自带的 `threadSafeAllocator()`，它提供了一个无锁的线程安全接口。注意不要同时混用 `allocator()` 和 `threadSafeAllocator()` 返回的接口。

<<<@/code/release/memory_manager.zig#ThreadSafeFixedBufferAllocator

## `ArenaAllocator`

这个分配器的特点是你可以多次申请内存，并无需每次用完时进行 `free` 操作，可以使用 `deinit` 直接一次回收所有分发出去的内存，如果你的程序是一个命令行程序或者没有什么特别的循环模式，例如 web server 或者游戏事件循环之类的，那么推荐你使用这个。

<<<@/code/release/memory_manager.zig#ArenaAllocator

## `c_allocator`

这是纯粹的 C 的 `malloc`，它会直接尝试调用 C 库的内存分配。使用它时，需要在 `build.zig` 中让对应模块链接 libc，例如 `exe.root_module.linkSystemLibrary("c", .{})`：

<<<@/code/release/memory_manager.zig#c_allocator

:::info 🅿️ 提示

它还有一个变体：[`raw_c_allocator`](https://ziglang.org/documentation/master/std/#std.heap.raw_c_allocator)。

这两者的区别仅仅是 `c_allocator` 可能会调用 `alloc_aligned`而不是 `malloc` ，会优先使用 `malloc_usable_size` 来进行一些检查。

而 `raw_c_allocator` 则是完全只使用 `malloc`。

:::

## `page_allocator`

这是最基本的分配器，它仅仅是实现了不同系统的分页申请系统调用。

每次执行分配时，它都会向操作系统申请整个内存页面。单个字节的分配可能会剩下数千的字节无法使用（现代操作系统页大小最小为 4K，但有些系统还支持 2M 和 1G 的页），由于涉及到系统调用，它的速度很慢，但好处是线程安全并且无锁。

<<<@/code/release/memory_manager.zig#page_allocator

## `BufferFirstAllocator`

该分配器比较特殊，它会优先从给定的缓冲区（通常位于栈上）中分配内存，如果缓冲区剩余空间不足，那么它将回退到事先指定的分配器，即使用堆内存。

该分配器的目的和内存池类似，都是尽量避免使用堆内存（堆内存相对于栈上分配过慢）。

Zig 0.17 将原来的 `std.heap.stackFallback` / `StackFallbackAllocator` 重做为 `BufferFirstAllocator`：缓冲区不再作为类型参数内置在分配器中，而是由调用者自行准备后传入 `.init(buffer, fallback_allocator)`。

<<<@/code/release/memory_manager.zig#buffer_first_allocator

## `MemoryPool`

> [!TIP]
> 内存池，也被称为对象池，是一种内存管理策略。在预先分配的内存块（池）中，当程序需要创建新的对象时，它会从池中取出一个已经分配的内存块，而不是直接从操作系统中申请。同样，当对象不再需要时，它的内存会被返回到池中，而不是被释放回操作系统。
>
> 内存池的主要优点是提高了内存分配的效率。通过减少使用系统调用（内存分配需要通过系统调用向 os 申请内存），并且预先分配的内存块大小是固定的，所以分配和回收内存的操作可以在常数时间内完成。
>
> 此外，由于内存块在物理上是相邻的，因此内存池还可以减少内存碎片。
>
> 内存池也有其缺点，例如，如果内存池的大小设置得不合适（太大或太小），则可能会浪费内存或导致内存不足。

<<<@/code/release/memory_manager.zig#MemoryPool

除了基本的分配，内存池还支持预分配和指针对齐设置等，源代码可以参考这里[memory_pool.zig](https://github.com/ziglang/zig/blob/master/lib/std/heap/memory_pool.zig)，它的实现很巧妙，值得一看。

这里有一篇关于最初这个内存池是如何实现的文章：[Cool Zig Patterns - Gotta alloc fast](https://zig.news/xq/cool-zig-patterns-gotta-alloc-fast-23h)

## 实现内存分配器

待添加，当前你可以通过实现 `Allocator` 接口来实现自己的分配器。为了做到这一点，必须仔细阅读 [`std/mem.zig`](https://github.com/ziglang/zig/blob/master/lib/std/mem.zig) 中的文档注释，然后提供 `allocFn` 和 `resizeFn`。

有许多分配器示例可供查看以获取灵感。查看 [`std/heap.zig`](https://github.com/ziglang/zig/blob/master/lib/std/heap.zig) 和 [`std.heap.SafeAllocator`](https://github.com/ziglang/zig/blob/master/lib/std/heap/SafeAllocator.zig)
