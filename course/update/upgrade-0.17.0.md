---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.16.0` 版本升级到 `0.17.0`。

和 `0.16.0` 那次以 `std.Io` 为核心的大迁移相比，`0.17.0` 对日常业务代码的冲击要小一些，但仍然有几类必须处理的破坏性变更：

- **语法清理**：数组乘法 `**`、`errdefer |err|`、`void{}`、`i0` 被移除
- **`@cImport` 被正式移除**，C 头文件翻译需要迁移到构建系统中的 translate-c 包
- **类型反射改为“数组结构体”风格**，`@typeInfo(T).@"struct".fields` 等写法需要改写
- **`@bitCast` 对数组 / 向量的语义变为与端序无关**，可能在没有编译错误的情况下改变行为
- **构建系统拆分为配置进程与执行进程**，`b.build_root`、`b.args` 等 API 被移除，配置阶段的副作用需要显式声明
- **分配器重做**：`DebugAllocator` → `SafeAllocator`，`stackFallback` → `BufferFirstAllocator`

::: tip 🅿️ 推荐的升级顺序

1. 先手动处理**语法层面**的移除项（`**`、`errdefer |err|`、`void{}`、`i0`）。`0.17.0` 的 `zig fmt` 无法解析这些已被移除的语法，不先处理的话 `zig fmt` 会直接报错
2. 运行一次 `zig fmt`，它会自动把 `@intFromEnum` / `@enumFromInt` 升级为 `@backingInt` / `@fromBackingInt`
3. 修复 `build.zig`，确保构建脚本本身能够跑起来
4. 按编译错误逐个修复标准库与反射相关的 API
5. 最后审查所有涉及数组或向量的 `@bitCast`，这一类问题**不会产生编译错误**

:::

::: warning 关于编辑器支持

由于构建系统的配置进程与执行进程被拆分，**ZLS 目前暂时无法与 `0.17.0` 配合使用**。如果你非常依赖 ZLS，可以先在独立分支上完成迁移，等待 ZLS 跟进后再切换。

:::

## 语言变动

### 数组乘法 `**` 被移除

数组乘法语法 `a ** b` 被移除了。最常见的用法——用同一个值填充数组——应当改为 `@splat`：

```zig
// 0.16.0
var buffer = [_]u8{0} ** 1024;
const line = "-" ** 40;

// 0.17.0
var buffer: [1024]u8 = @splat(0);
const line: [40]u8 = @splat('-');
```

`@splat` 依赖结果类型，因此需要显式写出数组类型。如果没有结果位置，可以配合 `@as` 使用：`@as([1024]u8, @splat(0))`。需要哨兵时也可以直接写：`const s: [40:0]u8 = @splat('-');`。

对结构体字段同样适用：

```zig
pub const init: RollingIntegralImage = .{
    // 0.16.0: .data = [1]Float{0} ** data_size,
    .data = @splat(0),
    .num_rows = 0,
};
```

如果重复的是**多个元素组成的模式**，次数较少时可以直接用 `++` 拼接，次数较多时可以写一个编译期辅助函数：

```zig
const small = [_]u8{ 1, 2 };
const big = small ++ small ++ small; // { 1, 2, 1, 2, 1, 2 }

fn repeat(comptime T: type, comptime pattern: []const T, comptime n: usize) [pattern.len * n]T {
    var result: [pattern.len * n]T = undefined;
    for (0..n) |i| @memcpy(result[i * pattern.len ..][0..pattern.len], pattern);
    return result;
}

const pat = repeat(u8, &.{ 1, 2 }, 3); // { 1, 2, 1, 2, 1, 2 }
```

### `errdefer` 捕获被移除

`errdefer |err|` 不再被允许。官方给出的迁移方式是**把函数拆成两层**：内层保留原来的逻辑（包括不带捕获的 `errdefer`），外层通过 `catch |err|` 观察错误：

```zig
// 0.16.0
fn processOneTarget(job: Job) void {
    errdefer |err| std.debug.panic("panic: {s}", .{@errorName(err)});
    const target = job.target;
    // ...
}

