---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.15.1` 版本升级到 `0.16.0`。

`0.16.0` 是 Zig 近几个版本里破坏性变更最集中的一次更新之一。最大的主题是：**I/O 被统一到了新的 `std.Io` 接口**，同时语言层也清理了 `@Type`、`@cImport`、`packed` / `extern` 类型规则，以及一批历史 API。

## 语言变动

### `switch` 能力继续增强

`0.16.0` 继续补齐了 `switch` 的一些语义细节。最直观的一点是：`packed struct` 和 `packed union` 现在也可以直接作为 prong item 使用，并且比较规则基于它们的 backing integer。

此外，下面这些行为也得到增强或修复：

- 需要结果类型的表达式（例如 `@enumFromInt`）可以直接写进 `switch` prong
- 联合类型的 tag capture 不再只限于 `inline` prong
- 对 `void` 做 `switch` 时，不再一律强制要求 `else`
- 一些错误集合和 one-possible-value 类型上的历史问题被修复了

这部分通常不需要你主动迁移，但如果你有比较复杂的 `switch` 写法，可以顺便回头看一下是否能更简洁。

### `@cImport` 开始迁移到构建系统

`@cImport` 在 `0.16.0` 里还没有被移除，但已经被正式标记为 deprecated。官方建议开始把 C 头文件翻译工作迁移到 `build.zig` 中，通过 `addTranslateC` 生成模块，再在 Zig 代码里 `@import("c")`。

旧写法：

```zig
pub const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("math.h");
    @cInclude("stdlib.h");
});

const c = @import("c.zig").c;
```

新写法：

`c.h`

```c
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
```

`build.zig`

```zig
const translate_c = b.addTranslateC(.{
    .root_source_file = b.path("src/c.h"),
    .target = target,
    .optimize = optimize,
});

