---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.14.0` 版本升级到 `0.15.1`。

## 语言变动

### 移除 `usingnamespace`

`usingnamespace` 关键字已被完全移除。需要将其替换为更明确的声明方式。

#### 条件包含

旧写法：

```zig
pub usingnamespace if (have_foo) struct {
    pub const foo = 123;
} else struct {};
```

新写法：

```zig
// 方案 1：直接声明（推荐）
pub const foo = 123;

// 方案 2：使用 compileError
pub const foo = if (have_foo)
    123
else
    @compileError("foo not supported on this target");

// 方案 3：使用哨兵值支持特性检测
pub const foo = if (have_foo) 123 else {};
```

#### 多实现切换

旧写法：

```zig
pub usingnamespace switch (target) {
    .windows => struct {
        pub const target_name = "windows";
        pub fn init() T {
            // ...
        }
    },
    else => struct {
        pub const target_name = "something good";
        pub fn init() T {
            // ...
        }
    },
};
```

新写法：

```zig
pub const target_name = switch (target) {
    .windows => "windows",
    else => "something good",
};
pub const init = switch (target) {
    .windows => initWindows,
    else => initOther,
};
fn initWindows() T {
    // ...
}
fn initOther() T {
    // ...
}
```

#### Mixins 混入

旧写法：

```zig
pub fn CounterMixin(comptime T: type) type {
    return struct {
        pub fn incrementCounter(x: *T) void {
            x.count += 1;
        }
        pub fn resetCounter(x: *T) void {
            x.count = 0;
        }
    };
}

pub const Foo = struct {
    count: u32 = 0,
    pub usingnamespace CounterMixin(Foo);
};
```

新写法（使用零位字段）：

```zig
pub fn CounterMixin(comptime T: type) type {
    return struct {
        pub fn increment(m: *@This()) void {
            const x: *T = @alignCast(@fieldParentPtr("counter", m));
            x.count += 1;
        }
        pub fn reset(m: *@This()) void {
            const x: *T = @alignCast(@fieldParentPtr("counter", m));
            x.count = 0;
        }
    };
}

pub const Foo = struct {
    count: u32 = 0,
    counter: CounterMixin(Foo) = .{},
};

// 使用方式
// foo.counter.increment() 替代 foo.incrementCounter()
```

### 非穷尽枚举的 switch 改进

现在可以在非穷尽枚举的 switch 中组合使用显式标签和 `_` 分支：

```zig
switch (enum_val) {
    .special_case_1 => foo(),
    .special_case_2 => bar(),
    _, .special_case_3 => baz(),
}
```

注意：不能同时使用 `else` 和 `_`：

```zig
const Enum = enum(u32) {
    A = 1,
    B = 2,
    C = 44,
    _
};

fn someFunction(value: Enum) void {
    // 错误：不能同时使用 else 和 _
    switch (value) {
        .A   => {},
        .C   => {},
        else => {}, // 处理已命名但未列出的标签
        _    => {}, // 处理未命名标签
    }
}
```

### 内联汇编：类型化的 clobber 描述符

旧写法：

```zig
pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
        : "rcx", "r11"
    );
}
```

新写法：

```zig
pub fn syscall1(number: usize, arg1: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true });
}
```

可以使用 `zig fmt` 自动升级。

### @ptrCast 从单项指针转换为切片

现在 `@ptrCast` 可以将单项指针转换为切片：

```zig
const val: u32 = 1;
const bytes: []const u8 = @ptrCast(&val);
```

注意：未来计划将此功能移至 `@memCast`。

### undefined 上的算术操作

只有永远不会导致非法行为的运算符才允许 `undefined` 作为操作数。

错误示例：

```zig
const a: u32 = 0;
const b: u32 = undefined;
_ = a + b; // 错误：对 undefined 的使用导致非法行为
```

最佳实践：**始终避免对 undefined 进行任何操作**。

### 整数到浮点的损失性转换

编译时整数转换为浮点数时，如果无法精确表示，现在会报错：

错误示例：

```zig
const val: f32 = 123_456_789; // 错误：f32 无法表示此整数值
```

修复方法：

```zig
const val: f32 = 123_456_789.0; // 使用浮点字面量
```

## 标准库

### Writer 和 Reader 重大变更

这是 0.15.1 最大的破坏性变更。所有 `std.io` 的 reader 和 writer 都已弃用，需要迁移到新的 `std.Io.Reader` 和 `std.Io.Writer`。

#### 主要变化

1. **新接口是非泛型的**：不再使用 `anytype`
2. **缓冲区在接口内部**：不需要单独的 BufferedReader/Writer
3. **明确的错误集合**：每个函数都有具体的 error set
4. **新增高级特性**：支持向量、填充、直接文件传输等

#### 适配旧代码

如果你有旧的 writer，可以使用适配器：

```zig
fn foo(old_writer: anytype) !void {
    var adapter = old_writer.adaptToNewApi(&.{});
    const w: *std.Io.Writer = &adapter.new_interface;
    try w.print("{s}", .{"example"});
}
```

#### 升级 stdout

旧写法：

```zig
const stdout = std.io.getStdOut().writer();
try stdout.print("...", .{});
```

新写法：

```zig
var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;