// 0.17.0
fn processOneTarget(job: Job) void {
    processOneTargetInner(job) catch |err| std.debug.panic("panic: {s}", .{@errorName(err)});
}

fn processOneTargetInner(job: Job) !void {
    const target = job.target;
    // ...
}
```

如果原来的 `errdefer |err|` 只是用来记录日志，外层可以在记录后继续把错误返回：

```zig
fn processOne(fail: bool) !void {
    processOneInner(fail) catch |err| {
        std.log.err("failed: {t}", .{err});
        return err;
    };
}

fn processOneInner(fail: bool) !void {
    // 不需要观察错误的清理逻辑可以继续使用 errdefer
    errdefer std.log.debug("cleanup", .{});
    if (fail) return error.Oops;
}
```

### `void{}` 与 `i0` 被移除

这两项都是简单的替换：

- `void{}` 改为 `{}`
- `i0` 改为 `u0`（`i0` 本身没有意义，几乎所有用法都可以透明地替换为 `u0`）

### `@cImport` 被移除，改用 translate-c 包

`@cImport` 在 `0.16.0` 中已经被标记为 deprecated，`0.17.0` 将其正式移除。同时，构建系统内置的 `b.addTranslateC` 也被标记为 deprecated（暂时仍可使用），官方推荐改为依赖 ZSF 官方维护的 [translate-c](https://codeberg.org/ziglang/translate-c) 包。

首先把它添加为依赖。注意 **translate-c 的版本需要与 Zig 版本匹配**，适配 `0.17.0` 的是 `2.0.0` 版本：

```sh
zig fetch --save git+https://codeberg.org/ziglang/translate-c#2.0.0
```

然后准备一个头文件作为翻译入口，把原来写在 `@cImport` 里的内容搬进去：

```c
// src/c.h
#define _NO_CRT_STDIO_INLINE 1
#include <stdio.h>
#include <math.h>
```

最后在 `build.zig` 中翻译该头文件，并把翻译结果作为模块导入：

```zig
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.dependency("translate_c", .{});
    const c: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
        // 默认会链接 libc；需要链接系统库时可以在这里声明，
        // 翻译时也会自动包含对应库的头文件
        // .link_system_libs = &.{.{ .name = "glfw3" }},
    });
    // 翻译时需要的额外头文件目录
    // c.addIncludePath(b.path("include"));

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = c.mod },
            },
        }),
    });
    b.installArtifact(exe);
}
```

源码中的改动就很简单了：

```zig
// 0.16.0
const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
});

// 0.17.0
const c = @import("c");
```

有几点需要注意：

- `@cDefine`、`@cUndef` 对应头文件里的 `#define` / `#undef`；也可以使用 `Translator` 的 `defineCMacro` 等方法
- 原来写在 `@cImport` 里的多个 `@cInclude`，可以合并到同一个头文件中，一次性翻译成一个模块
- `zig translate-c` 命令行子命令依然可以用来查看翻译结果

### `@intFromEnum` / `@enumFromInt` 改为 `@backingInt` / `@fromBackingInt`

`@intFromEnum` 和 `@enumFromInt` 被标记为 deprecated，取而代之的是 `@backingInt` 和 `@fromBackingInt`。**`zig fmt` 会自动完成这一替换**，但有一处需要手动处理：`@fromBackingInt` 的参数必须**恰好**是枚举的底层整数类型，不再接受其他整数类型，因此通常需要补一个 `@intCast`：

```zig
const Color = enum(u4) { red, green, blue = 8 };

const n: usize = 8;

// 0.16.0
const c: Color = @enumFromInt(n);
const i = @intFromEnum(c);

// 0.17.0
const c: Color = @fromBackingInt(@intCast(n));
const i = @backingInt(c); // u4
```

另外：

- `@backingInt` 也可以用于显式指定了底层整数类型的 `packed struct` / `packed union`，以及带标记的联合类型（返回当前激活标记的底层整数）
- 可以用 `std.meta.BackingInt(T)` 获取 `@backingInt` 的结果类型
- 空枚举现在必须以 `noreturn` 作为底层类型：`const Empty = enum(noreturn) {};`
- 当 `@bitCast` 的目标是枚举类型时，现在也会对无效的标记值进行安全检查

