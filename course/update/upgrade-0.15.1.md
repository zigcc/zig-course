---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.14.0` 版本升级到 `0.15.1`。
本次发布凝聚了 162 位贡献者 在 5 个月内 647 次提交的成果。在将 Zig 的 **x86 后端** 设为 **调试模式** 的默认选项后，其编译速度提升了 5 倍；同时，正在积极开发的 **aarch64 后端** 也取得了显著进展。此外，**Writergate** 以及一系列语言变更和标准库调整，带来了大量的 **API 破坏性更改**。

## 语言变更

### 移除 `usingnamespace`

`usingnamespace` 关键字已被移除。以下是常见用例的替代方案：

#### 用例：条件包含

```zig
// 旧代码
const builtin = @import("builtin");
const os_impl = switch (builtin.os.tag) {
    .linux => @import("os/linux.zig"),
    .windows => @import("os/windows.zig"),
    else => @compileError("Unsupported OS"),
};
usingnamespace os_impl;
```

⬇️

```zig
// 新代码
const builtin = @import("builtin");
const os_impl = switch (builtin.os.tag) {
    .linux => @import("os/linux.zig"),
    .windows => @import("os/windows.zig"),
    else => @compileError("Unsupported OS"),
};

// 显式导出所需函数
pub const open = os_impl.open;
pub const close = os_impl.close;
pub const read = os_impl.read;
pub const write = os_impl.write;
```

#### 用例：实现切换

```zig
// 旧代码
const MyStruct = struct {
    data: u32,

    usingnamespace if (builtin.mode == .Debug)
        @import("debug_impl.zig")
    else
        @import("release_impl.zig");
};
```

⬇️

```zig
// 新代码
const Impl = if (builtin.mode == .Debug)
    @import("debug_impl.zig")
else
    @import("release_impl.zig");

const MyStruct = struct {
    data: u32,

    pub fn doSomething(self: *MyStruct) void {
        return Impl.doSomething(self);
    }

    // 显式实现所有需要的方法
};
```

#### 用例：混入

```zig
// 旧代码
fn LoggingMixin(comptime T: type) type {
    return struct {
        pub fn log(self: *T, message: []const u8) void {
            std.log.info("{s}: {s}", .{ @typeName(T), message });
        }
    };
}

const MyStruct = struct {
    data: u32,
    usingnamespace LoggingMixin(@This());
};
```

⬇️

```zig
// 新代码
fn LoggingMixin(comptime T: type) type {
    return struct {
        pub fn log(self: *T, message: []const u8) void {
            std.log.info("{s}: {s}", .{ @typeName(T), message });
        }
    };
}

const MyStruct = struct {
    data: u32,

    const Mixin = LoggingMixin(@This());

    pub fn log(self: *MyStruct, message: []const u8) void {
        Mixin.log(self, message);
    }
};
```

### 移除 `async` 和 `await` 关键字

`async` 和 `await` 关键字已被移除。这为未来引入新的异步编程方案做准备。

```zig
// 旧代码 - 将不再工作
fn asyncFunction() async void {
    // 异步代码
}

fn caller() void {
    const frame = async asyncFunction();
    await frame;
}
```

目前需要使用其他方式处理并发，等待未来版本中新的异步编程支持。

### 对非穷尽枚举的 `switch` 支持

现在可以对非穷尽枚举使用 `switch` 语句：

```zig
const MyEnum = enum(u8) {
    foo = 1,
    bar = 2,
    _,
};