try stdout.print("...", .{});

try stdout.flush(); // 别忘记 flush！
```

#### std.fs.File.Reader 和 Writer

新的 `std.fs.File.Reader` 会缓存文件信息：

```zig
var file_reader = file.reader(&buffer);
const reader: *std.Io.Reader = &file_reader.interface;
```

#### compress.flate 重构

旧写法：

```zig
var decompress = try std.compress.flate.decompressor(allocator, reader, null);
defer decompress.deinit();
```

新写法：

```zig
var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
var decompress: std.compress.flate.Decompress = .init(reader, .zlib, &decompress_buffer);
const decompress_reader: *std.Io.Reader = &decompress.reader;

// 如果要直接写入 writer，可以使用空缓冲：
var decompress: std.compress.flate.Decompress = .init(reader, .zlib, &.{});
const n = try decompress.streamRemaining(writer);
```

**注意**：压缩功能已被移除。

#### CountingWriter 已删除

根据需求选择替代方案：

- 丢弃字节：使用 `std.Io.Writer.Discarding`
- 分配字节：使用 `std.Io.Writer.Allocating`
- 固定缓冲区：使用 `std.Io.Writer.fixed`

#### BufferedWriter 已删除

旧写法：

```zig
const stdout_file = std.fs.File.stdout().writer();
var bw = std.io.bufferedWriter(stdout_file);
const stdout = bw.writer();

try stdout.print("...\n", .{});
try bw.flush();
```

新写法：

```zig
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;