### `@bitCast` 对数组 / 向量的语义与端序无关

这是本次升级中**最需要人工审查**的一项，因为它可能在没有任何编译错误的情况下改变程序行为。

`@bitCast` 现在作用于值的**逻辑位表示**：整数从最低有效位开始；数组和向量则从第一个元素开始，依次拼接各元素的位。结果与目标的端序无关：

```zig
const bytes: [2]u8 = .{ 0x34, 0x12 };
const x: u16 = @bitCast(bytes);
// 0.17.0 中，无论大端还是小端，x 都等于 0x1234
// 0.16.0 中，大端目标上的结果是 0x3412
```

在小端目标上，新行为与旧行为基本一致；但如果你的代码运行在大端目标上，或者原本就依赖“按内存布局重新解释”的语义，就需要修改。根据实际意图，可以选择：

```zig
// 1. 需要明确的字节序时，使用 std.mem.readInt / writeInt
const le = std.mem.readInt(u16, &bytes, .little);
const be = std.mem.readInt(u16, &bytes, .big);

// 2. 需要“按内存布局”重新解释时，使用 @ptrCast
const int_ptr: *align(1) const u16 = @ptrCast(&bytes);
const native = int_ptr.*;
```

此外，`@bitCast` **不再允许用于 `extern struct` / `extern union`**。这类代码本质上是在做 type punning，请改用 `@ptrCast`、`extern union`，或者借助 `std.mem.toBytes` / `std.mem.bytesToValue`。

### `@hasDecl` 只对 `pub` 声明返回 `true`

以前，`@hasDecl` 对“同一文件中的非 `pub` 声明”也会返回 `true`，现在不再如此：

```zig
const Foo = struct {
    bar: i32,

    const baz = 1;
    pub var quux = "xxx";
};

test "@hasDecl example" {
    try std.testing.expect(!@hasDecl(Foo, "bar"));
    try std.testing.expect(!@hasDecl(Foo, "baz")); // 0.17.0 中变为 false
    try std.testing.expect(@hasDecl(Foo, "quux"));
}
```

如果你在同一个文件里用 `@hasDecl` 检测私有声明（常见于根据可选声明切换实现的泛型代码），需要把被检测的声明标记为 `pub`。

### `internal` 与 `link_once` 链接属性被移除

`std.lang.GlobalLinkage` 中的 `.internal` 和 `.link_once` 被移除：

- `.link_once` 的用途大多可以改用 `.weak`
- `.internal` 的替代方式是：一开始就不要 `@export` 这个符号

### 顺手可以用上的新特性

- `@divCeil`：向正无穷取整的整数除法，可以替换 `std.math.divCeil(a, b) catch unreachable`
- 长度在编译期已知的切片，现在可以直接解引用为数组（`slice.*`），或强制转换为数组指针
- `@SpirvType`：在 SPIR-V 目标上声明 image、sampler 等类型

```zig
try expectEqual(2, @divCeil(5, 3));
try expectEqual(-1, @divCeil(-5, 3));

const slice: []const u16 = &.{ 1, 2, 3 };
const array: [3]u16 = slice.*;
const array_ptr: *const [3]u16 = slice;
```

## 标准库

### `std.builtin` 改名为 `std.lang`

`std.builtin` 被标记为 deprecated，改为 `std.lang`。像 `std.builtin.Type`、`std.builtin.CallingConvention`、`std.builtin.Endian` 这样的写法，都可以直接替换为 `std.lang.Type`、`std.lang.CallingConvention`、`std.lang.Endian`。

### `OptimizeMode` 改为 `Optimize`，标签名去掉 “release”

`std.lang.OptimizeMode` 更名为 `std.lang.Optimize`，枚举标签也改成了小写且去掉了 “release”：

| 0.16.0         | 0.17.0  |
| :------------- | :------ |
| `Debug`        | `debug` |
| `ReleaseSafe`  | `safe`  |
| `ReleaseFast`  | `fast`  |
| `ReleaseSmall` | `small` |