const exe = b.addExecutable(.{
    .name = "example",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = translate_c.createModule(),
            },
        },
    }),
});
```

```zig
const c = @import("c");
```

如果你升级到 `0.16.0` 后发现同一份 C 头文件翻译结果和以前不一致，也不用急着怀疑自己。因为 `translate-c` 的底层实现已经从 `libclang` 切换到了 Aro，这类差异更应该视为 bug 并反馈给 Zig。

### `@Type` 被拆分为独立的类型构造内建

这是 `0.16.0` 最重要的语言级 breaking change 之一。`@Type` 被移除了，原本依赖 `@Type(.{ ... })` 或 `std.meta.*` 造类型的代码，需要迁移到新的内建函数。

新增的核心内建包括：

- `@EnumLiteral()`
- `@Int()`
- `@Tuple()`
- `@Pointer()`
- `@Fn()`
- `@Struct()`
- `@Union()`
- `@Enum()`

常见迁移：

```zig
@Type(.enum_literal)
```

⬇️

```zig
@EnumLiteral()
```

```zig
@Type(.{ .int = .{ .signedness = .unsigned, .bits = 10 } })
```

⬇️

```zig
@Int(.unsigned, 10)
```

```zig
std.meta.Tuple(&.{ u32, [2]f64 })
```

⬇️

```zig
@Tuple(&.{ u32, [2]f64 })
```

如果你的项目大量依赖元编程，这一项往往是升级时最先爆出来的报错来源。建议先全局搜索 `@Type(` 和 `std.meta.`，再逐个迁移。

### 小整数类型现在可以安全地隐式转换为浮点

如果某个整数类型的所有可能值，都能被目标浮点类型精确表示，那么现在可以直接发生隐式 coercion。

旧写法：

```zig
var foo_int: u24 = 123;
var foo_float: f32 = @floatFromInt(foo_int);
```

新写法：

```zig
var foo_int: u24 = 123;
var foo_float: f32 = foo_int;
```

注意这只适用于“不会丢精度”的情况。像 `u25 -> f32` 这种仍然需要显式写 `@floatFromInt`。

### 运行时向量索引被禁止

此前很多人会把向量当成“可在运行时索引的数组”来用。`0.16.0` 不再允许这种写法。

旧写法：

```zig
for (0..vector_len) |i| {
    _ = vector[i];
}
```

新写法：

```zig
const vector_type = @typeInfo(@TypeOf(vector)).vector;
const array: [vector_type.len]vector_type.child = vector;

for (&array) |elem| {
    _ = elem;
}
```

如果你确实需要逐项遍历向量，请先把它显式 coercion 成数组，再做索引或遍历。

### 数组与向量不再支持旧式内存强转

`0.16.0` 不再鼓励通过 `@ptrCast` 在数组内存和向量内存之间来回转换。如果你之前是在做同构数据的值级转换，请直接使用 coercion：

```zig
const arr: [4]i32 = .{ 1, 2, 3, 4 };
const vec: @Vector(4, i32) = arr;
const back: [4]i32 = vec;
```

如果你的类型外层还包了一层 `error!` 或其他容器类型，先解包，再在内部做数组和向量之间的转换。

### 不再允许返回局部变量地址

下面这种初学者常见错误，现在会直接给出明确的编译错误：

```zig
fn foo() *i32 {
    var x: i32 = 1234;
    return &x;
}
```

如果你在升级后遇到这类错误，正确修复方式通常是三种之一：

- 直接返回值，而不是返回指针
- 让调用方传入 buffer / 输出参数
- 改用堆分配，并明确约定释放责任

### `packed` 与 `extern` 规则更严格

#### `packed union` 需要明确 backing integer，并保证各字段 bit size 一致

以前 Zig 对 `packed union` 的位级布局有一些隐式推断。`0.16.0` 开始要求它更明确。

旧写法：

```zig
const U = packed union {
    x: u8,
    y: u16,
};
```

新写法：

```zig
const U = packed union(u16) {
    x: packed struct(u16) {
        data: u8,
        padding: u8 = 0,
    },
    y: u16,
};
```

总结一下这条规则：如果你需要 `packed union`，就请明确写出 backing integer，并保证每个字段都能映射到同样大小的位表示。

#### `packed struct` / `packed union` 不再允许指针字段

如果你过去把指针直接塞进 `packed` 类型里，现在需要改成整数保存地址：

```zig
const addr: usize = @intFromPtr(ptr);
const ptr_again: *T = @ptrFromInt(addr);
```

这项变更的核心原因是：很多目标平台里，指针并不只是“裸地址位”，而 `packed` 类型又承诺了精确的位级布局，因此两者不再兼容。

#### `extern` 场景下必须显式指定 tag type / backing type

`enum`、`packed struct`、`packed union` 只要被用于 `extern` / `export` 场景，就不能再依赖隐式推断的底层整数类型。

旧写法：

```zig
const Enum = enum { a, b, c, d };
const PackedStruct = packed struct { a: u4, b: u4 };
const PackedUnion = packed union { a: u8, b: i8 };
```

新写法：

```zig
const Enum = enum(u8) { a, b, c, d };
const PackedStruct = packed struct(u8) { a: u4, b: u4 };
const PackedUnion = packed union(u8) { a: u8, b: i8 };
```

如果你的类型需要跨 ABI 边界导出，请把 tag type 或 backing type 明确写出来，不要再依赖编译器推断。

### 浮点取整内建现在可以直接产出整数

`@floor`、`@ceil`、`@round`、`@trunc` 现在可以直接把浮点值转成整数值。

旧写法：

```zig
const x: i32 = @intFromFloat(@round(value));
```

新写法：

```zig
const x: i32 = @round(value);
```

这项改动本身不一定会让旧代码报错，但会让很多“先取整、再转整数”的写法明显简化。

### 类型解析规则被重做，依赖环错误会更清晰

`0.16.0` 彻底重做了编译器内部的类型解析流程。结果是：

- 大多数以前能工作的代码会继续工作
- 一些以前会莫名其妙报 dependency loop 的代码，现在反而能正常工作
- 也有一小部分旧代码会因为真正的依赖环而在 `0.16.0` 开始报错

最常见的症状，是结构体默认字段值、对 `@This()` 的对齐查询、`@typeInfo` 反射等路径互相依赖。

这类问题没有统一的机械式修法，但 `0.16.0` 的错误信息比以前清楚很多，通常你只需要打断这条环上的任意一条依赖即可。

## 标准库

### `std.Io` 成为新的核心 I/O 抽象

这是 `0.16.0` 最大的标准库变更。现在，凡是“可能阻塞控制流”或“会引入非确定性”的能力，基本都要求显式接收一个 `std.Io` 实例。

这意味着下面这些领域都围绕 `std.Io` 重新组织了：

- 文件系统
- 网络
- 进程
- 同步原语
- 定时器与睡眠
- 一部分流式读写接口

对于从 `0.15.x` 升级的项目来说，如果你只是想先获得和以前类似的行为，通常可以从 `Io.Threaded` 开始：

```zig
var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();
```

但这只是临时过渡方案。更理想的做法，仍然是把 `io: std.Io` 作为参数一路向下传递，或者放到你的应用上下文里统一管理。

测试代码则建议优先使用 `std.testing.io`。

### `main` 现在可以直接接收 `std.process.Init`

`0.16.0` 给 `main` 函数增加了一个非常实用的新入口。你可以直接在参数里拿到已经初始化好的常用资源：

- `init.gpa`
- `init.io`
- `init.arena`
- `init.environ_map`
- `init.preopens`

新写法示例：

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    try std.Io.File.stdout().writeStreamingAll(io, "Hello, world!\n");
}
```

`main` 现在有三种合法形态：

- `pub fn main() ...`：仍然合法，但拿不到参数和环境变量
- `pub fn main(init: std.process.Init.Minimal) ...`：只拿到原始 `argv` / `environ`
- `pub fn main(init: std.process.Init) ...`：拿到完整预初始化资源

### 环境变量与命令行参数不再是全局状态

`0.16.0` 之后，环境变量和进程参数被明确收敛到 `main` 的初始化参数里，不再鼓励像以前一样把它们当作“随处可取的全局状态”。

读取参数：

```zig
const std = @import("std");

pub fn main(init: std.process.Init.Minimal) void {
    var args = init.args.iterate();
    while (args.next()) |arg| {
        std.log.info("arg: {s}", .{arg});
    }
}
```

读取环境变量：

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    for (init.environ_map.keys(), init.environ_map.values()) |key, value| {
        std.log.info("env: {s}={s}", .{ key, value });
    }
}
```

如果你的库函数仍然需要环境变量，请改成显式传参，或者显式接收 `*const std.process.Environ.Map`。

### 进程 API 的入口被重新整理

围绕新的 `std.Io`，进程相关 API 也发生了明显变化。

启动子进程：

```zig
var child = std.process.Child.init(argv, gpa);
child.stdin_behavior = .Pipe;
child.stdout_behavior = .Pipe;
child.stderr_behavior = .Pipe;
try child.spawn(io);
```

⬇️

```zig
var child = try std.process.spawn(io, .{
    .argv = argv,
    .stdin = .pipe,
    .stdout = .pipe,
    .stderr = .pipe,
});
```

运行并捕获输出：

```zig
const result = try std.process.run(allocator, io, .{
    .argv = argv,
});
```

替换当前进程镜像：

```zig
const err = std.process.replace(io, .{ .argv = argv });
```

### `std.Thread.Pool` 被移除

`std.Thread.Pool` 已经从标准库中移除。最常见的迁移方向，是改用 `std.Io.async` 或 `std.Io.Group.async`。

如果你过去用的是“提交一组任务，然后等待全部结束”的模式，通常可以这样迁移：

```zig
fn doAllTheWork(io: std.Io) !void {
    var group: std.Io.Group = .init;
    errdefer group.cancel(io);

    group.async(io, doSomeWork, .{ io, &group, first_work_item });
    try group.await(io);
}
```

另外要特别注意：如果你的旧代码里除了 `Thread.Pool` 之外，还用了 `Thread.Mutex`、`Thread.Condition`、`Thread.ResetEvent` 等同步原语，那么升级到 `std.Io` 时，它们也应该一起迁到对应的 `std.Io.*` 类型。

### `std.io` 进一步收敛到 `std.Io`

这一轮更新里，`GenericReader`、`AnyReader`、`FixedBufferStream` 等历史接口继续退出。

常见映射：

- `std.io` ➡️ `std.Io`
- `std.Io.GenericReader` ➡️ `std.Io.Reader`
- `std.Io.AnyReader` ➡️ `std.Io.Reader`
- `std.leb.readUleb128` ➡️ `std.Io.Reader.takeLeb128`
- `std.leb.readIleb128` ➡️ `std.Io.Reader.takeLeb128`

读取固定缓冲区：

```zig
var fbs = std.io.fixedBufferStream(data);
const reader = fbs.reader();
```

⬇️

```zig
var reader: std.Io.Reader = .fixed(data);
```

写入固定缓冲区：

```zig
var fbs = std.io.fixedBufferStream(buffer);
const writer = fbs.writer();
```

⬇️

```zig
var writer: std.Io.Writer = .fixed(buffer);
```

### 文件系统和路径 API 有一批实用迁移点

#### `readFileAlloc`

旧写法：

```zig
const contents = try std.fs.cwd().readFileAlloc(allocator, file_name, 1234);
```

新写法：

```zig
const contents = try std.Io.Dir.cwd().readFileAlloc(io, file_name, allocator, .limited(1234));
```

注意新的限制语义更严格：到达上限本身也会报错，错误名也从 `FileTooBig` 变成了 `StreamTooLong`。

#### `readToEndAlloc`

旧写法：

```zig
const contents = try file.readToEndAlloc(allocator, 1234);
```

新写法：

```zig
var file_reader = file.reader(&.{});
const contents = try file_reader.interface.allocRemaining(allocator, .limited(1234));
```

#### 当前目录 API 更名

旧写法：

```zig
std.process.getCwd(buffer)
std.process.getCwdAlloc(allocator)
```

新写法：

```zig
std.process.currentPath(io, buffer)
std.process.currentPathAlloc(io, allocator)
```

#### `fs.path.relative` 变成纯函数

旧写法：

```zig
const relative = try std.fs.path.relative(gpa, from, to);
defer gpa.free(relative);
```

新写法：

```zig
const cwd_path = try std.process.currentPathAlloc(io, gpa);
defer gpa.free(cwd_path);

