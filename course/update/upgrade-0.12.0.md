---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.11.0` 版本升级到 `0.12.0`。

## 语言变动

### 非必要不使用 `var`

引入了一个新的编译错误，当局部变量声明为 `var` 但使用 `const` 就足够时，编译器会发出该错误！

```zig
const expectEqual = @import("std").testing.expectEqual;
test "unnecessary use of var" {
    var x: u32 = 123;
    try expectEqual(123, x);
}
```

```sh
$ zig test unnecessary_var.zig
docgen_tmp/unnecessary_var.zig:3:9: error: local variable is never mutated
    var x: u32 = 123;
        ^
docgen_tmp/unnecessary_var.zig:3:9: note: consider using 'const'
```

解决该错误也很简单，使用 `const` 即可！

### 结果位置语义

对结果位置语义 _Result Location Semantics (RLS)_ 的多项增强。

::: info

结果位置语义是 Zig 语言中的一个特性，它影响函数如何返回结果和错误。

:::

结果类型（result types）可以通过取地址运算符（`&`）进行传递。这允许依赖结果类型的语法结构，如匿名初始化 `.{ ... }` 和像 `@intCast` 这样的转换内建函数，在存在取地址运算符的情况下正确地工作。这是一种新的特性，可以使代码在处理结果类型时更加灵活和准确。

```zig
const S = struct { x: u32 };
const int: u64 = 123;
const val: *const S = &.{ .x = @intCast(int) };
comptime {
    _ = val;
}
```

::: info

此外，在这个版本中，结果位置（**result locations**）不能通过 `@as` 和明确类型的聚合初始化 `T{ ... }` 进行传播。这个限制是为了简化语言设计。在之前的版本中，有几个关于结果指针（result pointers）错误转换的 bug，这个更改就是为了解决这些问题。

:::

### 解构语法（Aggregate Destructuring）

引入了新语法，允许对可索引的聚合结构（如元组、向量和数组）进行解构。在赋值操作的左侧编写一系列的左值或本地变量声明，将尝试解构右侧指定的值。这是一种新的赋值方式，可以更方便地从聚合结构中提取值：

```zig
var z: u32 = undefined;
const x, var y, z = [3]u32{ 1, 2, 3 };
y += 10;
// x 是 1，y 是 2，z 是 3

const x, const y = @Vector(2, u32){ 1, 2 };
// 编译期的值也会进行解构，x 是 1，y 是 2

var runtime: u32 = undefined;
runtime = 123;
const x, const y = .{ 42, runtime };
// 当然，编译期和运行时的值也会被正确解析
// x 是编译期可以知道的值 42
// y 是运行时可知的值 123

```

::: warning

**切片**（slices）不能直接被解构，如果想从切片中解构值，需要将它转换为数组，方法是使用编译时已知的边界进行切割，例如 `slice[0..3].*`。这样，就可以像处理数组一样处理切片，从而实现解构。

:::

### 命名空间类型等价性

在 Zig 中，结构体（`struct`）、枚举（`enum`）、联合体（`union`）和不透明类型（`opaque types`）是特殊的，它们不像元组和数组那样使用结构等价性，而是创建独特的类型。这些类型有命名空间，因此可能包含声明，它们可以统称为"命名空间类型"。

在 `0.11.0` 版本中，每次这样的类型声明被语义分析时，都会创建一个新的类型。泛型类型的等价性是通过对编译时函数调用的记忆化（memoization）来处理的；也就是说，`std.ArrayList(u8) == std.ArrayList(u8)` 成立，因为 `ArrayList` 函数只被调用一次，其结果被记忆化。

在 0.12.0 版本中，这一点发生了变化。现在，命名空间类型基于两个因素进行去重：它们的源位置和它们的捕获。

类型的"捕获"指的是它闭包覆盖的编译时已知类型和值的集合。换句话说，它是在类型内部引用但在类型外部声明的值的集合。例如，`std.ArrayList` 的编译时 `T: type` 参数被它返回的类型捕获。如果两个命名空间类型由同一段代码声明并且有相同的捕获，那么它们现在被认为是完全相同的类型。

请注意，编译器仍然会记忆化编译时调用：这一点没有改变。然而，这种记忆化对语言语义的影响已经不再有意义。

这种实现的更改不太可能带来改变，但需要注意以下情况：

```zig
fn MakeOpaque(comptime n: comptime_int) type {
    _ = n;
    return opaque {};
}
const A = MakeOpaque(0);
const B = MakeOpaque(1);
```

在 Zig `0.11.0` 版本中，这段代码会创建两个不同的类型，因为对 `MakeOpaque` 的调用是不同的，因此每次调用都会单独分析不透明声明。而在 `Zig 0.12.0` 版本中，这些类型是相同的（A == B），因为虽然函数被调用了两次，但声明并没有捕获任何值。

要修正这个问题也很简单，强制捕获 `n` 就可以了：

```zig
fn MakeOpaque(comptime n: comptime_int) type {
    return opaque {
        comptime {
            _ = n;
        }
    };
}
const A = MakeOpaque(0);
const B = MakeOpaque(1);
```

由于 `n` 被 `opaque` 强制引用，将会产生两个不同的类型！

### 编译期内存变化

对编译器的编译时内存（comptime memory）的内部表示，特别是编译时可变内存（即 `comptime var`）进行了全面改革。这次改革带来了一些面向用户的变化，以新的限制的形式出现，限制了你可以对 `comptime var` 做什么。

第一个也是最重要的新规则是，永远不允许指向 a comptime var 的指针成为运行时已知的。例如：

```zig
test "runtime-known comptime var pointer" {
    comptime var x: u32 = 123;
    // `var` 使得 `ptr` 运行时可知
    var ptr: *const u32 = undefined;
    ptr = &x;
    if (ptr.* != 123) return error.TestFailed;
}
```

```sh
$ zig test comptime_var_ptr_runtime.zig
docgen_tmp/comptime_var_ptr_runtime.zig:5:11: error: runtime value contains reference to comptime var
    ptr = &x;
          ^~
docgen_tmp/comptime_var_ptr_runtime.zig:5:11: note: comptime var pointers are not available at runtime
```

在早期版本的 Zig 中，此测试会通过。现在，编译器会报告编译错误，因为对 `ptr` 的赋值使得值 `&x`（这是一个指向 `comptime var` 的指针）变为运行时已知。

例如，通过将这样的指针传递给在运行时调用的函数，这些指针也可以变为运行时已知：

```zig
test "comptime var pointer as runtime argument" {
    comptime var x: u32 = 123;
    if (load(&x) != 123) return error.TestFailed;
}
fn load(ptr: *const u32) u32 {
    return ptr.*;
}
```

```sh
$ zig test comptime_var_ptr_runtime_arg.zig
docgen_tmp/comptime_var_ptr_runtime_arg.zig:3:14: error: runtime value contains reference to comptime var
    if (load(&x) != 123) return error.TestFailed;
             ^~