虽然标准库提供了向后兼容的声明，但**与旧名称进行 `==` / `!=` 比较的代码将无法编译**，需要改写：

```zig
const builtin = @import("builtin");

// 0.16.0
if (builtin.mode == .Debug) {}

// 0.17.0
if (builtin.mode == .debug) {}
```

在 `build.zig` 中，函数签名里的类型也需要改名：

```zig
// 0.16.0
fn addExample(b: *std.Build, optimize: std.builtin.OptimizeMode) void {}

// 0.17.0
fn addExample(b: *std.Build, optimize: std.lang.Optimize) void {}
```

命令行参数也有了新名字：`-O fast`、`zig build -Doptimize=safe` 等。经测试，旧的 `-O ReleaseFast`、`-Doptimize=ReleaseFast` 目前仍然可以使用，但建议在脚本和 CI 中尽早改为新名称。

另外，推荐使用 `std.lang.Optimize.runtimeSafety` 来代替 `std.debug.runtime_safety`。

### `@import("builtin")` 中的冗余常量

`cpu`、`os`、`abi` 和 `object_format` 被标记为 deprecated，并将在 `0.18.0` 中移除：

```zig
const builtin = @import("builtin");

// 0.16.0
if (builtin.os.tag == .windows) {}

// 0.17.0
if (builtin.target.os.tag == .windows) {}
```

`object_format` 对应的是 `builtin.target.ofmt`。

### 类型反射改为“数组结构体”风格

这是本版本中改动面最广的一项。`@typeInfo` 返回的结构体、联合、枚举、函数等类型信息，不再是“由字段信息结构体组成的数组”，而是多个**并列的切片**。

**结构体**：

```zig
// 0.16.0
inline for (@typeInfo(S).@"struct".fields) |field| {
    try s.fieldPrefix(field.name);
    try printValue(field.type, @field(v, field.name));
}

// 0.17.0
const info = @typeInfo(S).@"struct";
inline for (info.field_names, info.field_types) |field_name, field_type| {
    try s.fieldPrefix(field_name);
    try printValue(field_type, @field(v, field_name));
}
```

字段的默认值、对齐、是否为 `comptime` 等属性，被放进了与 `field_names` 等长的 `field_attrs` 中，例如 `info.field_attrs[i].default_value_ptr`。声明的名称则位于 `info.decl_names`。

**枚举**：`field_names` 与 `field_values` 两个等长切片：

```zig
const e = @typeInfo(Color).@"enum";
// e.field_names[2] => "blue"
// e.field_values[2] => 8
```

**联合**：同样是 `field_names`、`field_types` 等并列切片。

**函数**：参数类型与参数属性被拆分开，调用约定、可变参数等则移进了 `attrs`：

```zig
const f = @typeInfo(@TypeOf(add)).@"fn";
// 0.16.0: f.params[0].type.?、f.params[1].is_noalias、f.calling_convention
// 0.17.0:
_ = f.param_types[0].?;
_ = f.param_attrs[1].@"noalias";
_ = f.attrs.@"callconv";
_ = f.return_type.?;
```

**指针**：`is_const`、`is_volatile`、`alignment`、`address_space`、`is_allowzero` 等字段被收进了 `attrs`，其中对齐值变为可选值——`null` 表示使用子类型的自然对齐：

```zig
const p = @typeInfo(*const align(8) u32).pointer;
// 0.16.0: p.is_const、p.alignment
// 0.17.0:
_ = p.attrs.@"const";
_ = p.attrs.@"align".?;
```

**错误集**：变为 `error_names: ?[]const [:0]const u8`，`null` 表示 `anyerror`。

与之相应，`std.meta.fieldNames`、`std.meta.fieldTypes`、`std.meta.fieldInfo` 也被标记为 deprecated，请直接使用 `@typeInfo(T).@"struct".field_names` 等字段。

::: tip 🅿️ 提示