try stdout.print("...\n", .{});
try stdout.flush();
```

### 格式化打印变更

#### "{f}" 必须显式调用 format 方法

旧写法：

```zig
std.debug.print("{}", .{std.zig.fmtId("example")});
```

新写法：

```zig
std.debug.print("{f}", .{std.zig.fmtId("example")});
```

使用 `-freference-trace` 可以帮助排查所有格式字符串问题。

#### format 方法签名变更

旧签名：

```zig
pub fn format(
    this: @This(),
    comptime format_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void { ... }
```

新签名：

```zig
pub fn format(this: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void { ... }
```

如果需要不同的格式化方法，有三种方案：

1. 定义不同的格式化方法：

```zig
pub fn formatB(foo: Foo, writer: *std.Io.Writer) std.Io.Writer.Error!void { ... }
// 使用：.{std.fmt.alt(Foo, .formatB)}
```

2. 使用 `std.fmt.Alt`：

```zig
pub fn bar(foo: Foo, context: i32) std.fmt.Alt(F, F.baz) {
    return .{ .data = .{ .context = context } };
}
```

3. 返回实现 format 的结构：

```zig
pub fn bar(foo: Foo, context: i32) F {
    return .{ .context = 1234 };
}
const F = struct {
    context: i32,
    pub fn format(f: F, writer: *std.Io.Writer) std.Io.Writer.Error!void { ... }
};
```

#### 格式化打印不再支持 Unicode

对齐功能现在仅支持 ASCII/字节，不再支持 Unicode 码点。

#### 新格式化符号

- `{t}` - 等同于 `@tagName()` 和 `@errorName()`
- `{d}` - 可用于自定义类型（需实现 `formatNumber` 方法）
- `{b64}` - 以标准 base64 输出字符串

### 链表类型去泛型

旧写法：

```zig
std.DoublyLinkedList(T).Node
```

新写法：

```zig
struct {
    node: std.DoublyLinkedList.Node,
    data: T,
}
```

使用 `@fieldParentPtr` 可通过 node 找到 data。

### std.Progress 支持进度条

`std.Progress` 新增 `setStatus` 方法：

```zig
pub const Status = enum {
    working,      // 正在执行任务
    success,      // 操作完成，等待用户输入
    failure,      // 发生错误，等待用户输入
    failure_working, // 有错误但还在工作
};
```

### HTTP 客户端与服务端重构

#### 服务端 API

旧写法：

```zig
var read_buffer: [8000]u8 = undefined;
var server = std.http.Server.init(connection, &read_buffer);
```

新写法：

```zig
var recv_buffer: [4000]u8 = undefined;
var send_buffer: [4000]u8 = undefined;
var conn_reader = connection.stream.reader(&recv_buffer);
var conn_writer = connection.stream.writer(&send_buffer);
var server = std.http.Server.init(conn_reader.interface(), &conn_writer.interface);
```

使用流程：

```zig
var server = std.http.Server.init(conn_reader.interface(), &conn_writer.interface);
var request = try server.receiveHead();
const body_reader = try request.reader();
// 读取 body...

// 一次性响应
try request.respond(content, .{
    .status = status,
    .extra_headers = &.{
        .{ .name = "content-type", .value = "text/html" },
    },
});

// 或流式响应
var response = try request.respondStreaming();
const body_writer = response.writer();
// 写入 body...
try response.end();
```

#### 客户端 API

旧写法：

```zig
var server_header_buffer: [1024]u8 = undefined;
var req = try client.open(.GET, uri, .{
    .server_header_buffer = &server_header_buffer,
});
defer req.deinit();

try req.send();
try req.wait();

const body_reader = try req.reader();
// 读取 body...

var it = req.response.iterateHeaders();
while (it.next()) |header| {
    // 处理 header
}
```

新写法：

```zig
var req = try client.request(.GET, uri, .{});
defer req.deinit();

try req.sendBodiless();
var response = try req.receiveHead(&.{});

// 先处理 headers
var it = response.head.iterateHeaders();
while (it.next()) |header| {
    // 处理 header
}

// 再读取 body
var reader_buffer: [100]u8 = undefined;
const body_reader = response.reader(&reader_buffer);
```

### TLS 客户端

`std.crypto.tls.Client` 不再依赖 `std.net` 或 `std.fs`，仅依赖 `std.Io.Reader` / `std.Io.Writer`。

### ArrayList 默认无管理（unmanaged）

旧的有管理版本已弃用：

- `std.ArrayList` -> `std.array_list.Managed`（将被移除）
- `std.ArrayListAligned` -> `std.array_list.AlignedManaged`（将被移除）

推荐使用：

```zig
const ArrayList = std.ArrayListUnmanaged;
var list: ArrayList(i32) = .empty;
defer list.deinit(gpa);
try list.append(gpa, 1234);
try list.ensureUnusedCapacity(gpa, 1);
list.appendAssumeCapacity(5678);
```

新的 "Bounded" 变体方法：

```zig
var buffer: [8]i32 = undefined;
var stack = std.ArrayListUnmanaged(i32).initBuffer(&buffer);
try stack.appendSliceBounded(initial_stack);
```

### BoundedArray 被移除

根据场景选择替代方案：

1. 任意容量上限 -> 让调用方传入缓冲区或用动态分配
2. 栈上有限容量 -> 直接用 `ArrayListUnmanaged`

示例：

旧写法：

```zig
var stack = try std.BoundedArray(i32, 8).fromSlice(initial_stack);
```

新写法：

```zig
var buffer: [8]i32 = undefined;
var stack = std.ArrayListUnmanaged(i32).initBuffer(&buffer);
try stack.appendSliceBounded(initial_stack);
```

### 删除和弃用内容

以下 API 已被删除或重命名：

```zig
// 文件操作
std.fs.File.reader -> std.fs.File.deprecatedReader
std.fs.File.writer -> std.fs.File.deprecatedWriter

// 格式化
std.fmt.fmtSliceEscapeLower -> std.ascii.hexEscape
std.fmt.fmtSliceEscapeUpper -> std.ascii.hexEscape
std.zig.fmtEscapes -> std.zig.fmtString
std.fmt.fmtSliceHexLower -> {x}
std.fmt.fmtSliceHexUpper -> {X}
std.fmt.fmtIntSizeDec -> {B}
std.fmt.fmtIntSizeBin -> {Bi}
std.fmt.fmtDuration -> {D}
std.fmt.fmtDurationSigned -> {D}
std.fmt.Formatter -> std.fmt.Alt
std.fmt.format -> std.Io.Writer.print

// IO
std.io.GenericReader -> std.Io.Reader
std.io.GenericWriter -> std.Io.Writer
std.io.AnyReader -> std.Io.Reader
std.io.AnyWriter -> std.Io.Writer
std.io.SeekableStream -> 删除（用具体实现替代）
std.io.BitReader -> 删除
std.io.BitWriter -> 删除
std.Io.LimitedReader -> 删除
std.Io.BufferedReader -> 删除
std.fifo -> 删除

// POSIX
std.posix.iovec.iov_base -> .base
std.posix.iovec.iov_len -> .len
```

### std.c 重组

`std.c` 现在有更好的组织结构，并且消除了最后一个 `usingnamespace` 的使用。

## 构建系统

### 移除旧的 root_module 字段

`root_source_file` 等字段已被完全移除。

错误示例：

```zig
const exe = b.addExecutable(.{
    .name = "foo",
    .root_source_file = b.path("src/main.zig"), // 错误
    .target = b.graph.host,
    .optimize = .Debug,
});
```

正确写法：

```zig
const exe = b.addExecutable(.{
    .name = "foo",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

参考 [0.14.0 升级指南](./upgrade-0.14.0.md#从现有模块创建工件)。
