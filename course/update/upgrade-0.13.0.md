---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.12.0` 版本升级到 `0.13.0`。

> 本次更新并未对语法进行变动，目前语法基本趋于稳定！

## 标准库

### `BatBadBut` 漏洞临时方案

`std.process.Child`：针对 Windows 上的任意命令执行漏洞 (BatBadBut) 的临时解决方案！

更多信息可以见该 [Issue](https://github.com/ziglang/zig/pull/19698) 和该文章 [BatBadBut: You can't securely execute commands on Windows](https://flatt.tech/research/posts/batbadbut-you-cant-securely-execute-commands-on-windows/)。

### 简化 `hash.crc` 实现

移除了两个原始实现，转而采用基于算法类型的泛型实现。过去有三个很相似的实现，这令人在选择时感到迷惑！

库普曼多项式（Koopman polynomial）没有完全等价的多项式，因此已将其添加到 catalog.txt 文件中。未来更新时测试会报告此问题。

对于旧库普曼多项式 `api` 的用户来说，这是一个重大变化，特别是在使用自定义或非标准多项式时（Crc32 别名将继续起作用）。编译错误会说明需要做什么才能保留现有功能，可能需要用户进行少量代码更改。

```zig
const hash = Crc32WithPoly(.Castagnoli); // old
const hash = Crc(.Crc32Iscsi); // new
```

自定义多项式需要更多的处理，并且需要用户定义自己的算法类型。如果使用，请注意之前的实现需要预反射多项式并使用以下参数：

```zig
.{
    .polynomial = 0x741b8cd7, // equivalent to the reflected polynomial: 0xeb31d82e
    .initial = 0xffffffff,
    .reflect_input = true,
    .reflect_output = true,
    .xor_output = 0xffffffff,
}
```

下面是松散性能测量：

```sh
crc32-slicing-by-8 # 8K of tables
   iterative:  3074 MiB/s [2d191d9400000000]
  small keys:  32B  4650 MiB/s 152387950 Hashes/s [20024c446a99a300]
crc32-half-byte-lookup # 64b of tables
   iterative:   281 MiB/s [2d191d9400000000]
  small keys:  32B   389 MiB/s 12751954 Hashes/s [20024c446a99a300]
crc32 # 1K of tables
   iterative:  3077 MiB/s [2d191d9400000000]
  small keys:  32B  4660 MiB/s 152709182 Hashes/s [20024c446a99a300]