`0.16.0` 中引入的 `@Struct`、`@Union`、`@Enum`、`@Fn`、`@Pointer` 等类型构造内建函数，本来就采用“名字数组 + 类型数组 + 属性数组”的形式传参。`0.17.0` 让 `@typeInfo` 的返回值也变成了同样的形式，因此“读取类型信息 → 修改 → 重新构造类型”的代码会比以前顺畅得多。

:::

### `DebugAllocator` 改为 `SafeAllocator`

`std.heap.DebugAllocator` 与 `std.heap.Check` 被标记为 deprecated，替代品是线程安全的 `std.heap.SafeAllocator`。它不再是泛型类型，配置通过 `init` 的参数传入，并且需要显式提供后备分配器：

```zig
// 0.16.0
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
defer if (debug_allocator.deinit() == .leak) @panic("memory leak");
const gpa = debug_allocator.allocator();

// 0.17.0
var safe_allocator: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});
defer if (safe_allocator.deinit() != 0) @panic("memory leak");
const gpa = safe_allocator.allocator();
```

注意 `deinit` 的返回值从 `Check` 枚举变成了**泄漏的数量**（`usize`）。原来的 `DebugAllocatorConfig` 对应 `SafeAllocator.Options`，可配置栈追踪帧数、canary 值等。

当然，如果你在 `0.16.0` 中已经改用了 `pub fn main(init: std.process.Init)`，直接使用 `init.gpa` 即可，不需要自己创建分配器。

### `stackFallback` 改为 `BufferFirstAllocator`

“先用栈上缓冲区、不够再回退到堆”的分配器被重做了。现在缓冲区由调用者传入，分配器不再对缓冲区大小泛型，也可以自由控制缓冲区的对齐。

需要注意，**发布说明里仍沿用了 `StackFallbackAllocator` 这个名字，但在 `0.17.0` 的标准库中，它的实际名称是 `std.heap.BufferFirstAllocator`**：

```zig
// 0.16.0
var stack align(@max(
    @alignOf(std.heap.StackFallbackAllocator(0)),
    @alignOf(Item),
)) = std.heap.stackFallback(@sizeOf(Item), gpa);
const allocator = stack.get();

// 0.17.0
var stack_buf: [256]u8 = undefined;
var stack: std.heap.BufferFirstAllocator = .init(&stack_buf, gpa);
const allocator = stack.allocator();
```

### `memory_pool` 的 managed 版本被移除

`std.heap.memory_pool.AlignedManaged` 与 `ExtraManaged` 被移除，请改用 `std.heap.memory_pool.Aligned` 与 `Extra`，并在调用时显式传入分配器。

### `fmt.allocPrint` 改为 `Allocator.print`

```zig
// 0.16.0
const s = try std.fmt.allocPrint(gpa, "{s}={d}", .{ x, y });

// 0.17.0
const s = try gpa.print("{s}={d}", .{ x, y });
```

`std.fmt.allocPrintSentinel` 对应 `Allocator.printSentinel`。旧函数目前仍然可用，但已被标记为 deprecated。

### `ArrayList` 的 `getLast` 系列

```zig
// 0.16.0
if (list.getLastOrNull()) |foo| {
    // ...
}
const foo = list.getLast();

// 0.17.0
if (list.last()) |foo| {
    // ...
}
const foo = list.last().?;
```

新增的 `lastPtr` 返回 `?*T`，可以用来原地修改最后一个元素。

### `std.zon.parse` 重做

`std.zon.parse` 现在接受结构体参数，结果从 arena 中分配，因此也不再需要 `parse.free`：

```zig
// 0.16.0
var diag: Diagnostics = .{};
defer diag.deinit(gpa);
const result = std.zon.fromSlice(MyZonType, gpa, source, &diag, .{}) catch |err| switch (err) {
    error.ParseZon => std.process.fatal("input.zon: {f}", .{diag}),
    error.OutOfMemory => |e| return e,
};
defer std.zon.parse.free(result);

// 0.17.0
var diag: Diagnostics = undefined;
const result = std.zon.fromSlice(MyZonType, .{
    .gpa = gpa,
    .arena = arena,
    .source = source,
    .diagnostics = &diag,
}) catch |err| switch (err) {
    error.ParseZon => diag.fatal("input.zon"),
    error.OutOfMemory => |e| return e,
};
```