fn handleEnum(value: MyEnum) void {
    switch (value) {
        .foo => std.debug.print("foo\n", .{}),
        .bar => std.debug.print("bar\n", .{}),
        else => std.debug.print("unknown\n", .{}),
    }
}
```

### 允许对布尔向量使用更多运算符

布尔向量现在支持更多运算符：

```zig
test "boolean vector operations" {
    const vec_a: @Vector(4, bool) = .{ true, false, true, false };
    const vec_b: @Vector(4, bool) = .{ false, true, true, false };

    const and_result = vec_a & vec_b;
    const or_result = vec_a | vec_b;
    const xor_result = vec_a ^ vec_b;
    const not_result = ~vec_a;
}
```

### 内联汇编：类型化的破坏描述符

内联汇编现在支持类型化的 clobber 列表：

```zig
// 旧代码
asm volatile ("mov %[src], %[dst]"
    : [dst] "=r" (dst)
    : [src] "r" (src)
    : "memory" // 字符串形式
);
```

⬇️

```zig
// 新代码
asm volatile ("mov %[src], %[dst]"
    : [dst] "=r" (dst)
    : [src] "r" (src)
    : .memory // 类型化形式
);
```

### 允许 `@ptrCast` 从单项指针到切片的转换

现在可以使用 `@ptrCast` 将单项指针转换为切片：

```zig
test "ptrCast to slice" {
    var value: u32 = 42;
    const ptr: *u32 = &value;

    // 新功能：将单项指针转换为切片
    const slice: []u32 = @ptrCast(ptr);

    std.testing.expect(slice[0] == 42);
}
```

### 对 `undefined` 进行算术运算的新规则

`undefined` 值的算术运算规则发生了变化：

```zig
test "undefined arithmetic" {
    const a: i32 = undefined;
    const b: i32 = 10;

    // 任何与 undefined 的运算都返回 undefined
    const result = a + b; // result 是 undefined
    _ = result;

    // 更安全的做法
    const safe_a: i32 = 0; // 显式初始化
    const safe_result = safe_a + b;
    std.testing.expect(safe_result == 10);
}
```

### 对从整数到浮点数的有损转换发出错误

现在对于可能导致精度损失的转换会发出编译错误：

```zig
test "lossy integer to float conversion" {
    const large_int: u64 = 0x1FFFFFFFFFFFFF; // 53 位

    // 这将产生编译错误，因为 f64 只有 52 位尾数
    // const float_val: f64 = @floatFromInt(large_int); // 错误！

    // 需要显式使用有损转换
    const float_val: f64 = @floatFromInt(@as(u53, @truncate(large_int)));

    std.debug.print("Float: {}\n", .{float_val});
}
```

## 标准库

### Writergate

这是本次更新中最重大的破坏性更改，原有的 `std.io` 中的读写器接口被完全重新设计。

#### 动机

旧的 I/O 系统存在以下问题：

- 泛型接口导致编译时间过长
- 缓冲区管理不一致
- 性能不佳，存在不必要的内存拷贝
- 接口复杂，难以优化

#### 适配器 API

新的设计引入了适配器模式：

```zig
// 旧的泛型接口
fn processData(reader: anytype, writer: anytype) !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;
        try writer.writeAll(buffer[0..bytes_read]);
    }
}
```

⬇️

```zig
// 新的适配器接口
fn processData(reader: std.Io.Reader, writer: std.Io.Writer) !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;
        try writer.writeAll(buffer[0..bytes_read]);
    }
}

// 使用时需要适配器
const file = try std.fs.cwd().openFile("input.txt", .{});
defer file.close();

const stdout = std.io.getStdOut();

try processData(
    file.reader().adapter(), // 适配器转换
    stdout.writer().adapter(), // 适配器转换
);
```

### 新的 `std.Io.Writer` 和 `std.Io.Reader` API

新的 API 采用**非泛型设计**：

```zig
// std.Io.Writer 的定义
pub const Writer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (*anyopaque, []const u8) anyerror!usize,
        writeAll: *const fn (*anyopaque, []const u8) anyerror!void,
        writeByte: *const fn (*anyopaque, u8) anyerror!void,
    };

    pub fn write(self: Writer, bytes: []const u8) !usize {
        return self.vtable.write(self.ptr, bytes);
    }

    pub fn writeAll(self: Writer, bytes: []const u8) !void {
        return self.vtable.writeAll(self.ptr, bytes);
    }
};
```

#### `std.fs.File.Reader` 和 `std.fs.File.Writer`

文件 I/O 的使用方式也发生了变化：

```zig
// 旧代码
const file = try std.fs.cwd().openFile("data.txt", .{});
defer file.close();

const reader = file.reader();
var buffer: [1024]u8 = undefined;
const bytes_read = try reader.read(&buffer);
```

⬇️

```zig
// 新代码
const file = try std.fs.cwd().openFile("data.txt", .{});
defer file.close();

// 方式 1：直接使用文件方法
var buffer: [1024]u8 = undefined;
const bytes_read = try file.read(&buffer);