const relative = try std.fs.path.relative(gpa, cwd_path, environ_map, from, to);
defer gpa.free(relative);
```

也就是说，`relative` 不再自己偷偷读取当前工作目录和环境变量，而是要求你把这些上下文显式传进去。

#### `File.Stat.atime` 现在是可选值

读取访问时间：

```zig
stat.atime
```

⬇️

```zig
stat.atime orelse return error.FileAccessTimeUnavailable
```

设置时间戳：

```zig
try file.setTimestamps(io, src_stat.atime, src_stat.mtime);
```

⬇️

```zig
try file.setTimestamps(io, .{
    .access_timestamp = .init(src_stat.atime),
    .modify_timestamp = .init(src_stat.mtime),
});
```

#### 其他值得顺手处理的文件系统改动

- `std.fs.wasi.Preopens` ➡️ `std.process.Preopens`
- 原来的 `atomicFile` 流程重构为 `createFileAtomic`
- `fs.getAppDataDir` 已被移除，应用应自行决定“应用数据目录”的策略

### `std.posix` 和 `std.os.windows` 的中层 API 被移除

这次标准库很明确地砍掉了很多“中不溜”的系统接口。如果你升级后是在 `std.posix` 或 `std.os.windows` 里踩雷，官方建议只选两条路：

- 往上走，改用 `std.Io`
- 往下走，直接使用 `std.posix.system`

也就是说，Zig 不再想长期维护那批半高层、半底层的历史包装函数。

### `std.mem` 的 “index of” 系列统一更名为 “find”

`std.mem` 现在统一使用 `find` 作为“查找子串位置”的概念名称，并新增了 `cut`、`cutPrefix`、`cutSuffix`、`cutScalar`、`cutLast`、`cutLastScalar` 等函数。

如果你项目里大量用了 `indexOf` / `lastIndexOf` / `indexOfScalar` 这类 API，可以统一按新的 `find*` 命名规则做搜索替换。

### 容器继续向 unmanaged 方向收敛

这部分延续了 `0.14` 和 `0.15` 的趋势：标准库越来越倾向于“容器本身不持有 allocator，把 allocator 显式传给需要分配的方法”。

这次比较关键的变化有：

- `ArrayHashMap`、`AutoArrayHashMap`、`StringArrayHashMap` 被移除
- `AutoArrayHashMapUnmanaged` ➡️ `std.array_hash_map.Auto`
- `StringArrayHashMapUnmanaged` ➡️ `std.array_hash_map.String`
- `ArrayHashMapUnmanaged` ➡️ `std.array_hash_map.Custom`
- `PriorityQueue` 和 `PriorityDequeue` 都继续往 `.empty` / `push` / `pop` 风格迁移

`PriorityQueue` 常见重命名：

- `init` ➡️ `initContext`
- `add` ➡️ `push`
- `addUnchecked` ➡️ `pushUnchecked`
- `addSlice` ➡️ `pushSlice`
- `remove` ➡️ `pop`
- `removeOrNull` ➡️ `pop`
- `removeIndex` ➡️ `popIndex`

`PriorityDequeue` 常见重命名：

- `init` ➡️ `.empty`
- `add` ➡️ `push`
- `addSlice` ➡️ `pushSlice`
- `addUnchecked` ➡️ `pushUnchecked`
- `removeMinOrNull` / `removeMin` ➡️ `popMin`
- `removeMaxOrNull` / `removeMax` ➡️ `popMax`
- `removeIndex` ➡️ `popIndex`

### 分配器与并发模型继续调整

有两条需要直接注意：

- `std.heap.ArenaAllocator` 现在变成了 thread-safe 且 lock-free
- `std.heap.ThreadSafeAllocator` 被移除

如果你的旧代码是“在外层包一层 `ThreadSafeAllocator`”，现在应改为直接选用本身适合并发场景的 allocator，或者改造调用结构，避免再依赖这层包装器。

### Fuzz 测试接口改成 `std.testing.Smith`

如果你的项目用到了 fuzz 测试，这也是一个直接的 breaking change。

旧写法：

```zig
const std = @import("std");