另外请留意方法名的变化：原来的 `fromSliceAlloc` 改名为 `fromSlice`，而原来**不分配内存**的 `fromSlice` 改名为 `fromSliceNoAlloc`，其他 “from” 系列方法也按同样的规则改名。

### `bit_set` 类型与 `initEmpty` / `initFull`

| 0.16.0                         | 0.17.0                                     |
| :----------------------------- | :----------------------------------------- |
| `std.bit_set.IntegerBitSet`    | `std.bit_set.Integer`                      |
| `std.bit_set.ArrayBitSet`      | `std.bit_set.Array`                        |
| `std.StaticBitSet`             | `std.bit_set.Static`                       |
| `std.DynamicBitSetUnmanaged`   | `std.bit_set.Dynamic`                      |
| `std.DynamicBitSet`            | `std.bit_set.DynamicManaged`（deprecated） |
| `.initEmpty()` / `.initFull()` | `.empty` / `.full`                         |

`std.enums.EnumSet` 的 `initEmpty` / `initFull` 也同样改为 `empty` / `full`：

```zig
// 0.16.0
var set = std.bit_set.IntegerBitSet(8).initEmpty();

// 0.17.0
var set: std.bit_set.Integer(8) = .empty;
```

### `Uri.getHost` 改为 `HostName.fromUri`

```zig
var host_buf: [HostName.max_len]u8 = undefined;

// 0.16.0
const host = try uri.getHost(&host_buf);

// 0.17.0
// 注意错误集与之前不同，因为 fromUri 会进行校验
const host = try HostName.fromUri(uri, &host_buf);
```

`Uri.getHostAlloc` 被直接移除。由于语义差异较大，这里没有提供平滑的弃用过渡，需要逐一评估调用处。

### 其他需要顺手处理的改名

| 0.16.0                                                   | 0.17.0                          |
| :------------------------------------------------------- | :------------------------------ |
| `std.gpu`                                                | `std.spirv`                     |
| `std.DoublyLinkedList.pop`                               | `std.DoublyLinkedList.popLast`  |
| `std.ascii.indexOfIgnoreCase` 系列                       | `std.ascii.findIgnoreCase` 系列 |
| `std.mem.containsAtLeastScalar2`                         | `std.mem.containsAtLeastScalar` |
| `std.mem.readPackedIntNative` / `readPackedIntForeign`   | `std.mem.readPackedInt`         |
| `std.mem.writePackedIntNative` / `writePackedIntForeign` | `std.mem.writePackedInt`        |
| `std.Target.parseCpuModel` 返回错误                      | 返回可选值                      |

还有一处行为变化：`std.mem.eql` 与 `std.mem.findDiff` 在比较**浮点切片**时，不再因为“两个切片指向同一块内存”而直接返回相等，因此包含 `nan` 的同一个切片与自身比较时会返回 `false`。

## 构建系统

`0.17.0` 的构建系统被拆分为两个进程：**配置进程（configurer）**负责运行你的 `build.zig` 并生成构建图，**执行进程（maker）**负责包管理和执行构建图。配置结果会被缓存，在配置没有变化时，`zig build` 可以完全跳过 `build.zig` 的执行。

这带来了两条新的基本规则：

1. **`build` 函数里不应该再有副作用**，例如直接 spawn 子进程、写文件；需要在构建过程中做的事情，都应该声明为构建步骤
2. **配置逻辑读取了哪些外部状态，就需要显式声明**，否则配置缓存可能无法及时失效

### `b.build_root` 改为 `b.root`

`b.build_root`（`Directory`）被移除，改为 `b.root`，类型是 `Cache.Path`。如果需要在配置阶段遍历项目中的目录：