// 方式 2：使用新的 Reader 接口
const reader = file.reader();
const io_reader = reader.adapter();
const bytes_read2 = try io_reader.read(&buffer);
```

#### 升级 `std.io.getStdOut().writer().print()`

标准输出的使用方式也需要调整：

```zig
// 旧代码
const stdout = std.io.getStdOut().writer();
try stdout.print("Hello, {s}!\n", .{"World"});
```

⬇️

```zig
// 新代码
// 方式 1：使用 std.debug.print（推荐）
std.debug.print("Hello, {s}!\n", .{"World"});

// 方式 2：使用新的 Writer 接口
const stdout = std.io.getStdOut();
const writer = stdout.writer().adapter();
try writer.print("Hello, {s}!\n", .{"World"});

// 方式 3：直接使用文件方法
const stdout = std.io.getStdOut();
try stdout.writeAll("Hello, World!\n");
```

#### 重构 `std.compress.flate`

压缩相关的代码也需要大量修改：

```zig
// 旧代码
var deflate_stream = std.compress.flate.deflateStream(allocator, writer);
defer deflate_stream.deinit();
try deflate_stream.writer().writeAll(data);
try deflate_stream.finish();
```

⬇️

```zig
// 新代码
var deflate_stream = std.compress.flate.DeflateStream.init(allocator, writer.adapter());
defer deflate_stream.deinit();
try deflate_stream.writeAll(data);
try deflate_stream.finish();
```

#### 删除 `CountingWriter`

`CountingWriter` 被删除，需要手动计数：

```zig
// 旧代码
var counting_writer = std.io.countingWriter(base_writer);
```

⬇️

```zig
// 新代码 - 需要手动计数
var bytes_written: usize = 0;
```

#### 删除 `BufferedWriter`

`BufferedWriter` 被重构：

```zig
// 旧代码
var buffered_writer = std.io.bufferedWriter(base_writer);
```

⬇️

```zig
// 新代码
var buffer: [4096]u8 = undefined;
var buffered_writer = std.io.BufferedWriter(4096, @TypeOf(base_writer)).init(base_writer);
```

### 调用 `format` 方法需要使用 `{f}`

现在调用自定义的 `format` 方法需要使用 `{f}` 格式说明符：

```zig
const Point = struct {
    x: f32,
    y: f32,

    pub fn format(self: Point, writer: anytype) !void {
        try writer.print("Point({d}, {d})", .{ self.x, self.y });
    }
};

// 使用时必须使用 {f}
const point = Point{ .x = 1.0, .y = 2.0 };
std.debug.print("{f}\n", .{point}); // 注意使用 {f}
```

### `format` 方法不再使用格式字符串或选项

格式化方法的签名已经简化：

```zig
// 旧代码
const Point = struct {
    x: f32,
    y: f32,

    pub fn format(
        self: Point,
        comptime fmt: []const u8, // 被移除
        options: std.fmt.FormatOptions, // 被移除
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Point({d}, {d})", .{ self.x, self.y });
    }
};
```

⬇️

```zig
// 新代码
const Point = struct {
    x: f32,
    y: f32,

    pub fn format(
        self: Point,
        writer: anytype, // 只保留 writer 参数
    ) !void {
        try writer.print("Point({d}, {d})", .{ self.x, self.y });
    }
};
```

### 格式化打印不再处理 Unicode

Unicode 处理被移除，需要手动处理：

```zig
// 旧代码
std.debug.print("你好，{s}！\n", .{"世界"}); // 自动处理 Unicode
```

⬇️

```zig
// 新代码 - 需要手动处理 Unicode
const message = "你好，世界！";
std.debug.print("{s}\n", .{message}); // 仍然可以显示，但不保证所有 Unicode 处理
```

### 新的格式化打印说明符

新增了一些格式化说明符：

```zig
const value: u32 = 255;

// 新的格式化选项
std.debug.print("{d}\n", .{value});     // 十进制：255
std.debug.print("{x}\n", .{value});     // 十六进制：ff
std.debug.print("{X}\n", .{value});     // 大写十六进制：FF
std.debug.print("{o}\n", .{value});     // 八进制：377
std.debug.print("{b}\n", .{value});     // 二进制：11111111

// 浮点数格式化
const pi: f64 = 3.14159;
std.debug.print("{d:.2}\n", .{pi});     // 保留两位小数：3.14
std.debug.print("{e}\n", .{pi});        // 科学计数法：3.14159e+00

