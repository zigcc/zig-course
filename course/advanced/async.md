---
outline: deep
---

# 异步

> 从 `0.16` 开始，Zig 重新拥有了异步能力。它不再依靠 `async` / `await` 关键字，而是由标准库中的 `std.Io` 接口提供。

## 历史回顾

在 `0.10` 之前，Zig 通过 `async`、`await`、`suspend`、`resume` 等关键字实现了一套基于无栈协程的异步机制。这套机制在 self-hosted 编译器中一直没有完成移植，最终相关关键字在 `0.11` 以后被移除（详见 [issue #6025](https://github.com/ziglang/zig/issues/6025)）。

新的设计换了一种思路：**异步不再是语言特性，而是 I/O 实现提供的能力**。

- 语言层面没有 `async` 关键字，也没有“异步函数”与“普通函数”之分，从而彻底避开了“函数染色（function coloring）”问题
- 所有可能阻塞的操作（文件、网络、睡眠、锁、进程……）都通过 `std.Io` 接口完成
- 异步任务通过 `io.async`、`io.concurrent` 等普通函数发起，具体如何调度由 `Io` 的实现决定

如果你熟悉 Zig 的分配器，就很容易理解这种设计：需要分配内存的函数接收一个 `std.mem.Allocator`，需要做 I/O 的函数接收一个 `std.Io`。由调用者（通常是 `main`）决定用哪一种实现，库代码只依赖接口。

## `std.Io` 接口

`std.Io` 本身非常小，只有两个字段：

```zig
userdata: ?*anyopaque,
vtable: *const VTable,
```

和 `std.mem.Allocator` 一样，它是一个“胖指针”：`userdata` 指向具体实现的状态，`vtable` 是一张函数指针表。这张表涵盖了：

- 异步与并发：`async`、`concurrent`、`await`、`cancel`，以及任务组 `Group`
- 取消：`checkCancel`、`swapCancelProtection`、`recancel`
- 同步原语的底层支持：`futexWait`、`futexWake`
- 文件系统：`Dir`、`File` 的各种操作
- 网络：监听、连接、收发数据、DNS 查询
- 进程：创建子进程、等待、获取当前路径等
- 时间与随机数：`now`、`sleep`、`random`

标准库目前提供了以下实现：

| 实现                                     | 说明                                                                         |
| ---------------------------------------- | ---------------------------------------------------------------------------- |
| `Io.Threaded`                            | 基于线程池，功能最完整，也是目前的默认实现                                   |
| `Io.Threaded.init_single_threaded`       | 单线程、阻塞式，不提供并发能力                                               |
| `Io.Evented`                             | 基于 fiber（见下方说明）的事件驱动实现，仍处于实验阶段                       |
| `Io.Uring` / `Io.Kqueue` / `Io.Dispatch` | 分别基于 io_uring、kqueue、Grand Central Dispatch，`Io.Evented` 会按平台选用 |
| `Io.failing`                             | 模拟一个“什么都不支持”的系统，常用于测试                                     |

::: tip 🅿️ 什么是 fiber？

**fiber**（纤程）可以理解为“由程序自己调度的轻量级线程”，也常被称为**有栈协程（stackful coroutine）**或用户态线程。

和操作系统线程一样，每个 fiber 都拥有**自己独立的栈**，所以它可以在任意深度的函数调用中途暂停，之后再从暂停的地方继续执行。不同之处在于，fiber 之间的切换完全发生在用户态：只需保存当前 fiber 的栈指针、帧指针和指令指针，再恢复另一个 fiber 的这三个值即可，不需要陷入内核，也不需要内核参与调度。标准库中的 `std.Io.fiber.Context` 保存的正是这三个寄存器。

`Io.Evented` 的工作方式大致如下：

1. 每个 `io.async` / `io.concurrent` 任务都运行在一个 fiber 上
2. 任务发起 I/O（读文件、收网络数据、`sleep` 等）时，把请求提交给 io_uring / kqueue / GCD，然后**主动切换**到另一个就绪的 fiber
3. 等内核通知 I/O 完成，再切换回原来的 fiber，让它从暂停处继续执行

这样少量的系统线程就能同时推进大量任务，而任务代码本身看起来和普通的阻塞式代码完全一样。

| 对比项   | 系统线程           | fiber               | Zig 旧版 `async`（无栈协程）                                   |
| -------- | ------------------ | ------------------- | -------------------------------------------------------------- |
| 调度者   | 操作系统内核       | `Io` 实现（用户态） | 用户代码（`suspend`/`resume`）                                 |
| 独立的栈 | 有                 | 有                  | 没有，状态保存在 `@Frame` 中                                   |
| 切换开销 | 较大，需要进入内核 | 很小，几条指令      | 很小                                                           |
| 函数染色 | 无                 | 无                  | 隐式存在：会挂起的函数由编译器推断为 async，并沿调用链向上传播 |

正因为 fiber 有独立的栈，普通函数无需任何标记就能在其中被挂起，新的 `std.Io` 才得以避开函数染色问题。代价是栈切换需要针对每种 CPU 架构编写汇编，目前 `std.Io.fiber` 只支持 x86_64、aarch64 和 riscv64，在其他架构上 `Io.Evented` 不可用。

:::

### 获取 `Io`

最简单的方式是让 `main` 接收 `std.process.Init`，运行时会为你准备好默认的 `Io` 实现（同时还有 `gpa`、`arena` 等）。你也可以自己创建一个 `Io.Threaded`：

<<<@/code/release/async.zig#get_io

在单元测试中，可以直接使用 `std.testing.io`。

:::info 🅿️ 提示

`Io` 和分配器一样，应该由应用程序的入口来选择，然后一路作为参数传下去。编写库时，请让需要做 I/O 的函数接收一个 `io: std.Io` 参数，而不是自己创建实现。

:::

## `async` 与 `await`

`io.async(function, args)` 会“异步地”调用 `function`，并立即返回一个 `Io.Future(T)`，其中 `T` 是 `function` 的返回类型。之后可以通过 `future.await(io)` 拿到结果。

本节以及后面的大部分示例中，`io` 都来自 `main` 的参数 `init: std.process.Init`，也就是运行时默认选择的 `Io.Threaded`。它内部维护一个线程池，`io.async` 发起的任务会交给池中的线程执行：

<<<@/code/release/async.zig#async_await

两个 `fetch` 各自睡眠 100ms，但总耗时只有约 100ms，因为它们被分配到了不同的线程上同时执行。如果换成别的 `Io` 实现，同样的代码可能会有不同的表现，下一小节就会看到这一点。

### 用 `defer` 取消任务

上面的代码在每次 `io.async` 之后都紧跟了一句 `defer _ = a.cancel(io) catch {};`，它的作用是：**无论从哪条路径离开作用域，任务都会被结束，任务占用的资源都会被回收**。如果没有这一句，一旦两次 `await` 之间的代码出错提前返回，任务 `b` 就再也不会被等待，它占用的资源也就泄漏了。

你可能会注意到，`catch {}` 把 `cancel` 返回的错误直接丢掉了，什么也没有输出。这是有意为之，标准库自己也是这样写的（例如 `std.Io.net.HostName` 中 DNS 查询的实现）。分两种情况来看：

- **正常路径**：`await` 已经拿到了结果，错误也已经通过 `try` 处理过了。`Future` 的 `await` 和 `cancel` 都是**幂等**的，此时 `cancel` 只是把同一个结果再返回一遍，丢弃它并不会漏掉任何东西
- **提前返回的路径**：函数已经带着另一个错误在返回了，而 `defer` 中的表达式本身也无法再向上返回错误。此时任务刚刚被要求取消，它的结果多半就是 `error.Canceled`，已经没有人关心了；`cancel` 真正重要的作用是等任务结束并回收资源

但下面两种情况不能简单地丢弃结果：

- **任务返回了需要释放的资源**（例如打开的文件、分配的内存）：要在 `defer` 中把它释放掉，例如 `defer if (f.cancel(io)) |file| file.close(io) else |_| {};`
- **提前返回时也想知道任务出了什么错**：可以在 `catch` 中把错误记录下来，例如 `catch |err| std.log.warn("task failed: {t}", .{err})`

### `async` 不等于并发

`async` 表达的是 **异步（asynchrony）**：这次调用与后续代码相互独立，结果可以晚一点再要。它**并不保证**任务会与调用者同时运行。

Io 实现完全可以在 `io.async` 内部就地把函数执行完，再把结果交给 `Future`。下面的代码和上一节完全相同，只是 `io` 不再来自 `init.io`，而是我们自己创建的单线程实现 `Io.Threaded.init_single_threaded`：

<<<@/code/release/async.zig#async_not_concurrent

程序依然正确，只是总耗时变成了两次睡眠之和。这正是 `async` 的设计意图：**用 `async` 编写的代码，在任何 `Io` 实现上都能正确运行**，并发只是锦上添花的优化。因此 `io.async` 永远不会失败。

## `concurrent`：需要真正的并发

有些代码只有在多个任务**同时**运行时才能正确工作。典型例子是生产者与消费者通过一个容量有限的队列通信：如果生产者在队列满时阻塞，而消费者又必须等生产者执行完才开始运行，程序就会死锁。

这种场景应该使用 `io.concurrent`。它和 `io.async` 的用法一样，但要求 `Io` 实现必须为任务分配一个独立的“并发单元”（例如线程或 fiber），否则返回 `error.ConcurrencyUnavailable`：

<<<@/code/release/async.zig#concurrent

这里用到的 `Io.Queue(T)` 是标准库提供的多生产者多消费者队列，它的 `putOne` / `getOne` 在队列满或空时会阻塞当前任务，`close` 后再取数据会在取完剩余元素后返回 `error.Closed`。

在不支持并发的实现上，`concurrent` 会直接报错，而不是让程序悄悄死锁：

<<<@/code/release/async.zig#concurrent_unavailable

:::warning 如何选择

- 只是想“让这几件事尽量重叠执行”：用 `async`，它在任何实现上都正确
- 程序的正确性依赖于多个任务同时运行：用 `concurrent`，并处理 `error.ConcurrencyUnavailable`

:::

## 取消

`future.cancel(io)` 与 `await` 类似，但会先向任务发出**取消请求**。任务在下一次到达**取消点（cancelation point）**时会收到 `error.Canceled`。所谓取消点，就是任何错误集合中包含 `error.Canceled` 的 `Io` 函数，例如 `sleep`、文件读写、网络收发、`Mutex.lock` 等。

<<<@/code/release/async.zig#cancel

关于取消，还有几条规则需要了解：

- 取消请求只会让**下一个**取消点返回 `error.Canceled`，之后的取消点不会重复报告。因此忽略 `error.Canceled` 通常是一个 bug，正确的做法是把它向上传播
- 如果确实需要先处理完手头的事情再响应取消，可以在捕获 `error.Canceled` 后调用 `io.recancel()`，让下一个取消点再次返回它
- 对于长时间运行的纯计算任务，可以定期调用 `io.checkCancel()` 主动检查是否被取消

如果某段代码必须完整执行、不能被打断，可以通过 `swapCancelProtection` 临时屏蔽取消：

<<<@/code/release/async.zig#cancel_protection

## `Group`：任务组

当需要启动数量不定的任务、并且只关心“全部完成”时，可以使用 `Io.Group`。组内的任务不返回值（返回类型必须能转换为 `Io.Cancelable!void`），只能作为一个整体被等待或取消：

<<<@/code/release/async.zig#group

`Group` 也提供了 `concurrent` 方法，语义与 `io.concurrent` 一致。它的一个重要特点是：每个任务结束时就会释放自己占用的资源，而不是等整个组完成，因此一个长期存在、不断加入新任务的组（例如服务器为每个连接创建一个任务）也不会造成资源泄漏。

## `Select`：等待最先完成的任务

`Io.Select(U)` 可以同时启动多个不同类型的任务，并等待其中**最先完成**的那一个。`U` 是一个带标签的联合类型，每个字段对应一种任务的返回类型。

一个常见用法是为操作加上超时：

<<<@/code/release/async.zig#select

`await` 返回第一个完成的结果后，`cancelDiscard` 会取消剩下的任务并丢弃它们的结果。如果剩下的任务可能返回需要释放的资源，应该改用 `cancel`，循环调用直到返回 `null`，逐个释放结果。

## 同步原语

由于任务可能运行在线程上，也可能运行在 fiber 上，同步原语必须由 `Io` 实现来配合阻塞与唤醒。因此原先的 `std.Thread.Mutex` 等已经被移除，取而代之的是 `std.Io` 中一套与实现无关的版本，它们都需要传入 `io`：

- `Io.Mutex`：互斥锁
- `Io.RwLock`：读写锁
- `Io.Condition`：条件变量
- `Io.Semaphore`：信号量
- `Io.Event`：一次性事件，可以 `set` 并让其他任务 `wait`
- `Io.Queue(T)`：前面用到的阻塞队列

<<<@/code/release/async.zig#mutex

这些原语都建立在 `Io` 的 `futexWait` / `futexWake` 之上。在 `Io.Threaded` 中它们对应真正的线程阻塞，而在事件驱动的实现中则对应挂起当前 fiber、切换到其他任务。

## 实现一个自己的 `Io`

理解 `std.Io` 最好的办法就是亲手实现一个。下面我们实现一个极简的“模拟系统” `SimIo`：

- 标准输入来自一段预设的字符串，标准输出写入内存
- 拥有一个虚拟时钟，`sleep` 不会真正等待，而是立刻把时钟向前拨
- `async` 就地执行，不提供并发能力
- 其余操作全部沿用 `Io.failing`，即表现为一个“什么都没有”的系统

<<<@/code/release/async.zig#sim_io

这里有几个值得注意的地方：

1. **以 `Io.failing` 为模板**：`VTable` 有近百个函数，我们不必全部实现。在 `comptime` 中复制一份 `Io.failing.vtable.*`，再覆盖我们关心的几个即可
2. **`async` 可以就地执行**：标准库提供了 `Io.noAsync`，它直接调用函数并返回 `null`，表示结果已经写好，此后的 `await` 不会再调用实现。`Io.noGroupAsync` 同理
3. **流式读写统一经过 `operate`**：`File.Reader` / `File.Writer` 的流式读写最终都会变成 `Io.Operation`，交给 `vtable.operate` 处理
4. **定位读写返回 `error.Unseekable`**：`File.Writer` 默认先尝试定位写入（`pwritev`），遇到 `error.Unseekable` 后会自动退回流式模式，就像写入一个真实的终端或管道一样

下面这段“业务代码”只依赖 `Io` 接口：它逐行读取标准输入，每行“处理”一秒钟，再把结果写到标准输出：

<<<@/code/release/async.zig#sim_io_app

`app` 中用到的 `File.stdin().reader`、`Writer.print`、`io.sleep`、`Clock.now`、`io.async` 全是标准库的普通 API，它完全不知道自己运行在模拟系统中。传入 `SimIo` 时，整个程序瞬间完成，输出为：

```
hello: 2 vowels
zig: 1 vowels
async io: 3 vowels
elapsed: 3s
```

虽然程序“睡”了 3 秒，但实际上一点时间也没有花。这正是把 I/O 抽象成接口所带来的好处之一：**可以把真实世界替换成一个完全确定、可控的环境**，从而编写出快速、稳定、可复现的测试，或者模拟各种难以复现的故障（磁盘已满、网络断开、时钟回拨……）。

:::info 🅿️ 提示

如果想更进一步，实现一个真正支持并发的 `Io`，就需要让 `async` / `concurrent` 把任务交给其他执行单元，并在 `await`、`futexWait`、`sleep` 等阻塞点上把当前任务挂起、切换到其他任务。`Io.Threaded` 使用线程来做到这一点，而 `Io.Evented` 则借助 `std.Io.fiber` 在用户态切换栈。阅读它们的源码是深入理解 Zig 异步模型的好途径。

:::

## 总结

| 需求                         | 使用                                  |
| ---------------------------- | ------------------------------------- |
| 发起一个可以晚点取结果的任务 | `io.async` + `Future.await`           |
| 必须同时运行的多个任务       | `io.concurrent`                       |
| 提前结束任务                 | `Future.cancel` / `Group.cancel`      |
| 启动一批任务并等待全部完成   | `Io.Group`                            |
| 等待多个任务中最先完成的     | `Io.Select`                           |
| 任务间通信与同步             | `Io.Queue`、`Io.Mutex`、`Io.Event` 等 |

更多关于 `std.Io` 引入时的变更细节，可以参考 [0.16.0 版本说明](../update/0.16.0-description.md)。