```zig
// 0.16.0
const full_path = try std.process.currentPathAlloc(io, b.allocator);
var dir = try std.Io.Dir.openDirAbsolute(io, full_path, .{ .iterate = true });

// 0.17.0
const io = b.graph.io;
// 配置逻辑依赖该目录中的条目，需要显式声明，
// 这样新增、删除或重命名文件后才会重新执行配置
b.dependOnDirectoryContents(b.path("examples"));
var dir = try b.root.openDir(io, "examples", .{ .iterate = true });
defer dir.close(io);
```

### 在配置阶段声明外部依赖

与上面的 `dependOnDirectoryContents` 类似，构建系统提供了四个函数，用来声明配置逻辑依赖的外部状态：

| 函数                          | 何时使配置缓存失效                      |
| :---------------------------- | :-------------------------------------- |
| `b.dependOnFileContents`      | 文件内容发生变化                        |
| `b.dependOnFileMetadata`      | 文件的大小、inode、mtime 或内容发生变化 |
| `b.dependOnDirectoryContents` | 目录中有条目被添加、删除或重命名        |
| `b.dependOnDirectoryMetadata` | 目录的最后修改时间发生变化              |

而像 `b.findProgram` 这类无法被精确追踪的操作，或者直接调用 `b.graph.poisonCache()`，会让配置缓存“被污染”：这样仍然能得到正确的结果，只是每次都需要重新执行 `build.zig`。

如果想确认自己的构建脚本是否“纯净”，可以使用 `zig build --cache-poison=disallowed`：一旦配置缓存将被污染，构建就会直接 panic，方便定位问题。

### 不要在 `build` 函数里直接执行命令

过去有些构建脚本会在 `build` 函数中直接用 `std.process.spawn` 等方式运行命令（例如依次构建子项目）。在新的模型下，应当把这些操作声明为 `Run` 步骤，交给执行进程去完成：

```zig
// 0.16.0：在配置阶段直接 spawn 子进程
var child = try std.process.spawn(io, .{
    .argv = &.{ "zig", "build" },
    .cwd = .{ .path = sub_dir },
});
_ = try child.wait(io);

// 0.17.0：声明为 Run 步骤，在执行阶段运行
const sub_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
sub_build.setName("zig build (sub project)");
sub_build.setCwd(b.path("sub_project"));
sub_build.stdio = .inherit;
b.getInstallStep().dependOn(&sub_build.step);
```

### `b.args` 改为 `run.addPassthruArgs()`

`b.args` 被移除了。构建脚本不再能在配置阶段读到 `zig build run -- arg1 arg2` 中 `--` 之后的参数，而是声明一个“透传参数”的占位，由执行进程在运行时替换。作为交换，修改这些参数时不再需要重新执行构建脚本：

```zig
const run_cmd = b.addRunArtifact(exe);

// 0.16.0
if (b.args) |args| {
    run_cmd.addArgs(args);
}

// 0.17.0
run_cmd.addPassthruArgs();
```

### `Run` 步骤的参数方法统一为 `...Arg2`

`Run` 步骤中原来成对出现的 `addXxxArg` / `addPrefixedXxxArg` 被统一为带选项结构体的 `...Arg2` 版本，旧方法被标记为 deprecated：

```zig
// 0.16.0
run.addArtifactArg(exe);
run.addPrefixedFileArg("--input=", b.path("data.txt"));
const out = run.addPrefixedOutputFileArg("-o", "out.bin");

// 0.17.0
run.addArtifactArg2(exe, .{});
run.addFileArg2(b.path("data.txt"), .{ .prefix = "--input=" });
const out = run.addOutputFileArg2("out.bin", .{ .prefix = "-o" });
```

路径类参数的选项中还有 `suffix` 和 `make_absolute`（把路径转为绝对路径后再传给子进程）。其他方法同理：`addDirectoryArg2`、`addOutputDirectoryArg2`、`addFileContentArg2`、`addDepFileOutputArg2`。

### `findProgram` 与 `findProgramLazy`

`b.findProgram` 的签名发生了变化，并且新增了不会污染配置缓存的 `findProgramLazy`：