// 指针和切片
const ptr: *u32 = &value;
const slice: []const u8 = "hello";
std.debug.print("{*}\n", .{ptr});       // 指针地址
std.debug.print("{s}\n", .{slice});     // 字符串
std.debug.print("{any}\n", .{slice});   // 通用格式化
```

### 去泛型化链表

链表类型也进行了重构：

```zig
// 旧代码
const Node = std.SinglyLinkedList(i32).Node;
var list = std.SinglyLinkedList(i32){};
var node = Node{ .data = 42 };
list.prepend(&node);
```

⬇️

```zig
// 新代码
const SinglyLinkedList = std.SinglyLinkedList;
const Node = SinglyLinkedList.Node;

var list: SinglyLinkedList = .{};
var node = Node{ .data = @as(*anyopaque, @ptrCast(&@as(i32, 42))) };
list.prepend(&node);

// 或者使用新的 API
var typed_list = std.DoublyLinkedList(i32){};
var typed_node = std.DoublyLinkedList(i32).Node{ .data = 42 };
typed_list.append(&typed_node);
```

### `std.Progress` 支持进度条转义码

进度条系统得到了增强，支持更多的终端转义码。

### HTTP 客户端和服务器

标准库新增了 HTTP 支持：

```zig
// HTTP 客户端示例
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse("https://httpbin.org/get") catch unreachable;

    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    try headers.append("User-Agent", "Zig HTTP Client");

    var request = try client.open(.GET, uri, headers, .{});
    defer request.deinit();

    try request.send(.{});
    try request.wait();

    const body = try request.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    std.debug.print("Response: {s}\n", .{body});
}
```

### TLS 客户端

内置 TLS 支持：

```zig
// TLS 连接示例
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try std.net.Address.parseIp("93.184.216.34", 443); // example.com
    const stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();

    var tls_client = try std.crypto.tls.Client.init(stream, .{
        .host = "example.com",
        .allocator = allocator,
    });
    defer tls_client.deinit();

    const request = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n";
    try tls_client.writeAll(request);

    var buffer: [4096]u8 = undefined;
    const bytes_read = try tls_client.read(&buffer);
    std.debug.print("Response: {s}\n", .{buffer[0..bytes_read]});
}
```

### `ArrayList`：将非托管模式设为默认

这是一个重大的破坏性更改。`std.ArrayList` 现在默认采用 **非托管 (unmanaged)** 模式：

```zig
// 旧代码
const std = @import("std");

fn oldArrayListExample(allocator: std.mem.Allocator) !void {
    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();

    try list.append(42);
    try list.appendSlice(&[_]i32{ 1, 2, 3 });

    for (list.items) |item| {
        std.debug.print("{d} ", .{item});
    }
}
```

⬇️

```zig
// 新代码
const std = @import("std");

fn newArrayListExample(allocator: std.mem.Allocator) !void {
    // 方式 1：使用新的 ArrayListUnmanaged
    var list: std.ArrayListUnmanaged(i32) = .empty;
    defer list.deinit(allocator);

    try list.append(allocator, 42);
    try list.appendSlice(allocator, &[_]i32{ 1, 2, 3 });

    for (list.items) |item| {
        std.debug.print("{d} ", .{item});
    }
}

// 方式 2：使用别名保持兼容性
fn compatibilityExample(allocator: std.mem.Allocator) !void {
    // ArrayList 现在是 ArrayListUnmanaged 的别名
    const ArrayList = std.ArrayListUnmanaged;
    var list: ArrayList(i32) = .empty;
    defer list.deinit(allocator);

    try list.append(allocator, 42);
}

// 方式 3：使用新的初始化方法
fn newInitExample(allocator: std.mem.Allocator) !void {
    var list = std.ArrayList(i32).init(allocator); // 仍然可用，但已弃用
    defer list.deinit();

    // 或者使用新的方式
    var new_list: std.ArrayList(i32) = .{};
    defer new_list.deinit(allocator);

    try new_list.append(allocator, 42);
}
```

其他容器类型也发生了类似的变化：

```zig
// HashMap
var map: std.HashMapUnmanaged([]const u8, i32, std.hash_map.StringContext, 80) = .{};
defer map.deinit(allocator);

try map.put(allocator, "key", 42);
const value = map.get("key");

// ArrayHashMap
var array_map: std.ArrayHashMapUnmanaged([]const u8, i32, std.hash_map.StringContext, false) = .{};
defer array_map.deinit(allocator);

try array_map.put(allocator, "key", 42);