docgen_tmp/comptime_var_ptr_runtime_arg.zig:3:14: note: comptime var pointers are not available at runtime
```

现在，这个测试也会发出一个编译错误。`load` 的调用发生在运行时，它的 `ptr` 参数没有标记为 `comptime`，所以在 `load` 的主体内，`ptr` 是运行时已知的。这意味着调用 `load` 使得指针 `&x` 在运行时已知，因此产生了编译错误。

这个限制是为了修复一些反直觉的错误。当一个指向 comptime var 的指针变为运行时已知时，对它的修改变得无效，因为指向的数据变为常量，但类型系统没有反映这一点，导致在看似有效的代码中可能出现运行时段错误。此外，你在运行时从这样的指针读取的值将是它的"最终"编译时值，这是一种不直观的行为。因此，这些指针不能再是运行时已知的。

第二个新的限制是一个指向 `comptime var` 的指针永远不允许包含在全局声明的解析值中。例如：

```zig
const ptr: *const u32 = ptr: {
    var x: u32 = 123;
    break :ptr &x;
};
comptime {
    _ = ptr;
}
```

```sh
$ zig test comptime_var_ptr_global.zig
docgen_tmp/comptime_var_ptr_global.zig:1:30: error: global variable contains reference to comptime var
const ptr: *const u32 = ptr: {
                        ~~~~~^
referenced by:
    comptime_0: docgen_tmp/comptime_var_ptr_global.zig:6:9
    remaining reference traces hidden; use '-freference-trace' to see all reference traces
```

在这里，`ptr` 是一个全局声明，其值是一个指向 `comptime var` 的指针。这个声明在 `0.11.0` 中是允许的，但在 `0.12.0` 中会引发一个编译错误。在更复杂的情况下，同样的规则也适用，例如当指针包含在结构体字段中时：

```zig
const S = struct { ptr: *const u32 };
const val: S = blk: {
    var x: u32 = 123;
    break :blk .{ .ptr = &x };
};
comptime {
    _ = val;
}
```

```sh
$ zig test comptime_var_ptr_global_struct.zig
docgen_tmp/comptime_var_ptr_global_struct.zig:2:21: error: global variable contains reference to comptime var
const val: S = blk: {
               ~~~~~^
referenced by:
    comptime_0: docgen_tmp/comptime_var_ptr_global_struct.zig:7:9
    remaining reference traces hidden; use '-freference-trace' to see all reference traces
```

这段代码引发的编译错误与前一个例子相同。这个限制主要是为了帮助在 Zig 编译器中实现增量编译，这依赖于全局声明的分析是顺序无关的，以及声明之间的依赖关系可以被轻易地建模。

这种情况最常见的表现形式是在现有代码中出现编译错误，如果一个函数在编译时构造一个切片，然后在运行时使用。例如，考虑以下代码：

```zig
fn getName() []const u8 {
    comptime var buf: [9]u8 = undefined;
    // 在实践中，这里可能会有更复杂的逻辑来填充 buf
    @memcpy(&buf, "some name");
    return &buf;
}
test getName {
    try @import("std").testing.expectEqualStrings("some name", getName());
}
```

```sh
$ zig test construct_slice_comptime.zig
docgen_tmp/construct_slice_comptime.zig:5:12: error: runtime value contains reference to comptime var
    return &buf;
           ^~~~
docgen_tmp/construct_slice_comptime.zig:5:12: note: comptime var pointers are not available at runtime
referenced by:
    decltest.getName: docgen_tmp/construct_slice_comptime.zig:8:64
    remaining reference traces hidden; use '-freference-trace' to see all reference traces
```

调用 getName 返回一个切片，其 ptr 字段是一个指向 comptime var 的指针。这意味着这个值不能在运行时使用，也不能出现在全局声明的值中。这段代码可以通过在填充缓冲区后将计算的数据提升为 const 来修复：

```zig
fn getName() []const u8 {
    comptime var buf: [9]u8 = undefined;
    // In practice there would likely be more complex logic here to populate `buf`.
    @memcpy(&buf, "some name");
    const final_name = buf;
    return &final_name;
}
test getName {
    try @import("std").testing.expectEqualStrings("some name", getName());
}
```

像在 Zig 的早期版本中一样，编译时已知的 consts 具有无限的生命周期，这里讨论的限制不适用于它们。因此，这段代码会正常运行。

另一种可能的失败模式是在使用旧语义创建全局可变编译时状态的代码中。例如，以下片段试图创建一个全局的编译时计数器：

```zig
const counter: *u32 = counter: {
    var n: u32 = 0;
    break :counter &n;
};
comptime {
    counter.* += 1;
}
```

```sh
$ zig test global_comptime_counter.zig
docgen_tmp/global_comptime_counter.zig:1:32: error: global variable contains reference to comptime var
const counter: *u32 = counter: {
                      ~~~~~~~~~^
referenced by:
    comptime_0: docgen_tmp/global_comptime_counter.zig:6:5
    remaining reference traces hidden; use '-freference-trace' to see all reference traces
```

这段代码在 Zig `0.12.0` 中会发出一个编译错误。Zig 不支持也不会支持这种用例：任何可变的编译时状态必须在本地表示。

### `@fieldParentPtr`

删除了第一个参数，以支持使用结果类型。

迁移指南：

```zig
const parent_ptr = @fieldParentPtr(Parent, "field_name", field_ptr);
```

变为：

```zig
const parent_ptr: *Parent = @fieldParentPtr("field_name", field_ptr);
```

或者

```zig
const parent_ptr: *Parent = @alignCast(@fieldParentPtr("field_name", field_ptr));
```

这取决于编译器能够证明的父指针对齐。第二种形式更具有可移植性，因为对于某些目标可能需要 `@alignCast` ，而对于其他目标可能不需要。

### 禁止在函数类型上进行对齐

`0.11.0` 允许函数类型指定对齐。在 `0.12.0` 中，这是不允许的，因为它是函数声明和指针的属性，而不是函数类型的属性。

```zig
comptime {
    _ = fn () align(4) void;
}
```

会报告以下错误：

```sh
$ zig test func_type_align.zig
docgen_tmp/func_type_align.zig:2:21: error: function type cannot have an alignment
    _ = fn () align(4) void;
```

### `@errorCast`

过去发布的版本包含了一个 `@errSetCast` 内置函数，它执行从一个错误集到另一个可能更小的错误集的安全检查转换。在 `0.12.0` 中，这个内置函数被 `@errorCast` 替换。它将继续发挥原本的作用，但此外，这个新的内置函数可以转换错误联合类型的错误集：

```zig
const testing = @import("std").testing;

test "@errorCast error set" {
    const err: error{Foo, Bar} = error.Foo;
    const casted: error{Foo} = @errorCast(err);
    try testing.expectEqual(error.Foo, casted);
}

test "@errorCast error union" {
    const err: error{Foo, Bar}!u32 = error.Foo;
    const casted: error{Foo}!u32 = @errorCast(err);
    try testing.expectError(error.Foo, casted);
}

test "@errorCast error union payload" {
    const err: error{Foo, Bar}!u32 = 123;
    const casted: error{Foo}!u32 = @errorCast(err);
    try testing.expectEqual(123, casted);
}
```

### `@abs`

在此之前的版本包含 `@fabs` 内置函数，`std.math.fabs()` 和 `std.math.abs()` 标准库函数。这已被新的 `@abs` 内置函数替换，它能够对整数以及浮点数进行操作。

```zig
const expectEqual = @import("std").testing.expectEqual;

test "@abs on float" {
    const x: f32 = -123.5;
    const y = @abs(x);
    try expectEqual(123.5, y);
}

test "@abs on int" {
    const x: i32 = -12345;
    const y = @abs(x);
    try expectEqual(12345, y);
}
```

## 标准库

在 Windows 上，程序的命令行参数是一个单一的 WTF-16 编码字符串，由程序来将其分割成字符串数组。在 C/C++ 中，C 运行时的入口点负责分割命令行并将 argc/argv 传递给 main 函数。

以前，`ArgIteratorWindows` 匹配 `CommandLineToArgvW` 的行为，但事实证明，CommandLineToArgvW 的行为并不匹配 2008 年后的 C 运行时。在 2008 年，C 运行时的 argv 分割[改变了它如何处理引用参数中的连续双引号](https://daviddeley.com/autohotkey/parameters/parameters.htm#WINCRULESDOC)（现在被认为是转义引号，例如 `"foo""bar"` 在 2008 年后会被解析成 `foo"bar`），并且 `argv[0]` 的规则也被改变了。

这个版本使 ArgIteratorWindows 匹配 2008 年后的 C 运行时的行为。这里的动机大致与 Rust 做出同样的改变时相同，即（改述）：

- Zig 和现代 C/C++ 程序之间的一致行为

- 允许用户以更直接的方式转义双引号

此外，对 [BatBadBut](https://flatt.tech/research/posts/batbadbut-you-cant-securely-execute-commands-on-windows/) 的建议的缓解措施依赖于 2008 年后的 argv 分割行为，以便对给 cmd.exe 的参数进行往返处理。

[BadBatBut 的缓解措施](https://github.com/ziglang/zig/pull/19698)没有在 0.12.0 版本的发布截止日期之前完成。

### 不在允许覆盖 POSIX API

Zig 的历史版本允许应用程序覆盖标准库的 POSIX API 层。该版本故意移除了这个能力，没有提供迁移方案。

这从一开始就是一个错误。在这个抽象层进行该操作是错误的。

对此的另一种计划是使所有 I/O 操作都需要一个 IO 接口参数，类似于今天的分配需要一个 `Allocator` 接口参数。

但当前尚未有类似的规划，所以需要该功能的应用程序必须维护一个标准库的分支，直到该问题被解决。

### `std.os` 命名为 `std.posix`

迁移方式：

```zig
std.os.abort();
```

到

```zig
std.posix.abort();
```

通常，人们应该更倾向于使用更高级别的跨平台抽象，而不是深入到 POSIX API 层。例如， `std.process.exit` 比 `std.posix.exit` 更具有可移植性。你通常应该期望在操作系统实现相应的 POSIX 功能时，`std.posix` 内的 API 在给定的操作系统上是可用的。

### Ryu 浮点数格式化

Zig 0.12.0 用基于 Ryu 的算法替换了先前的 errol 浮点数格式化算法，Ryu 是一种用于将 IEEE-754 浮点数转换为十进制字符串的现代算法。

这带来的改进包括：

- 能够格式化 `f80` 和 `f128` 类型
- 更准确的 `f16` 和 `f32` 格式化
- 对每种浮点类型的完全往返支持
- 通用后端，可以用来打印任何一般位数的浮点数（小于或等于 128 位）

差异：

- 指数不再用前导 0 填充到 2 位，如果是正数，不再打印符号：

```sh
errol: 2.0e+00
ryu:   2e0
```

- 在除 `f64` 之外的所有情况下，全精度输出更准确，因为我们不再在内部进行 `f64` 的转换：

```sh
# Ryu
3.1234567891011121314151617181920212E0 :f128
3.1234567891011121314E0 :f80
3.1234567891011121314E0 :c_longdouble
3.123456789101112E0 :f64
3.1234567E0 :f32
3.123E0 :f16

## Errol
3.123456789101112e+00 :f128
3.123456789101112e+00 :f80
3.123456789101112e+00 :c_longdouble
3.123456789101112e+00 :f64
3.12345671e+00 :f32
3.123046875e+00 :f16
```

此外，在这些情况下，固定精度情况下的舍入行为也可能不同，因为最短表示通常会有所不同：

```sh
# bits:         141333
# precision:    3
# std_shortest: 1.98049715e-40
# ryu_shortest: 1.9805e-40
# type:         f32
|
| std_dec: 0.000
| ryu_dec: 0.000
|
| std_exp: 1.980e-40
| ryu_exp: 1.981e-40
```

性能：约提高 2.3 倍

代码大小：大约增加 5KB（2 倍）

以上源代码：[Github](https://github.com/ziglang/zig/pull/19229)

### 重构 HTTP

首先，一些非常直接的更改：

- 不发出 Server HTTP 头。如果用户希望添加，让他们自己添加。这不是严格必要的，可以说是一个有害的默认设置。
- 修正 `finish` 的错误集，不再包含 NotWriteable 和 MessageTooLong
  在 Server 中防止零长度的块
- 在 FetchOptions 中添加缺失的重定向行为选项，并将其改为枚举，而不是 2 个字段
- `error.CompressionNotSupported` 被重命名为 `error.CompressionUnsupported`，与同一集合中所有其他错误的命名约定相匹配。
- 删除了与字段和类型名称重复的文档注释。
- 暂时禁用服务器中的 zstd 解压缩；参见 [#18937](https://github.com/ziglang/zig/issues/18937)。
- Automatically handle expect: 100-continue requests

接下来，**移除了堆分配头部缓冲区的能力**。HTTP 头部的缓冲区现在总是通过静态缓冲区提供。因此，`OutOfMemory` 不再是 `read()` 错误集的成员，`Client` 和 `Server` 的 API 和实现得到了简化。`error.HttpHeadersExceededSizeLimit` 被重命名为 `error.HttpHeadersOversize`。

大的变动：

#### 移除 `std.http.Headers`

相反，一些头部通过在解析 HTTP 请求/响应时填充的显式字段名提供，一些通过支持传递额外、任意头部的新字段提供。这在许多地方简化了逻辑，也消除了许多地方的失败可能性。现在进行的反初始化代码更少了。此外，它使得不再需要克隆头部数据结构来处理重定向。

http_proxy 和 https_proxy 字段现在是指针，因为它们通常未被填充。

将 `loadDefaultProxies` 改为 `initDefaultProxies` ，以表明它实际上并未从磁盘或网络加载任何东西。现在的函数是有泄漏的；API 用户必须传递一个已经实例化的竞技场分配器。消除了反初始化代理的需要。

以前，代理存储了任意的头部集合。现在它们只存储授权值。

删除了 https_proxy 和 http_proxy 之间的重复代码。最后，环境变量的解析失败会导致错误被发出，而不是默默地忽略代理。

#### 完全重构 Server

主要移除了名字起得不好的 `wait`、`send`、`finish` 函数，它们都在同一个"`Response`"对象上操作，实际上这个对象被用作请求。

现在，看起来像：

- `std.net.Server.accept()` 会给出一个 `std.net.Server.Connection`
- 使用 `connection` 初始化 `std.http.Server.init()`
- `Server.receiveHead()` 会给出一个 Request
- `Request.reader()` 给出一个 body 的 reader
- `Request.respond()` 是一次性的，或者 `Request.respondStreaming()` 创建一个`Response`
- `Response.writer()` 给出一个 body 的 writer
- `Response.end()` 完成响应；`Response.endChunked()` 允许传递响应尾部。

换句话说，类型系统现在引导 API 用户走正确的路径。

`receiveHead` 允许将额外的字节读入读缓冲区，然后将这些字节用于主体或在连接复用时用于下一个请求。

`respond()`，一次性函数，将在一次系统调用中发送整个响应。

流式响应体不再浪费地用块头和尾部包装每次写入调用；相反，它只在刷新时发送 HTTP 块 wrapper。这意味着用户仍然可以控制何时发生，它也不会添加不必要的块。

从经验上看，使用代码显著地减少了噪音，它在更正确地处理错误的同时减少了错误处理，更明确地显示了正在发生的事情，并且是使用系统调用优化的。

```zig
var read_buffer: [8000]u8 = undefined;
    accept: while (true) {
        const connection = try http_server.accept();
        defer connection.stream.close();

        var server = std.http.Server.init(connection, &read_buffer);
        while (server.state == .ready) {
            var request = server.receiveHead() catch |err| {
                std.debug.print("error: {s}\n", .{@errorName(err)});
                continue :accept;
            };
            try static_http_file_server.serve(&request);
        }
    }
```

```zig
pub fn serve(
    context: *Context,
    request: *std.http.Server.Request,
) ServeError!void {
    // ...
    return request.respond(content, .{
        .status = status,
        .extra_headers = &.{
            .{ .name = "content-type", .value = @tagName(file.mime_type) },
        },
    });
```

还有：

- 将 `std.http.HeadParser` 从 `protocol.zig` 中解耦
- 删除 `std.Server.Connection` ，改为使用 `std.net.Server.Connection`。
  - API 使用者在初始化 `http.Server` 时提供读缓冲区，它用于 HTTP 头以及读取主体的缓冲区。
- 替换并注释 `State` 枚举。不再有 "start" 和 "first"。

`std.http.Client` 尚未像 `std.http.Server` 那样进行类似的重构。

### deflate 的重实现

> deflat e 是一种无损数据压缩算法和相关的文件格式。它通常用于 gzip 和 zip 文件格式中，也是 HTTP 协议中的一种常见的内容编码方式。
>
> inflate 是一种数据解压缩算法，它是 deflate 压缩算法的反向操作。在网络传输或数据存储中，通常先使用 deflate 算法将数据压缩，然后在需要使用数据时，再使用 inflate 算法将数据解压缩回原始形式。

在 `0.11.0` 中，deflate 实现是从 Go 标准库移植过来的，它有一些不受欢迎的特性，如不恰当地使用了全局变量，在 Zig 的代码库中关于 Go 的优化器的评论，以及需要动态内存分配。

`0.12.0` 重构了整个实现，并不是单纯的移植！

新的实现在解压缩上大约快 1.2 - 1.4 倍，在压缩上快 1.1 - 1.2 倍。在两种情况下，压缩大小几乎相同（来源）。

新的代码对所有结构使用静态分配，不需要分配器。这对于 deflate 很有意义，因为所有的结构、内部缓冲区获得了大小刚好的内存。对于 inflate 来说，相较过去的实现通过不预分配到理论最大尺寸数组（申请的数组通常不会被完全使用）来减少内存使用。

对于 deflate，新的实现分配了 395K，而之前的实现使用了 779K。对于 inflate，新的实现分配了 74.5K，而旧的实现大约 36K。

inflate 的差异是因为我们在这里使用 64K 的历史记录，而之前是 32K。

::: details 迁移指南

```zig
const std = @import("std");

// To get this file:
// wget -nc -O war_and_peace.txt https://www.gutenberg.org/ebooks/2600.txt.utf-8
const data = @embedFile("war_and_peace.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    try oldDeflate(allocator);
    try new(std.compress.flate, allocator);

    try oldZlib(allocator);
    try new(std.compress.zlib, allocator);

    try oldGzip(allocator);
    try new(std.compress.gzip, allocator);
}

pub fn new(comptime pkg: type, allocator: std.mem.Allocator) !void {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // Compressor
    var cmp = try pkg.compressor(buf.writer(), .{});
    _ = try cmp.write(data);
    try cmp.finish();

    var fbs = std.io.fixedBufferStream(buf.items);
    // Decompressor
    var dcp = pkg.decompressor(fbs.reader());

    const plain = try dcp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(plain);
    try std.testing.expectEqualSlices(u8, data, plain);
}

pub fn oldDeflate(allocator: std.mem.Allocator) !void {
    const deflate = std.compress.v1.deflate;

    // Compressor
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    // Remove allocator
    // Rename deflate -> flate
    var cmp = try deflate.compressor(allocator, buf.writer(), .{});
    _ = try cmp.write(data);
    try cmp.close(); // Rename to finish
    cmp.deinit(); // Remove

    // Decompressor
    var fbs = std.io.fixedBufferStream(buf.items);
    // Remove allocator and last param
    // Rename deflate -> flate
    // Remove try
    var dcp = try deflate.decompressor(allocator, fbs.reader(), null);
    defer dcp.deinit(); // Remove

    const plain = try dcp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(plain);
    try std.testing.expectEqualSlices(u8, data, plain);
}

pub fn oldZlib(allocator: std.mem.Allocator) !void {
    const zlib = std.compress.v1.zlib;

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // Compressor
    // Rename compressStream => compressor
    // Remove allocator
    var cmp = try zlib.compressStream(allocator, buf.writer(), .{});
    _ = try cmp.write(data);
    try cmp.finish();
    cmp.deinit(); // Remove

    var fbs = std.io.fixedBufferStream(buf.items);
    // Decompressor
    // decompressStream => decompressor
    // Remove allocator
    // Remove try
    var dcp = try zlib.decompressStream(allocator, fbs.reader());
    defer dcp.deinit(); // Remove

    const plain = try dcp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(plain);
    try std.testing.expectEqualSlices(u8, data, plain);
}

pub fn oldGzip(allocator: std.mem.Allocator) !void {
    const gzip = std.compress.v1.gzip;

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // Compressor
    // Rename compress => compressor
    // Remove allocator
    var cmp = try gzip.compress(allocator, buf.writer(), .{});
    _ = try cmp.write(data);
    try cmp.close(); // Rename to finisho
    cmp.deinit(); // Remove

    var fbs = std.io.fixedBufferStream(buf.items);
    // Decompressor
    // Rename decompress => decompressor
    // Remove allocator
    // Remove try
    var dcp = try gzip.decompress(allocator, fbs.reader());
    defer dcp.deinit(); // Remove

    const plain = try dcp.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(plain);
    try std.testing.expectEqualSlices(u8, data, plain);
}
```

:::

### `std.posix` API 现在类型安全

例如，让我们看一下 `std.posix.termios` ：

> POSIX 的 termios 是一个用于控制终端 I/O 特性的数据结构。它包含了一系列的标志位和设置，用于控制输入、输出和控制字符的处理方式，以及其他的终端相关设置。例如，你可以通过修改 termios 结构来设置终端的波特率、字符大小、奇偶校验等参数。

- 为全部 12 个操作系统的 termios 及其字段的类型添加缺失的 API 位
- 在 Linux 上纠正 API 位（对于某些 CPU 架构，它们是错误的）
- 整合 `std.c` 定义
- 为所有整数添加类型安全性

例如，以前这样在 tty 上设置即时模式：

```zig
const in = std.io.getStdIn();

// copy original settings and restore them once done
const original_termios = try std.posix.tcgetattr(in.handle);
defer std.posix.tcsetattr(in.handle, .FLUSH, original_termios) catch {};

// set immediate input mode
var termios = original_termios;
termios.lflag &= ~@as(std.posix.system.tcflag_t, std.posix.system.ICANON);

// flush changes
try std.posix.tcsetattr(in.handle, .FLUSH, termios);
```

现在中间部分看起来像这样：

```zig
// set immediate input mode
var termios = original_termios;
termios.lflag.ICANON = false;
```

这要归功于基于 `packed struct` 的新定义。例如，这是 Linux 的 `lflag` 定义：

```zig
pub const tc_lflag_t = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        _0: u1 = 0,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHO: bool = false,
        ECHONL: bool = false,
        _5: u2 = 0,
        ISIG: bool = false,
        ICANON: bool = false,
        _9: u1 = 0,
        IEXTEN: bool = false,
        _11: u11 = 0,
        TOSTOP: bool = false,
        _23: u8 = 0,
        NOFLSH: bool = false,
    },
    .mips, .mipsel, .mips64, .mips64el => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        _2: u1 = 0,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        IEXTEN: bool = false,
        _9: u6 = 0,
        TOSTOP: bool = false,
        _: u16 = 0,
    },
    else => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        _2: u1 = 0,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        TOSTOP: bool = false,
        _9: u6 = 0,
        IEXTEN: bool = false,
        _: u16 = 0,
    },
};
```

许多其他的 `std.posix` API 也以类似的方式进行了调整。

### `std.builtin` 枚举字段小写化

借此机会调整 `std.builtin` 中一些枚举的字段名，以符合我们当前的命名约定，即枚举字段应为 snake_case。以下枚举已被更新：

- `std.builtin.AtomicOrder`
- `std.builtin.ContainerLayout`
- `std.builtin.Endian`
- `std.builtin.FloatMode`
- `std.builtin.GlobalLinkage`
- `std.builtin.LinkMode`

### 全局配置

以前，当人们想要覆盖默认设置，如 `std.log` 使用的日志函数，他们必须在根文件中定义 `std_options` ，如下所示：

```zig
pub const std_options = struct {
    pub const logFn = myLogFn;
};
```

注意上面的 `std_options` 是一个结构类型定义。在这个版本中，`std_options` 现在是 `std.Options` 的一个实例，使得定义覆盖的过程更少出错。

代码变成了现在这样：

```zig
pub const std_options: std.Options = .{
    .logFn = myLogFn,
};
```

以下是 `std.Options` 的定义，可以看看我们还可以覆写什么：

```zig
pub const Options = struct {
    enable_segfault_handler: bool = debug.default_enable_segfault_handler,

    /// Function used to implement `std.fs.cwd` for WASI.
    wasiCwd: fn () os.wasi.fd_t = fs.defaultWasiCwd,

    /// The current log level.
    log_level: log.Level = log.default_level,

    log_scope_levels: []const log.ScopeLevel = &.{},

    logFn: fn (
        comptime message_level: log.Level,
        comptime scope: @TypeOf(.enum_literal),
        comptime format: []const u8,
        args: anytype,
    ) void = log.defaultLog,

    fmt_max_depth: usize = fmt.default_max_depth,

    cryptoRandomSeed: fn (buffer: []u8) void =
        @import("crypto/tlcsprng.zig").defaultRandomSeed,

    crypto_always_getrandom: bool = false,

    crypto_fork_safety: bool = true,

    /// By default Zig disables SIGPIPE by setting a "no-op" handler for it.
    /// Set this option to `true` to prevent that.
    ///
    /// Note that we use a "no-op" handler instead of SIG_IGN
    /// because it will not be inherited by any child process.
    ///
    /// SIGPIPE is triggered when a process attempts to write to a broken pipe.
    /// By default, SIGPIPE will terminate the process instead of exiting.
    /// It doesn't trigger the panic handler
    /// so in many cases it's unclear why the process was terminated.
    /// By capturing SIGPIPE instead, functions that write to broken pipes
    /// will return the EPIPE error (error.BrokenPipe) and the program can handle
    /// it like any other error.
    keep_sigpipe: bool = false,

    /// By default, std.http.Client will support HTTPS connections.
    /// Set this option to `true` to disable TLS support.
    ///
    /// This will likely reduce the size of the binary,
    /// but it will also make it impossible to make a HTTPS connection.
    http_disable_tls: bool = false,

    side_channels_mitigations: crypto.SideChannelsMitigations =
        crypto.default_side_channels_mitigations,
};
```

### std.meta.trait

`trait` 这个命名空间里提供了一些方法，用于对类型进行检查，比如 `isNumber`、`isZigString` 等，在 [#18061](https://github.com/ziglang/zig/pull/18061/files) 中 Andrew 把这个命名空间删除了，主要是因为现在的实现过于复杂，影响了编译时间。

如果在之前的版本中用到了这里面的函数，需要手动实现一下，社区也有人把 trait 这个单独做成了一个包来用：

- [wrongnull/zigtrait](https://github.com/wrongnull/zigtrait) A bunch of useful functions for working with zig types

### `std.mem.copy`

> 过去用于进行内存拷贝！

在新版中该标准库函数已被移除，与之对应的是使用 `@memcpy` 内置函数，或者是 [`std.mem.copyForwards`](https://ziglang.org/documentation/0.12.0/std/#std.mem.copyForwards) 和 [`std.mem.copyBackwards`](https://ziglang.org/documentation/0.12.0/std/#std.mem.copyBackwards) 函数，它们专门用于处理拷贝时出现内存重叠的情况。

### `std.mem.writeIntSlice`

该函数已删除，作为替代使用 [`std.mem.writeInt`](https://ziglang.org/documentation/0.12.0/std/#std.mem.writeInt)，该函数还支持指定大端或小端！

### 指针保护锁（Pointer Stability Locks）

> "Pointer Stability Locks" 是一种用于保护数据结构中的指针不被非法修改的机制。在 Zig 中，你可以使用 `std.debug.SafetyLock` 来锁定指针，防止它们在不应该被修改的时候被修改。如果尝试在锁定后修改这些指针，程序会抛出一个 panic，而不是触发未定义的行为。这可以帮助开发者更容易地发现和修复可能的错误。

添加了 `std.debug.SafetyLock` ，标准库的哈希表中新添加的 `lockPointers()` 和 `unlockPointers()` 用到了它。

除了触发未定义行为外，这提供了一种新的方法来检测非法修改和 `panic`。

:::details 示例

```zig
const std = @import("std");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var map: std.AutoHashMapUnmanaged(i32, i32) = .{};

    const gop = try map.getOrPut(gpa, 1234);
    map.lockPointers();
    defer map.unlockPointers();

    gop.value_ptr.* = try calculate(gpa, &map);
}

fn calculate(gpa: std.mem.Allocator, m: anytype) !i32 {
    try m.put(gpa, 42, 420);
    return 999;
}
```

```sh
$ zig build-exe safety_locks.zig
$ ./safety_locks
thread 223429 panic: reached unreachable code
/home/andy/local/lib/zig/std/debug.zig:403:14: 0x1036b4d in assert (safety_locks)
    if (!ok) unreachable; // assertion failure
             ^
/home/andy/local/lib/zig/std/debug.zig:2845:15: 0x10375fb in lock (safety_locks)
        assert(l.state == .unlocked);
              ^
/home/andy/local/lib/zig/std/hash_map.zig:1331:44: 0x1066683 in getOrPutContextAdapted__anon_6584 (safety_locks)
                self.pointer_stability.lock();
                                           ^
/home/andy/local/lib/zig/std/hash_map.zig:1318:56: 0x1037505 in getOrPutContext (safety_locks)
            const gop = try self.getOrPutContextAdapted(allocator, key, ctx, ctx);
                                                       ^
/home/andy/local/lib/zig/std/hash_map.zig:1244:52: 0x103765a in putContext (safety_locks)
            const result = try self.getOrPutContext(allocator, key, ctx);
                                                   ^
/home/andy/local/lib/zig/std/hash_map.zig:1241:35: 0x1034023 in put (safety_locks)
            return self.putContext(allocator, key, value, undefined);
                                  ^
/home/andy/docgen_tmp/safety_locks.zig:15:14: 0x1033fb6 in calculate__anon_3194 (safety_locks)
    try m.put(gpa, 42, 420);
             ^
/home/andy/docgen_tmp/safety_locks.zig:11:36: 0x10341eb in main (safety_locks)
    gop.value_ptr.* = try calculate(gpa, &map);
                                   ^
/home/andy/local/lib/zig/std/start.zig:511:37: 0x1033ec5 in posixCallMainAndExit (safety_locks)
            const result = root.main() catch |err| {
                                    ^
/home/andy/local/lib/zig/std/start.zig:253:5: 0x10339e1 in _start (safety_locks)
    asm volatile (switch (native_arch) {
    ^
???:?:?: 0x0 in ??? (???)
(process terminated by signal)
```

:::

有个方便的点，如果使用变体“assume capacity”，那么此时可以正常运行：

```zig
const std = @import("std");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var map: std.AutoHashMapUnmanaged(i32, i32) = .{};

    try map.ensureUnusedCapacity(gpa, 2);
    const gop = map.getOrPutAssumeCapacity(1234);
    map.lockPointers();
    defer map.unlockPointers();

    gop.value_ptr.* = calculate(&map);
}

fn calculate(m: anytype) i32 {
    m.putAssumeCapacity(42, 420);
    return 999;
}
```

还未完成的后续任务：

- [将指针保护锁引入到 array list](https://github.com/ziglang/zig/issues/19326)
- [将指针保护锁引入到 MultiArrayList](https://github.com/ziglang/zig/issues/19327)
- [为指针保护锁添加堆栈跟踪](https://github.com/ziglang/zig/issues/19328)

## 构建系统

构建系统发生了一些变化，有利于开发者进行开发！

### 系统包模式

通过引入系统集成选项，使 zig 构建系统对系统包维护者更加友好。

让我们使用 [groovebasin](https://github.com/andrewrk/groovebasin/tree/old-client) 作为示例项目来检查这个特性：

#### 可选性链接系统库

新增了我们可以实现可选性的链接到系统库（即可以选择是否优先使用系统库）：

```diff
--- a/build.zig
+++ b/build.zig
@@ -5,18 +5,8 @@ pub fn build(b: *std.Build) void {
     const optimize = b.standardOptimizeOption(.{
         .preferred_optimize_mode = .ReleaseSafe,
     });
-    const libgroove_optimize_mode = b.option(
-        std.builtin.OptimizeMode,
-        "libgroove-optimize",
-        "override optimization mode of libgroove and its dependencies",
-    );
     const use_llvm = b.option(bool, "use-llvm", "LLVM backend");

-    const groove_dep = b.dependency("groove", .{
-        .optimize = libgroove_optimize_mode orelse .ReleaseFast,
-        .target = target,
-    });
-
     b.installDirectory(.{
         .source_dir = .{ .path = "public" },
         .install_dir = .lib,
@@ -31,7 +21,22 @@ pub fn build(b: *std.Build) void {
         .use_llvm = use_llvm,
         .use_lld = use_llvm,
     });
-    server.linkLibrary(groove_dep.artifact("groove"));
+
+    if (b.systemIntegrationOption("groove", .{})) {
+        server.linkSystemLibrary("groove");
+    } else {
+        const libgroove_optimize_mode = b.option(
+            std.builtin.OptimizeMode,
+            "libgroove-optimize",
+            "override optimization mode of libgroove and its dependencies",
+        );
+        const groove_dep = b.dependency("groove", .{
+            .optimize = libgroove_optimize_mode orelse .ReleaseFast,
+            .target = target,
+        });
+        server.linkLibrary(groove_dep.artifact("groove"));
+    }
+
     b.installArtifact(server);

     const run_cmd = b.addRunArtifact(server);
```

#### Help 部分加入系统库集成

以下是 `--help` 的新内容：

```sh
System Integration Options:
  --system [dir]               System Package Mode. Disable fetching; prefer system libs
  -fsys=[name]                 Enable a system integration
  -fno-sys=[name]              Disable a system integration

  Available System Integrations:                Enabled:
    groove                                      no
    z                                           no
    mp3lame                                     no
    vorbis                                      no
    ogg                                         no
```

#### 使用系统集成 option

以下示例是在 `nix-shell`（或者 `nix shell`）下测试

```sh
[nix-shell:~/dev/groovebasin]$ zig build -fsys=z

[nix-shell:~/dev/groovebasin]$ ldd zig-out/bin/groovebasin
    linux-vdso.so.1 (0x00007fff054c7000)
    libz.so.1 => /nix/store/8mw6ssjspf8k1ija88cfldmxlbarl1bb-zlib-1.2.13/lib/libz.so.1 (0x00007fe164675000)
    libm.so.6 => /nix/store/whypqfa83z4bsn43n4byvmw80n4mg3r8-glibc-2.37-45/lib/libm.so.6 (0x00007fe164595000)
    libc.so.6 => /nix/store/whypqfa83z4bsn43n4byvmw80n4mg3r8-glibc-2.37-45/lib/libc.so.6 (0x00007fe1643ae000)
    /nix/store/whypqfa83z4bsn43n4byvmw80n4mg3r8-glibc-2.37-45/lib64/ld-linux-x86-64.so.2 (0x00007fe164696000)
```

然后我们移除 `-fsys=z` ：

```sh
[nix-shell:~/dev/groovebasin]$ ~/Downloads/zig/build-release/stage4/bin/zig build

[nix-shell:~/dev/groovebasin]$ ldd zig-out/bin/groovebasin
    linux-vdso.so.1 (0x00007ffcc23f6000)
    libm.so.6 => /nix/store/whypqfa83z4bsn43n4byvmw80n4mg3r8-glibc-2.37-45/lib/libm.so.6 (0x00007f525feea000)
    libc.so.6 => /nix/store/whypqfa83z4bsn43n4byvmw80n4mg3r8-glibc-2.37-45/lib/libc.so.6 (0x00007f525fd03000)
    /nix/store/whypqfa83z4bsn43n4byvmw80n4mg3r8-glibc-2.37-45/lib64/ld-linux-x86-64.so.2 (0x00007f525ffcc000)
```

可以看到，我们通过使用命令行参数指定 option 实现对系统库是否链接的设置！

#### 构建 `release` 的新 option

系统包维护者可以提供新的 `--release` 选项，以设置系统范围内的优化模式偏好，同时尊重应用程序开发者的选择。

```sh
 --release[=mode]             Request release mode, optionally specifying a
                               preferred optimization mode: fast, safe, small
```

```sh
andy@ark ~/d/a/zlib (main)> zig build --release
the project does not declare a preferred optimization mode. choose: --release=fast, --release=safe, or --release=small
error: the following build command failed with exit code 1:
/home/andy/dev/ayb/zlib/zig-cache/o/6f46a03cb0f5f70d2c891f31086fecc9/build /home/andy/Downloads/zig/build-release/stage3/bin/zig /home/andy/dev/ayb/zlib /home/andy/dev/ayb/zlib/zig-cache /home/andy/.cache/zig --seed 0x3e999c60 --release
andy@ark ~/d/a/zlib (main) [1]> zig build --release=safe
andy@ark ~/d/a/zlib (main)> vim build.zig
andy@ark ~/d/a/zlib (main)> git diff
diff --git a/build.zig b/build.zig
index 76bbb01..1bc13e6 100644
--- a/build.zig
+++ b/build.zig
@@ -5,7 +5,9 @@ pub fn build(b: *std.Build) void {
     const lib = b.addStaticLibrary(.{
         .name = "z",
         .target = b.standardTargetOptions(.{}),
-        .optimize = b.standardOptimizeOption(.{}),
+        .optimize = b.standardOptimizeOption(.{
+            .preferred_optimize_mode = .ReleaseFast,
+        }),
     });
     lib.linkLibC();
     lib.addCSourceFiles(.{
andy@ark ~/d/a/zlib (main)> zig build --release
andy@ark ~/d/a/zlib (main)> zig build --release=small
andy@ark ~/d/a/zlib (main)>
```

即使项目的构建脚本没有明确暴露优化配置选项，也可以设置此选项。

#### 不使用 `fetch`

`--system` 阻止 Zig 来 `fetch` 包。对应地，需要提供了一个包的目录，这个目录可能是由系统包管理器填充的。

```sh
[nix-shell:~/dev/2Pew]$ zig build --system ~/tmp/p -fno-sys=SDL2
error: lazy dependency package not found: /home/andy/tmp/p/1220c5360c9c71c215baa41b46ec18d0711059b48416a2b1cf96c7c2d87b2e8e4cf6
info: remote package fetching disabled due to --system mode
info: dependencies might be avoidable depending on build configuration

[nix-shell:~/dev/2Pew]$ zig build --system ~/tmp/p

[nix-shell:~/dev/2Pew]$ mv ~/.cache/zig/p/1220c5360c9c71c215baa41b46ec18d0711059b48416a2b1cf96c7c2d87b2e8e4cf6 ~/tmp/p

[nix-shell:~/dev/2Pew]$ zig build --system ~/tmp/p -fno-sys=SDL2
steps [5/8] zig build-lib SDL2 ReleaseFast native... Compile C Objects [75/128] e_atan2... ^C

[nix-shell:~/dev/2Pew]$
```

### 懒加载依赖

```diff
--- a/build.zig
+++ b/build.zig
-    const groove_dep = b.dependency("groove", .{
-        .optimize = libgroove_optimize_mode orelse .ReleaseFast,
-        .target = target,
-    });
+    if (b.lazyDependency("groove", .{
+        .optimize = libgroove_optimize_mode orelse .ReleaseFast,
+        .target = target,
+    })) |groove_dep| {
+        server.linkLibrary(groove_dep.artifact("groove"));
+    }
```

```diff
--- a/build.zig.zon
+++ b/build.zig.zon
@@ -5,6 +5,7 @@
         .groove = .{
             .url = "https://github.com/andrewrk/libgroove/archive/66745eae734e986cd478e7220664f2de902d10a1.tar.gz",
             .hash = "1220285f0f6b2be336519a0e612a11617c655f78b0efe1cac12fc73fc1e50c7b3e14",
+            .lazy = true,
         },
     },
     .paths = .{

```

这使得只有在实际使用依赖项时才会获取（fetch）依赖项。如果遇到任何缺失的懒惰依赖项，构建运行器将被重建。

当使用 `dependency()` 代替 `lazyDependency()` 有一个错误会出现：

:::details 示例

```sh
$ zig build -h
thread 2904684 panic: dependency 'groove' is marked as lazy in build.zig.zon which means it must use the lazyDependency function instead
/home/andy/Downloads/zig/lib/std/debug.zig:434:22: 0x11901a9 in panicExtra__anon_18741 (build)
    std.builtin.panic(msg, trace, ret_addr);
                     ^
/home/andy/Downloads/zig/lib/std/debug.zig:409:15: 0x1167399 in panic__anon_18199 (build)
    panicExtra(null, null, format, args);
              ^
/home/andy/Downloads/zig/lib/std/Build.zig:1861:32: 0x1136dca in dependency__anon_16705 (build)
                std.debug.panic("dependency '{s}{s}' is marked as lazy in build.zig.zon which means it must use the lazyDependency function instead", .{ b.dep_prefix, name });
                               ^
/home/andy/dev/groovebasin/build.zig:33:40: 0x10e8865 in build (build)
        const groove_dep = b.dependency("groove", .{
                                       ^
/home/andy/Downloads/zig/lib/std/Build.zig:1982:33: 0x10ca783 in runBuild__anon_8952 (build)
        .Void => build_zig.build(b),
                                ^
/home/andy/Downloads/zig/lib/build_runner.zig:310:29: 0x10c6708 in main (build)
        try builder.runBuild(root);
                            ^
/home/andy/Downloads/zig/lib/std/start.zig:585:37: 0x10af845 in posixCallMainAndExit (build)
            const result = root.main() catch |err| {
                                    ^
/home/andy/Downloads/zig/lib/std/start.zig:253:5: 0x10af331 in _start (build)
    asm volatile (switch (native_arch) {
    ^
???:?:?: 0x8 in ??? (???)
Unwind information for `???:0x8` was not available, trace may be incomplete

error: the following build command crashed:
/home/andy/dev/groovebasin/zig-cache/o/20af710f8e0e96a0ccc68c47688b2d0d/build /home/andy/Downloads/zig/build-release/stage3/bin/zig /home/andy/dev/groovebasin /home/andy/dev/groovebasin/zig-cache /home/andy/.cache/zig --seed 0x513e8ce9 -Z4472a09906216280 -h
```

:::

允许反向操作 - 当构建清单文件没有将其标记为懒加载时，使用 `lazyDependency()`。

在 `build.zig` 中，最佳实践可能是始终使用 `lazyDependency()`。

### 引入 `b.path`，弃用 `LazyPath.relative`

这将 `*std.Build` 所有者添加到 `LazyPath` ，以便可以在应用程序的构建脚本中顺利使用从依赖项返回的懒惰路径。

迁移指南：

在 source 中使用相对地址：

```zig
.root_source_file = .{ .path = "src/main.zig" },
```

↓

```zig
.root_source_file = b.path("src/main.zig"),
```

`LazyPath.relative`：

```zig
.root_source_file = LazyPath.relative("src/main.zig"),
```

↓

```zig
.root_source_file = b.path("src/main.zig"),
```

测试运行器：

```zig
.test_runner = "path/to/test_runner.zig",
```

↓

```zig
.test_runner = b.path("path/to/test_runner.zig"),
```

### Header 安装

`Compile.installHeader `和其它相关函数的目的一直是将头文件与产物一起打包，让它们与产物一起安装，并自动添加到与产物链接的模块的包含搜索路径中。

然而，在 `0.11.0` 中，这些函数修改了构建器的默认 `install` 顶级步骤，导致了一些意想不到的结果，比如根据调用的顶级构建步骤的不同，可能会安装或不安装头文件。

`0.12.0` 将其改为将安装的头文件添加到编译步骤本身，而不是修改顶级安装步骤。为了处理依赖链接模块的包含搜索路径的构建，第一次有模块链接到工件时，会创建并设置一个负责构建适当包含树的中间 `WriteFile` 步骤。

迁移指南：

`Compile.installHeader` 现在接收一个 `LazyPath`:

```zig
for (headers) |h| lib.installHeader(h, h);
```

↓

```zig
for (headers) |h| lib.installHeader(b.path(h), h);
```

`Compile.installConfigHeader` 已经移除了它的第二个参数，现在使用 `include_path` 的值作为它的子路径，以与 `Module.addConfigHeader` 保持一致。如果你想将子路径设置为其他内容，可以使用 `artifact.installHeader(config_h.getOutput(), "foo.h")`。

```zig
lib.installConfigHeader(avconfig_h, .{});
```

↓

```zig
lib.installConfigHeader(avconfig_h);
```

`Compile.installHeadersDirectory` / `installHeadersDirectoryOptions` 已经合并为 `Compile.installHeadersDirectory` ，它接受一个 `LazyPath`，并允许像 `InstallDir` 一样使用 exclude/include 过滤器。

```zig
lib.installHeadersDirectoryOptions(.{
        .source_dir = upstream.path(""),
        .install_dir = .header,
        .install_subdir = "",
        .include_extensions = &.{
            "zconf.h",
            "zlib.h",
        },
    });
```

↓

```zig
lib.installHeadersDirectory(upstream.path(""), "", .{
        .include_extensions = &.{
            "zconf.h",
            "zlib.h",
        },
    });
```

额外内容：

- `b.addInstallHeaderFile` 现在需要一个 `LazyPath`。

- 作为 [resurrect emit-h](https://github.com/ziglang/zig/issues/9698) 的解决方法，即使用户指定了 `h_dir` 覆盖，`-femit-h` 生成 header 也不会被触发。如果你的确需要触发生成 header，你现在需要使用 `install_artifact.emitted_h = artifact.getEmittedH()`，直到 `-femit-h` 被修复。

- 添加了 `WriteFile.addCopyDirectory`，其功能与 `InstallDir` 非常相似。
- `InstallArtifact` 已经更新，可以将打包的头文件与产物一起安装。打包的头文件将安装到由 `h_dir` 指定的目录（默认为 `zig-out/include`）。

### 移除 vcpkg 的支持

vcpkg 是微软提供的一个 C/C++ 包管理工具，在之前的版本中可以用 `addVcpkgPaths` 方法来链接使用 vcpkg 安装的包，但在 [579f572c](https://github.com/ziglang/zig/commit/579f572cf203eda11da7e4e919fdfc12e15f03e2) 这个 commit 中 Andrew 删除的对它的支持。推荐使用 zon 的方式来管理依赖。

可以想到，这样短时间内会比较麻烦，如果自己用到的包没有用 zig build，需要自己包装一下，但长远来看是有利于 Zig 生态的，毕竟常用的包不会多，社区经过一段时间发展，常见的 C 库应该都会有对应的 Zig 版本。

### `dependencyFromBuildZig`

给定一个对应于依赖项的 `build.zig` 的结构，`b.dependencyFromBuildZig` 返回相同的依赖项。换句话说，如果你已经 `@import` 了一个依赖项的 `build.zig` 结构，你可以使用这个函数来获取一个对应的 `Dependency`：

```zig
// in consumer build.zig
const foo_dep = b.dependencyFromBuildZig(@import("foo"), .{});
```

上面代码会根据 `foo` 这个导入返回它的 `build.zig` 的整个顶层空间。

这个函数对于从它们的 `build.zig` 文件中暴露需要使用它们对应 `Dependency` 的函数的包来说是有用的，比如用于访问包相对路径，或者运行系统命令并返回输出为懒加载路径。现在可以通过以下方式来实现：

```zig
// in dependency build.zig
// 假设这里是 A
pub fn getImportantFile(b: *std.Build) std.Build.LazyPath {
    const this_dep = b.dependencyFromBuildZig(@This(), .{});
    return this_dep.path("file.txt");
}

// in consumer build.zig
// 假设这里是 B
const file = @import("foo").getImportantFile(b);
```

我们可以在 B 中获取 A 的 `build.zig` 顶层空间，例如我们可以使用这个 `build.zig` 暴露出的其他构造函数！这有助于提高包的灵活性。
