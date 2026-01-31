---
outline: deep
---

# 原子操作

> 原子操作是在多线程环境中非常重要的一个概念，原子操作是指一个或一系列的操作，它们作为一个整体来执行，中间不会被任何其他的操作打断。这意味着原子操作要么全部完成，要么全部不完成，不会出现只完成部分操作的情况。

目前 Zig 提供了一些内建函数来进行原子操作，并且提供了 `std.atomic` 命名空间来实现内存排序、原子数据结构。

> [!TIP]
> 该部分内容更适合在单片机或者某些系统级组件开发上使用，常规使用可以使用 `std.Thread` 命名空间下的类型，包含常规的 `Mutex`，`Condition`，`ResetEvent`，`WaitGroup`等等。

## 内建函数

在讲述下列的内建函数前，我们需要了解一下前置知识：

**原子操作的顺序级别**：为了实现性能和必要保证之间的平衡，原子性分为六个级别。它们按照强度顺序排列，每个级别都包含上一个级别的所有保证。

关于原子顺序六个级别的具体说明，见 [LLVM](https://llvm.org/docs/Atomics.html#atomic-orderings)。

<!-- **NotAtomic**

简单的非原子加载或者存储，即常规加载或存储。

**Unordered**

无序的原子级别，是最低级别。意味着一组操作可以以任意的顺序原子执行，只需要结果而不管过程以何种顺序执行。

**Monotonic**

保证原子操作是单调的，在一个线程中，所观察到的原子值在后续过程中必定是大于或等于当前值。但在多线程中，并不保证不会发生重排序 -->

### [`@atomicLoad`](https://ziglang.org/documentation/master/#atomicLoad)

函数原型：

```zig
@atomicLoad(
    comptime T: type,
    ptr: *const T,
    comptime ordering: AtomicOrder
) T
```

用于某个类型指针进行原子化的读取值。

### [`@atomicRmw`](https://ziglang.org/documentation/master/#atomicRmw)

函数原型：

```zig
@atomicRmw(
    comptime T: type,
    ptr: *T,
    comptime op: AtomicRmwOp,
    operand: T,
    comptime ordering: AtomicOrder
) T
```

用于原子化的修改值并返回修改前的值。

其还支持九种操作符，具体 [见此](https://ziglang.org/documentation/master/#atomicRmw)。

### [`@atomicStore`](https://ziglang.org/documentation/master/#atomicStore)

函数原型：

```zig
@atomicStore(
    comptime T: type,
    ptr: *T,
    value: T,
    comptime ordering: AtomicOrder
) void
```

用于对某个类型指针进行原子化的赋值。

### [`@cmpxchgWeak`](https://ziglang.org/documentation/master/#cmpxchgWeak)

函数原型：

```zig
@cmpxchgWeak(
    comptime T: type,
    ptr: *T,
    expected_value: T,
    new_value: T,
    success_order: AtomicOrder,
    fail_order: AtomicOrder
) ?T
```

弱原子的比较与交换操作，如果目标指针是给定值，那么赋值为参数的新值，并返回 null，否则仅读取值返回。

### [`@cmpxchgStrong`](https://ziglang.org/documentation/master/#cmpxchgStrong)

函数原型：

```zig
@cmpxchgStrong(
    comptime T: type,
    ptr: *T,
    expected_value: T,
    new_value: T,
    success_order: AtomicOrder,
    fail_order: AtomicOrder
) ?T
```

强原子的比较与交换操作，如果目标指针是给定值，那么赋值为参数的新值，并返回 null，否则仅读取值返回。

## `std.atomic` 包

### 原子数据结构

可以使用 [`std.atomic.Value`](https://ziglang.org/documentation/master/std/#std.atomic.Value) 包裹某种类型获取到一个原子数据结构。

示例：

<<<@/code/release/atomic.zig#atomic_value

上述代码展示了一个典型的 **引用计数（Reference Counting）** 模式实现。引用计数是一种常见的内存管理技术，用于追踪有多少个引用指向同一个对象。

- **`ref()` 方法**：使用 `.monotonic` 顺序递增计数器。由于只是简单地增加计数，不需要与其他内存操作建立同步关系。
- **`unref()` 方法**：使用 `.release` 顺序递减计数器，确保在计数递减之前的所有内存操作对其他线程可见。当计数减到 1 时，使用 `.acquire` 加载来获取之前所有 `unref()` 操作形成的 release 序列，确保可以安全地调用清理函数。

这种模式常用于智能指针、共享资源管理等场景，是替代 `Mutex` 的轻量级线程安全方案

### `spinLoopHint` 自旋锁

[`std.atomic.spinLoopHint`](https://ziglang.org/documentation/master/std/#std.atomic.spinLoopHint)

向处理器发出信号，表明调用者处于忙等待自旋循环内。

示例：

<<<@/code/release/atomic.zig#spinLoopHint

`spinLoopHint` 用于在自旋等待循环中向 CPU 发出提示信号，表明当前线程正处于忙等待状态。这允许处理器进行功耗优化或将资源让给其他硬件线程。

**何时使用 `spinLoopHint`**：

- 当你实现自旋锁或其他忙等待逻辑时
- 当等待某个原子变量的值发生变化时
- 当预期等待时间非常短（纳秒到微秒级别）时

**与 Mutex 的选择**：

- **自旋等待**：适合极短时间的等待，避免线程上下文切换的开销
- **Mutex**：适合等待时间不确定或较长的场景，会让出 CPU 给其他线程

::: warning ⚠️ 警告
不当使用自旋等待会导致 CPU 资源浪费。如果等待时间较长或不确定，应使用 `std.Thread.Mutex` 等同步原语。
:::