// PriorityQueue
var pq: std.PriorityQueueUnmanaged(i32, void, compareInts) = .{};
defer pq.deinit(allocator);

try pq.add(allocator, 42);

fn compareInts(context: void, a: i32, b: i32) std.math.Order {
    _ = context;
    return std.math.order(a, b);
}
```

### 环形缓冲区

新增了环形缓冲区类型：

```zig
const RingBuffer = std.RingBuffer;

// 创建环形缓冲区
var buffer: [16]u8 = undefined;
var ring = RingBuffer.init(&buffer);

// 写入数据
const data = "Hello, World!";
const written = ring.write(data);
std.debug.print("Written {} bytes\n", .{written});

// 读取数据
var read_buffer: [32]u8 = undefined;
const read_count = ring.read(&read_buffer);
std.debug.print("Read: {s}\n", .{read_buffer[0..read_count]});
```

### 移除 `BoundedArray`

`BoundedArray` 被移除，建议使用其他替代方案：

```zig
// 旧代码
var bounded = std.BoundedArray(i32, 10).init(0);
try bounded.append(42);
```

⬇️

```zig
// 新代码 - 使用 ArrayList 或数组
var list: std.ArrayListUnmanaged(i32) = .empty;
defer list.deinit(allocator);

// 或者使用固定大小数组
var array: [10]i32 = undefined;
var count: usize = 0;

if (count < array.len) {
    array[count] = 42;
    count += 1;
}
```

### 删除和弃用

本次更新中删除和弃用了多个 API，需要使用新的替代方案。

## 构建系统

### 移除已弃用的隐式根模块

构建系统中已移除对隐式根模块的支持，需要在构建脚本中明确指定模块：

```zig
// 旧的 build.zig
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
}
```

⬇️

```zig
// 新的 build.zig
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
}
```

### macOS 文件系统监视

在 macOS 上，构建系统现在支持文件系统监视功能，能够在文件更改时自动触发重建：

```bash
# 启用文件系统监视
zig build --watch

# 设置去抖动时间（默认50ms）
zig build --watch --debounce 100
```

### Web 界面和即时报告

构建系统现在支持 Web 界面和详细的即时报告功能。

## 编译器

### x86 后端

在 **调试编译** 默认为 **x86 后端** 的情况下，其速度提高了 5 倍。这也是本次更新最显著的性能改进：

```bash
# 使用新的 x86 后端（默认）
zig build -Doptimize=Debug

# 如果需要使用 LLVM 后端
zig build -Doptimize=Debug -fLLVM
```

### aarch64 后端

**aarch64 后端** 的开发也在稳步推进，为 ARM 平台提供更好的支持。

### 增量编译

增量编译功能得到了改进：

```bash
# 启用增量编译
zig build -fincremental

# 结合文件系统监视
zig build -fincremental --watch

# 仅检查编译错误（不生成二进制文件）
zig build -fincremental -fno-emit-bin --watch
```

### 多线程代码生成

编译器现在支持多线程代码生成：

```bash
# 控制编译线程数
zig build -j4  # 使用 4 个线程
zig build -j   # 使用所有可用 CPU 核心

# 禁用多线程编译
zig build -j1
```

### 允许在模块级别配置 UBSan 模式

现在可以在模块级别配置 UBSan（未定义行为检测器）：

```zig
// build.zig 中的配置
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = true, // 启用 C 代码的 UBSan
    }),
});

// 或者使用命令行
zig build -Dsanitize-c
```

### 将测试编译为目标文件

现在可以将测试编译为目标文件而不是可执行文件：

```bash
# 将测试编译为 .o 文件
zig test src/main.zig --object

# 将测试编译为静态库
zig test src/main.zig --library

# 将测试编译为动态库
zig test src/main.zig --dynamic-library
```

### Zig 初始化

`zig init` 命令得到了改进：

```bash
# 创建新项目
zig init

# 创建库项目
zig init --lib

# 创建可执行项目
zig init --exe

# 指定项目名称
zig init --name my-project

# 在现有目录中初始化
zig init .
```

## 链接器

链接器得到了多项改进和优化。

## 模糊测试器

Zig 0.15.1 集成了一个内置的模糊测试器：

```bash
# 启动模糊测试
zig build test --fuzz

# 指定端口
zig build test --fuzz --port 8080