fn fuzzTest(_: void, input: []const u8) !void {
    var sum: u64 = 0;
    for (input) |b| sum += b;
    try std.testing.expect(sum != 1234);
}
```

新写法：

```zig
const std = @import("std");

fn fuzzTest(_: void, smith: *std.testing.Smith) !void {
    var sum: u64 = 0;
    while (!smith.eosWeightedSimple(7, 1)) {
        sum += smith.value(u8);
    }
    try std.testing.expect(sum != 1234);
}
```

同时，`0.16.0` 的 fuzzer 还支持了多进程、多核利用和崩溃输入落盘。如果你本来就依赖 fuzz 测试，这次升级是值得顺手把整套流程一起更新的。

## 构建系统

### 依赖目录改到项目本地 `zig-pkg`

从 `0.16.0` 开始，依赖包不再解压到全局缓存目录下，而是会被拉到项目根目录旁边的 `zig-pkg` 目录中。

这带来两个直接结果：

- 调试依赖更方便，能直接 grep、编辑、替换
- 你通常不应该把 `zig-pkg` 提交进仓库，但如果团队确实想这么做，也不是不允许

### `build.zig.zon` 的依赖信息更严格

这次升级后，如果依赖缺少 `fingerprint`，或者 `name` 还在用字符串而不是 enum literal，`zig build` 会直接失败。

另外，旧的 hash 格式也已经不再支持。也就是说，`0.15.x` 时还能勉强工作的某些老 `build.zig.zon`，到 `0.16.0` 可能需要顺手全部更新一遍。

### 可以通过 `zig build --fork` 临时覆写依赖

新加入的 `--fork=[path]` 允许你在不改 `build.zig.zon` 的前提下，临时把整棵依赖树中的某个包替换成本地目录里的 fork。

```sh
zig build --fork=/path/to/your-package
```

这对排查生态 breakage、联调依赖、离线开发都很有帮助。

### 新的错误输出与测试超时选项

`0.16.0` 的 `zig build` 新增或调整了这些常用参数：

- `--test-timeout`：为每个 Zig 单元测试设置超时
- `--error-style`：控制构建错误输出样式
- `--multiline-errors`：控制多行错误信息展示方式

其中，旧的 `--prominent-compile-errors` 已被移除。对应的新写法是：

```sh
zig build --error-style minimal
```

如果你平时配合 `--watch` 或增量编译工作流，`verbose_clear` / `minimal_clear` 这两种 error style 会比较顺手。

### 临时文件 API 被重构

这次构建系统还清理了旧的临时目录 API：

- `Build.makeTempPath` 被移除
- `RemoveDir` step 被移除

迁移方向是：

- 用 `Build.addTempFiles` 创建非缓存的临时文件目录
- 用 `Build.addMutateFiles` 表达“会修改文件”的流程
- 用 `Build.tmpPath` 作为便捷入口

如果你以前是在 configure 阶段预先创建临时目录，再在 make 阶段清理，`0.16.0` 之后应该把这套逻辑迁到新的 `WriteFile` / temp files API 上。

### `builtin.subsystem` 被移除，`Target.SubSystem` 也迁了位置

如果你的代码依赖 `std.builtin.subsystem`，现在需要重新设计：真正的 subsystem 直到链接阶段才知道，编译期再去猜它并不可靠。

另外，`std.Target.SubSystem` 被移动到了 `std.zig.Subsystem`。旧名字目前仍有 deprecated alias，可暂时过渡，但新代码最好直接跟着新命名走。

### 增量编译与新 ELF linker 继续前进

`0.16.0` 里，增量编译已经明显比 `0.15.x` 更实用了：

- LLVM 后端也开始支持增量编译
- 在 ELF 目标上，`-fincremental` 会默认启用新的 ELF linker
- 对很多项目来说，`-Dno-bin` 的收益已经不再明显

常见工作流现在可以直接写成：

```sh
zig build -fincremental --watch
```

不过也要注意：

- 增量编译依然不是默认开启
- 依然存在已知 bug 和误编译
- 新 ELF linker 还不完整，例如目前生成物仍然缺少 DWARF 信息

换句话说，`0.16.0` 的增量编译已经值得日常试用，但如果你碰到诡异问题，仍要记得先排除它。