```

### 重命名 `ComptimeStringMap` 为 `StaticStringMap`

重命名后的 `StaticStringMap` 仅接受单个类型参数，并返回已知的结构类型而不是匿名结构。这些更改最初的目的是为了减少 [#19682](https://github.com/ziglang/zig/pull/19682) 中描述的“过长类型名称”问题。

但缺点是对 API 进行了破坏，新的使用方法如下：

```zig
const map = std.StaticStringMap(T).initComptime(kvs_list);
```

更多细节：

- 将 `kvs_list` 参数从类型参数移至 `initComptime()` 参数
- 新的公共方法：
  - `keys()` 、`values()`
  - `init(allocator)`、`deinit(allocator)` 用于运行时数据
  - 暂时保留 `getLongestPrefix(str)`、`getLongestPrefixIndex(str)`，或许仍有用
- 性能指标：
  - 基准测试结果：[travisstaloch/comptime-string-map-revised#1](https://github.com/travisstaloch/comptime-string-map-revised/issues/1)
  - 将结构体大小从 48 字节减少到 32 字节，从而对所有长度字段使用 `u32` 而不是 `usize`，从而提高速度
  - 将 KV 存储为数组结构体可提高速度
  - 最新的基准测试显示了 _debug_ / _safe_ / _small_ / _fast_ 的 wall_time 改进：-6.6% / -10.2% / -19.1% / -8.9%

### `PriorityQueue` 存储容量而不是长度

这是一项重大更改，使 `PriorityQueue` 与 `ArrayList` 保持一致。

此前，`PriorityQueue` 将整个分配的切片存储在 `items` 字段中，并将长度存储在单独的 `len` 字段中。这与 `ArrayList` 不一致，导致访问内存越界错误。

现在，`items` 字段仅指向队列中的有效项目，额外未使用的容量存储在单独的 `cap` 字段中。

具体见此处：[std: align PriorityQueue and ArrayList API-wise](https://github.com/ziglang/zig/pull/19960)。

### 重命名 `std.ChildProcess` 为 `std.process.Child`

此前 `std.ChildProcess` 就已经处于弃用状态！

升级指南：

```zig
std.ChildProcess
```

↓

```zig
std.process.Child
```

> [!NOTE]
> 还有一些其他的函数也从 `std.ChildProcess` 移动到 `std.process` 命名空间。
> 未来还会有重大变化。例如，不使用创建一个 `Child`，然后在其上设置字段，然后调用 `spawn`，而是使用 `std.process.spawn` ，它采用 `options` 参数，然后返回 `Child`，只是一个从 `spawn` 到 `termination` 状态的对象。这是在 Zig 中更倾向于采用的一种做法，即将类型设计为具有最小生命周期和尽可能少未定义字段的状态。

### 重构 `CLI Progress`

这是对标准库的重大更改。编译器和构建系统都严重依赖此 API，因此受到影响。

- [简单的 `asciinema`](https://asciinema.org/a/gDna9RnicwYjDRIDn4e07NFSc) [source code](https://gist.github.com/andrewrk/b22b4f663cef6b4672d7097de95ea343)
- [使用 zig build 构建音乐播放器](https://asciinema.org/a/661404) [source code](https://codeberg.org/andrewrk/player)
- 性能影响可以忽略不计

升级指南：

- 传递 `std.Progress.Node` 而不是 `*std.Progress.Node` （不再是指针）
- 移除对 `node.activate()` 的调用，已不再需要
- 现在可以直接将短存活期的字符串传递给 `Node.start` ，因为数据将被复制
- 多次初始化 `std.Progress` 是非法的，请仅在 `main()` 中进行初始化
- 在写入 `stderr` 之前使用 `std.debug.lockStdErr` 和 `std.debug.unlockStdErr` 来正确集成到 `std.Progress`（ `std.debug.print` 内部已经包含该操作）

```zig
var progress = std.Progress{
    ...
};
const root_node = progress.start("Test", test_fn_list.len);
```

↓

```zig
const root_node = std.Progress.start(.{
    .root_name = "Test",
    .estimated_total_items = test_fn_list.len,
});
```

`start` 的所有选项都是可选的，当生成子进程时，首先填充 progress_node 字段：

```zig
child.progress_node = node;
try child.spawn();
```

> [!NOTE] >`std.Progress` 过去的实现存在限制，即它无法确定终端的所有权。这意味着它只能通过打印到终端的内容来处理子进程，并且它必须处理无进度感知的 stderr 写入终端。它还禁止处理 `SIGWINCH` 和使用 `ioctl` 来查找终端的行列。

新实现的设计理念是，单个进程将直接控制终端，所有其他进度报告都将传回该进程，这可以按照需求随意定制进度条。

创建一个标准的“Zig Progress Protocol”来使用，方便当应用程序是终端所有者或者当应用程序是子进程时，`std.Progress` API 都可以正常工作。后者的进度信息将通过管道以语义方式传递给父进程。

文件描述符通过 `ZIG_PROGRESS` 环境变量给出，方便 `std.process.Child` 与其集成，因此在父进程中附加子进程的进度就像在调用 `spawn` 之前设置 `child.progress_node` 字段一样简单。

为了避免使用此 API 带来的性能损失，`Node.start` 和 `Node.end` API 是线程安全的、无锁的、绝对可靠的，并且执行最少量的内存加载和存储。为了实现这一点，使用了静态分配的 `Node` 存储缓冲区：一块用于父项，另外的用于其余数据，子项不被存储。静态分配的缓冲区用于定制的 `Node` 分配器实现。

事实上，静态缓冲区完全够用，因为可以设置支持的终端宽度和高度的上限。如果终端大小超过此值，进度条输出无论如何都会被截断。

> [!TIP] 实现的大致原理
>
> 一个单独的线程通过计时器定期刷新终端，该进度更新线程迭代整个预分配的父数组，查找已使用的节点。这非常高效，因为双亲数组只有 200 个 8 位整数，或者大约 4 个高速缓存行。
>
> 迭代时，该线程通过从共享数据原子加载到仅由单个线程（进度更新线程）访问的数据，将数据“序列化”到单独的预分配数组中。
>
> 之后查找被标记为文件描述符的节点（通向子进程的管道），这些节点在序列化过程中将处理从管道中读取的数据。除了需要重新定位的父数组之外，数据可以按位进行 `memcpy`。一旦序列化过程完成，就会有两个路径，一个是子进程，另一个是拥有终端的根进程。
>
> 拥有终端的根进程扫描序列化数据，计算子进程和同级指针。序列化的数据仅包含父节点，因此在计算时，会从这里开始。然后遍历树，附加到一个静态缓冲区，该缓冲区将通过单个 `write()` 系统调用发送到终端。在此过程中，会考虑检测到的终端行和列。如果用户调整终端大小，则会导致 `SIGWINCH` 信号，通知更新线程唤醒并使用新行和列重新绘制。
>
> 子进程并不是绘制到终端，而是获取相同的序列化数据并通过管道发送它。管道处于非阻塞模式，因此如果管道已满，则子进程将丢弃消息；未来的更新将包含新的进度信息。同样，当父进程从管道中读取消息时，它会丢弃缓冲区中除最后一条消息之外的所有消息。如果管道中没有消息，父级将使用上次更新的数据。

更多信息可以见：[Andrew Kelley 关于该部分的 blog](https://andrewkelley.me/post/zig-new-cli-progress-bar-explained.html)

### `posix.iovec` 使用 `.base` 和 `.len` 代替 `.iov_base` 和 `.iov_len`

升级指南：

```zig
.{ .iov_base = message.ptr, .iov_len = message.len },
```

↓

```zig
.{ .base = message.ptr, .len = message.len },
```