# 指定测试时间
zig build test --fuzz --timeout 60
```

```zig
// 模糊测试例子
test "fuzz string parsing" {
    const input_bytes = std.testing.fuzzInput(.{});

    // 测试字符串解析函数
    const result = parseString(input_bytes);

    // 确保不会崩溃
    _ = result catch |err| {
        // 预期的错误可以忽略
        if (err == error.InvalidInput) return;
        return err;
    };
}

fn parseString(input: []const u8) ![]const u8 {
    if (input.len == 0) return error.InvalidInput;
    // 解析逻辑...
    return input;
}
```

## 错误修复

本次发布修复了大量错误。

## 本次发布包含的错误

Zig 目前仍存在一些已知的 bugs，包括一些编译错误。

## 工具链

### LLVM 20

本次更新升级到 LLVM 20，带来了以下改进：

- 更好的优化支持
- 新的目标架构支持
- 改进的调试信息生成
- 更好的 C++ 交互性

### 在交叉编译时支持动态链接的 FreeBSD libc

```bash
# 交叉编译到 FreeBSD
zig build -Dtarget=x86_64-freebsd-gnu
zig build -Dtarget=aarch64-freebsd-gnu

# 使用动态链接的 libc
zig build -Dtarget=x86_64-freebsd-gnu -Ddynamic-linker
```

### 在交叉编译时支持动态链接的 NetBSD libc

```bash
# 交叉编译到 NetBSD
zig build -Dtarget=x86_64-netbsd-gnu
zig build -Dtarget=aarch64-netbsd-gnu

# 使用 NetBSD 系统 libc
zig cc -target x86_64-netbsd-gnu program.c
```

### glibc 2.42

升级到 glibc 2.42，并支持静态链接本地 glibc：

```bash
# 使用系统 glibc 静态链接
zig build -Dtarget=native-linux-gnu -Dlinkage=static

# 指定 glibc 版本
zig build -Dtarget=x86_64-linux-gnu.2.42
```

#### 允许静态链接本机 glibc

现在可以静态链接本机系统的 glibc。

### MinGW-w64

MinGW-w64 工具链得到了更新：

```bash
# Windows 交叉编译
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-windows-gnu

# 使用 MinGW-w64 工具链
zig cc -target x86_64-windows-gnu program.c
```

### zig libc

`zig libc` 命令得到了增强：

```bash
# 查看当前目标的 libc 配置
zig libc

# 查看指定目标的 libc
zig libc -target x86_64-linux-gnu

# 查看所有可用的 libc
zig targets | grep libc
```

### zig cc

`zig cc` 作为 C 编译器的功能得到了增强：

```bash
# 更好的 GCC 兼容性
zig cc -std=c11 -O2 program.c

# 支持更多编译选项
zig cc -march=native -mtune=native program.c

# 更好的错误报告
zig cc -Wall -Wextra program.c
```

### zig objcopy 回归

`zig objcopy` 命令存在一些回归问题，正在修复中。

## 路线图

### I/O 作为接口

I/O 系统将继续作为接口进行发展和完善。

## 升级建议

由于此次更新包含多项破坏性更改，建议开发者在升级至 0.15.1 版本时：

### 升级步骤

1. **备份现有代码**：在开始升级之前做好备份

2. **分步骤进行**：
   - 首先处理 `usingnamespace` 的移除
   - 然后处理 I/O 系统的重构
   - 最后处理 ArrayList 等容器的变更

3. **使用编译器检查**：

   ```bash
   # 检查编译错误
   zig build-exe src/main.zig

   # 使用新的 x86 后端加速编译
   zig build -fno-LLVM
   ```

4. **测试全面性**：确保所有功能在新版本下正常运行
5. **利用新特性**：
   - 使用新的 x86 后端提高编译速度
   - 使用文件系统监视功能
   - 尝试增量编译

### 常见问题和解决方案

1. **I/O 代码编译错误**：参考上面的 Writergate 部分
2. **`usingnamespace` 错误**：使用显式导入替代
3. **ArrayList 错误**：改为使用 ArrayListUnmanaged
4. **格式化错误**：更新 format 方法签名

## 注意事项

- 这次升级的破坏性更改较多，建议在测试环境中进行充分测试
- I/O 接口的重构可能需要较多的代码调整工作
- 新的性能改进主要体现在编译速度上
- 文件系统监视功能有助于提高开发效率

完整的发布说明可在 [Zig 官方网站](https://ziglang.org/download/0.15.1/release-notes.html) 查看。