```zig
// 0.16.0
const python = try b.findProgram(&.{ "python3", "python" }, &.{});

// 0.17.0：在配置阶段立即查找，找不到返回 null，会污染配置缓存
const python = b.findProgram(.{ .names = &.{ "python3", "python" } });

// 0.17.0：返回 LazyPath，只有在被某个步骤用到时才会真正查找
const python_lazy = b.findProgramLazy(.{ .names = &.{ "python3", "python" } });
```

如果配置逻辑并不需要知道“程序是否存在”，只是要在某个步骤里调用它，优先使用 `findProgramLazy`。

### 其他构建 API 的变化

- `LazyPath.getDisplayName()` 改为通过 `"{f}"` 格式化打印 `LazyPath`
- `LazyPath.basename` 被移除，因为该值在执行阶段之前是未知的
- `ConfigHeader.Options` 中的 `include_guard_override` 改为 `include_guard`；另外 `ConfigHeader` 现在对所有风格都会报告未使用的值
- `Fmt` 步骤的 `paths` / `exclude_paths` 现在是 `LazyPath` 列表，可以使用 `b.pathList(&.{ "src", "build.zig" })` 创建
- `Step.Options` 添加路径时需要显式选择 `addOptionPath`（文件）、`addOptionPathDirectory`（目录）或 `addOptionPathUntracked`（不追踪）
- `b.dependency` 现在也支持惰性依赖；新增的 `b.dependencyLazy` 返回 `error{LazyDependencyNeeded}!*Dependency`，可以配合 `try` 使用
- 覆盖 build runner 的能力被移除；需要读取构建图的工具，可以使用 `zig build --print-configuration` 或 Build Server Protocol（`--listen=-`）
- Windows 资源相关的 API（如 `Module.addWin32ResourceFile`）被标记为 deprecated，将在下一个版本移到独立的包中
- 以 Windows 或 Wine 为目标时，`Run` 步骤只会根据 `argv[0]` 的 DLL 依赖修改 `PATH`，而不再对所有 artifact 参数这样处理

### 包管理

- `zig fetch <url>` 现在只抓取到全局缓存；只有使用 `--save` 时才会同时抓取到项目本地的包目录（默认是 `zig-pkg`），全局抓取时也不再要求存在 `build.zig`
- `zig build` 总是会把依赖抓取到项目本地（同时也会抓取到全局缓存）
- `--pkg-path` 参数与 `ZIG_LOCAL_PKG_DIR` 环境变量现在对 fetch 和 build 命令都生效
- 修复了路径依赖可以逃逸出父包根目录的 bug，如果你的项目依赖了这种行为，需要调整依赖布局

### 增量编译

在 `x86_64-linux` 上，现在大多数项目都可以通过 `zig build -fincremental --watch` 使用增量编译，修改源码后几乎可以立即完成重新构建，值得一试。

## 工具链与环境

- **macOS 的最低版本要求提升到了 15.0**，DragonFly BSD 提升到了 6.4。如果你的 CI 使用较旧的 macOS runner，需要相应升级
- `libc.txt` 中的 `gcc_dir` 字段更名为 `cc_dir`，并且在 Linux 目标上变为必填项
- 移除了 `powerpc-linux-gnueabi[hf]` 与 `powerpc64-linux-gnu` 目标
- `x86_64-macos`、`x86-windows` 等目标被标记为“过时”，后续版本可能移除支持
- 官方列出的已知回归中，#36444 会影响在 `Run` 步骤中使用响应文件（response file）的场景，如果你的构建依赖这种用法，升级前请先评估

## 小结

总体来说，`0.17.0` 的迁移可以分为三块：

- **语法与内建函数**：大部分是机械替换，`zig fmt` 能自动处理一部分，`errdefer` 捕获需要拆函数
- **反射与标准库**：类型反射的数组结构体风格是改动最集中的部分，分配器、`bit_set`、`zon` 等 API 按编译错误逐个处理即可
- **构建系统**：理解“配置与执行分离、配置可缓存”这一新模型之后，`b.build_root`、`b.args`、在 `build` 函数中执行命令等问题都会迎刃而解

完成迁移之后，你会得到一个更快、更易缓存的构建流程，以及一门正在加速走向稳定的语言。
