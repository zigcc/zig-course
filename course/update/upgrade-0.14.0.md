---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.13.0` 版本升级到 `0.14.0`。

## 语法变动

### 标记 `switch`

Zig 官方团队接受了一个[新的提案](https://github.com/ziglang/zig/issues/8220)，该提案允许对 `switch` 语句进行标记，并允许其成为 `continue` 语句跳转的目标。此处的 `continue` 语句接受单个操作数（类似 `break` 可以从块或循环返回一个值），该值将直接替换`switch` 表达式的操作数。

这个新的语法糖就类似在循环中指定变量作为 `switch` 操作数一样，示例如下：

```zig
// 以下两个单元测试等价，使用新的语法糖显著减少代码的长度
// 可以简单理解为类似 c 语言中的 `goto`
test "labeled switch" {
    foo: switch (@as(u8, 1)) {
        1 => continue :foo 2,
        2 => continue :foo 3,
        3 => return,
        4 => {},
        else => unreachable,
    }
    return error.Unexpected;
}

test "emulate labeled switch" {
    var op: u8 = 1;
    while (true) {
        switch (op) {
            1 => {
                op = 2;
                continue;
            },
            2 => {
                op = 3;
                continue;
            },
            3 => return,
            4 => {},
            else => unreachable,
        }
        break;
    }
    return error.Unexpected;
}
```

新的语法糖有时会更易于理解，例如在实现有限状态自动机时，可以编写 `continue :fsa new_state` 来表示状态转换。

同时现在可以使用带标签的 `break` 从 `switch` 中跳出来，此时可以得到 `switch` 表达式的操作数。如果是没有标记的 `break`，那么只会对 `for` 或者 `while` 生效。

与普通的 `switch` 语句不同，带有一个或多个 `continue` 目标的标记 `switch` 语句不会在编译时隐式求值（这类似于循环的行为）。然而，与循环一样，可以通过在 `comptime` 上下文中求值这样的表达式来强制进行编译时求值。

#### 代码生成属性

这种语言结构旨在生成有助于 CPU 预测 `switch` 各个 `case` 之间分支的代码，从而提高热循环中的性能，特别是那些调度指令、评估有限状态自动机（FSA）或执行类似基于 `case` 的评估的循环。为了实现这一点，生成的代码可能与直观预期的不同。

如果 `continue` 的操作数在编译时已知，那么它可以被翻译为一个无条件分支到相关的 `case`。这样的分支是完全可预测的，因此通常执行速度非常快。

如果操作数在运行时已知，那么每个 `continue` 可以变成一个单独的条件分支（理想情况下通过共享跳转表）回到同一组潜在的分支目标。这种模式的优势在于它通过提供不同的分支指令来帮助 CPU 的分支预测器，这些指令可以与不同的预测数据相关联。例如，在评估 FSA 时，如果 case `a` 很可能会跟随 case `b`，而 case `c` 很可能会跟随 case `d`，那么分支预测器可以使用 `switch` case 之间的直接跳转来更准确地预测控制流，而基于循环的降级会导致状态调度“折叠”成单个间接分支或类似的情况，从而阻碍分支预测。

这种降级可能会增加代码大小，相比于简单的“循环中的 `switch`”降级，任何 Zig 实现当然可以自由地按照自己的意愿降级这种语法，只要遵守语言语义。然而，官方的 ZSF 编译器实现将尝试匹配上述降级，特别是在 `ReleaseFast` 构建模式下。

更多见相关 PR：[Updating Zig's tokenizer to take advantage of this feature resulted in a 13% performance boost.](https://github..com/ziglang/zig/pull/21367)。

### 声明字面量

Zig 0.14.0 扩展了“**enum literal**”语法 (`.foo`)，引入了一项新功能，称为“**decl literals**”。现在，枚举字面量 `.foo` 不一定指代枚举，而是可以使用[结果位置语义（Result Location Semantics）](https://ziglang.org/documentation/0.14.0/#Result-Location-Semantics)引用目标类型上的任何声明。例如，考虑以下示例：

```zig
const S = struct {
    x: u32,
    const default: S = .{ .x = 123 };
};
test "decl literal" {
    const val: S = .default;
    try std.testing.expectEqual(123, val.x);
}
const std = @import("std");
```

由于 `val` 的初始化表达式对应的结果类型是 `S`，因此初始化实际上等同于 `S.default`。这在初始化结构体字段时特别有用，可以避免再次指定类型：

```zig
const S = struct {
    x: u32,
    y: u32,
    const default: S = .{ .x = 1, .y = 2 };
    const other: S = .{ .x = 3, .y = 4 };
};
const Wrapper = struct {
    val: S = .default,
};
test "decl literal initializing struct field" {
    const a: Wrapper = .{};
    try std.testing.expectEqual(1, a.val.x);
    try std.testing.expectEqual(2, a.val.y);
    const b: Wrapper = .{ .val = .other };
    try std.testing.expectEqual(3, b.val.x);
    try std.testing.expectEqual(4, b.val.y);
}
const std = @import("std");
```

这也可以帮助避免 [Faulty Default Field Values](https://ziglang.org/documentation/0.14.0/#Faulty-Default-Field-Values)，可以看下面的例子：

```zig
/// `ptr` 指向 `[len]u32`.
pub const BufferA = extern struct { ptr: ?[*]u32 = null, len: usize = 0 };
// 以上给出的默认值是想它默认为空
var empty_buf_a: BufferA = .{};
// 不过这样做实际上是违背的开发规范，实际上你可以这样写：
var bad_buf_a: BufferA = .{ .len = 10 };
// 这样处理并不安全，通过声明字面量可以实现方便并且安全的表示值

/// `ptr` 指向 `[len]u32`.
pub const BufferB = extern struct {
    ptr: ?[*]u32,
    len: usize,
    pub const empty: BufferB = .{ .ptr = null, .len = 0 };
};
// 以一种更简单的方式创建一个新的空 buffer
var empty_buf_b: BufferB = .empty;
// 不会再出现莫名其妙的字段覆盖！
// 如果我们要指定值，那么就需要都指定值，这会使错误更容易暴露出来：
var bad_buf_b: BufferB = .{ .ptr = null, .len = 10 };
```

许多现有的字段默认值使用可能更适合通过名为 default 或 empty 或类似的声明来处理，以确保数据不变性不会因覆盖单个字段而被破坏。

声明字面量还支持函数调用，如下所示：

```zig
const S = struct {
    x: u32,
    y: u32,
    fn init(val: u32) S {
        return .{ .x = val + 1, .y = val + 2 };
    }
};
test "call decl literal" {
    const a: S = .init(100);
    try std.testing.expectEqual(101, a.x);
    try std.testing.expectEqual(102, a.y);
}
const std = @import("std");
```

这种语法在初始化结构体字段时也很有用。它还支持通过 `try` 调用返回错误联合的函数。以下示例结合使用这些功能来初始化一个围绕 `ArrayListUnmanaged` 的薄包装器：

```zig
const Buffer = struct {
    data: std.ArrayListUnmanaged(u32),
    fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !Buffer {
        return .{ .data = try .initCapacity(allocator, capacity) };
    }
};
test "initialize Buffer with decl literal" {
    var b: Buffer = try .initCapacity(std.testing.allocator, 5);
    defer b.data.deinit(std.testing.allocator);
    b.data.appendAssumeCapacity(123);
    try std.testing.expectEqual(1, b.data.items.len);
    try std.testing.expectEqual(123, b.data.items[0]);
}
const std = @import("std");
```

声明字面量的引入伴随着一些标准库的变化。特别是，包括 `ArrayListUnmanaged` 和 `HashMapUnmanaged` 在内的非托管容器不应再使用 `.{}` 进行默认初始化，因为这里的默认字段值违反了上述指导原则。相反，它们应该使用其 `empty` 声明进行初始化，这可以通过声明字面量方便地访问：

```zig
const Buffer = struct {
    foo: std.ArrayListUnmanaged(u32) = .empty,
};
test "default initialize Buffer" {
    var b: Buffer = .{};
    defer b.foo.deinit(std.testing.allocator);
    try b.foo.append(std.testing.allocator, 123);
    try std.testing.expectEqual(1, b.foo.items.len);
    try std.testing.expectEqual(123, b.foo.items[0]);
}
const std = @import("std");
```

类似地，`std.heap.GeneralPurposeAllocator` 现在应该使用其 `.init` 声明进行初始化。

这些数据结构的过时默认字段值将在下一个发布周期中移除。

#### 字段和声明不可重名

Zig `0.14.0` 引入了一项限制，即容器类型（结构体、联合体、枚举和不透明类型）不能有同名的字段和声明（`const`/`var`/`fn`）。添加此限制是为了处理 `MyEnum.foo` 是查找声明还是枚举字段这一问题的歧义（这一问题因声明字面量而加剧）。

通常，通过遵循标准命名约定可以避免这种情况：

```zig
const Foo = struct {
    Thing: Thing,
    const Thing = struct {
        Data: u32,
    };
};
```

⬇️

```zig
const Foo = struct {
    thing: Thing,
    const Thing = struct {
        data: u32,
    };
};
```

这一限制的一个好处是，文档注释现在可以明确地引用字段名称，从而使这些引用成为可以点击的超链接。

### `@splat` 支持数组

Zig `0.14.0` 扩展了 `@splat` 内置函数，不仅适用于向量，还适用于数组，这在将数组默认初始化为常量值时非常有用。

例如，结合声明字面量，我们可以优雅地初始化一个 "color" 值的数组：

```zig
const Rgba = struct {
    r: u8,
    b: u8,
    g: u8,
    a: u8,
    pub const black: Rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
};
var pixels: [width][height]Rgba = @splat(@splat(.black));
```

操作数可以在编译时已知或运行时已知。此外，该内置函数还可以用于初始化以哨兵值结尾的数组。

```zig
const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
test "initialize sentinel-terminated array" {
    // the sentinel does not need to match the value
    const arr: [2:0]u8 = @splat(10);
    try expect(arr[0] == 10);
    try expect(arr[1] == 10);
    try expect(arr[2] == 0);
}
test "initialize runtime array" {
    var runtime_known: u8 = undefined;
    runtime_known = 123;
    // 操作数是运行时可知的，那么返回一个运行时的数组
    const arr: [2]u8 = @splat(runtime_known);
    try expect(arr[0] == 123);
    try expect(arr[1] == 123);
}
test "initialize zero-length sentinel-terminated array" {
    var runtime_known: u8 = undefined;
    runtime_known = 123;
    const arr: [0:10]u8 = @splat(runtime_known);
    // 操作数在运行时已知，但由于数组长度为零，结果在编译时已知。
    comptime assert(arr[0] == 10);
}
```

### 全局变量可以互相引用

现在这段代码是有效的：

```zig
const std = @import("std");
const expect = std.testing.expect;

const Node = struct {
    next: *const Node,
};

const a: Node = .{ .next = &b };
const b: Node = .{ .next = &a };

test "example" {
    try expect(a.next == &b);
    try expect(b.next == &a);
}
```

### `@export` 使用指针

此版本的 Zig 简化了 `@export` 内置函数。在之前的 Zig 版本中，这个内置函数的第一个操作数在语法上似乎是要导出的值，这个值被限制为局部变量或容器级声明的标识符或字段访问。这种系统限制过多，而且在语法上令人困惑且不一致；导出常量编译时已知的值是合理的，而这种用法暗示了值被导出，但实际上其地址才是相关的信息。为了解决这个问题，`@export` 现在有了一个新的用法，与 `@extern` 非常相似；它的第一个操作数是一个指针，指向要导出的数据。在大多数情况下，解决这个问题只需添加一个 `&` 操作符。

```zig
const foo: u32 = 123;
test "@export" {
    @export(foo, .{ .name = "bar" });
}
```

⬇️

```zig
const foo: u32 = 123;
test "@export" {
    @export(&foo, .{ .name = "bar" });
}
```

### `@branchHint` 替换 `@setCold`

在高性能代码中，有时希望向优化器提示条件的哪个分支更可能被执行；这可以生成更高效的机器代码。一些语言通过在布尔条件上添加 "likely" 注释来实现这一点；例如，GCC 和 Clang 实现了 `__builtin_expect` 函数。Zig `0.14.0` 引入了一种机制来传达此信息：新的 `@branchHint(comptime hint: std.builtin.BranchHint)` 内置函数。这个内置函数不是修改条件，而是作为块中的第一个语句出现，以传达控制流是否可能到达相关块。

例如：

```zig
fn warnIf(cond: bool, message: []const u8) void {
    if (cond) {
        @branchHint(.unlikely); // we expect warnings to *not* happen most of the time!
        std.log.warn("{s}", message);
    }
}
const std = @import("std");
```

`BranchHint` 类型如下：

```zig
pub const BranchHint = enum(u3) {
    /// Equivalent to no hint given.
    none,
    /// This branch of control flow is more likely to be reached than its peers.
    /// The optimizer should optimize for reaching it.
    likely,
    /// This branch of control flow is less likely to be reached than its peers.
    /// The optimizer should optimize for not reaching it.
    unlikely,
    /// This branch of control flow is unlikely to *ever* be reached.
    /// The optimizer may place it in a different page of memory to optimize other branches.
    cold,
    /// It is difficult to predict whether this branch of control flow will be reached.
    /// The optimizer should avoid branching behavior with expensive mispredictions.
    unpredictable,
};
```

除了作为条件之后块的第一个语句外，`@branchHint` 也允许作为任何函数的第一个语句。期望是优化器可以将可能性信息传播到包含这些调用的分支；例如，如果某个控制流分支总是调用一个标记为 `@branchHint(.unlikely)` 的函数，那么优化器可以假设该分支不太可能被执行。

`BranchHint` 包含 `.cold` ，这导致旧的 `@setCold` 功能已经多余，`@setCold` 已被移除。在大多数情况下，迁移非常简单：只需将 `@setCold(true)` 替换为 `@branchHint(.cold)`：

```zig
fn foo() void {
    @setCold(true);
    // ...
}
```

⬇️

```zig
fn foo() void {
    @branchHint(.cold);
    // ...
}
```

但是，需要注意 `@branchHint` 必须是封闭块（函数）中的第一个语句。这一限制在 `@setCold` 中不存在，因此非常规的用法可能需要额外做点小改动：

```zig
fn foo(comptime x: u8) void {
    if (x == 0) {
        @setCold(true);
    }
    // ...
}
```

⬇️

```zig
fn foo(comptime x: u8) void {
    @branchHint(if (x == 0) .cold else .none);
    // ...
}
```

### 移除 `@fence`

在 Zig `0.14` 中，`@fence` 已被移除。原本提供 `@fence` 是为了与 C11 内存模型保持一致，但它通过修改所有先前和未来原子操作的内存排序来使语义复杂化。这会产生[难以在检测器中建模的不可预见的约束](https://github.com/google/sanitizers/issues/1415)。fence 操作可以通过升级原子内存排序或添加新的原子操作来替代。

`@fence` 的最常见用例可以通过利用更强的内存排序或引入新的原子变量来替代。

#### StoreLoad 屏障

最常见的用例是 `@fence(.seq_cst)`。这主要用于确保对不同原子变量的多个操作之间的一致顺序。

例如：

| thread-1             | thread-2             |
| -------------------- | -------------------- |
| store X // A         | store Y // C         |
| fence(seq_cst) // F1 | fence(seq_cst) // F2 |
| load Y // B          | load X // D          |

目标是确保要么 `load X (D)` 看到 `store X (A)`，要么 `load Y (B)` 看到 `store Y (C)`。这一对顺序一致的栅栏通过两个不变[1](https://en.cppreference.com/w/cpp/atomic/memory_order#Strongly_happens-before:~:text=for%20every%20pair%20of%20atomic%20operations%20A%20and%20B%20on%20an%20object%20M%2C%20where%20A%20is%20coherence%2Dordered%2Dbefore%20B%3A)[2](https://en.cppreference.com/w/cpp/atomic/memory_order#Strongly_happens-before:~:text=if%20a%20memory_order_seq_cst%20fence%20X%20happens%2Dbefore%20A%2C%20and%20B%20happens%2Dbefore%20a%20memory_order_seq_cst%20fence%20Y%2C%20then%20X%20precedes%20Y%20in%20S.)来保证这一点。

现在 `@fence` 已被删除，还有其他方法可以实现这种关系：

- 将所有相关的存储和加载（A、B、C 和 D）设为 `SeqCst`，将它们全部包含在总顺序中。
- 将存储操作（A/C）设为 `Acquire`，并将其匹配的加载操作（D/B）设为 `Release`。从语义上讲，这意味着将它们升级为读 - 修改 - 写操作，这可以实现这样的排序。加载操作可以替换为非变异的 RMW 操作，即 `fetchAdd(0)` 或 `fetchOr(0)`。

像 LLVM 这样的优化器可能会在内部将其简化为 `@fence(.seq_cst)` + `load`。

#### 条件屏障

fence 的另一个用例是分别使用 `Acquire` 或 `Release` 有条件地与先前或未来的原子操作创建同步关系。

一个简单示例是原子引用计数器：

```zig
fn inc(counter: *RefCounter) void {
  _ = counter.rc.fetchAdd(1, .monotonic);
}

fn dec(counter: *RefCounter) void {
  if (counter.rc.fetchSub(1, .release) == 1) {
      @fence(.acquire);
      counter.deinit();
  }
}
```

在 `fetchSub(1)` 中的加载操作只需要在最后一次引用计数递减时为 `Acquire`，以确保之前的递减发生在 `deinit()` 之前。这里的 `@fence(.acquire)` 使用 `fetchSub(1)` 的加载部分创建了这种关系。

如果没有 `@fence` ，这里有两种方法：

- 无条件地通过 fence 的排序来加强所需的原子操作。

```zig
if (counter.rc.fetchSub(1, .acq_rel) == 1) {
```

- 有条件地复制所需的存储或加载，并按照栅栏的顺序进行

```zig
if (counter.rc.fetchSub(1, .release) == 1) {
    _ = counter.rc.load(.acquire);
```

`Acquire` 将与 `rc` 修改顺序中的最长释放序列同步，使所有先前的递减操作发生在 `deinit()` 之前。

#### 同步外部操作

`@fence` 最不常见的用法是为程序员无法控制的原子操作（例如外部函数调用）提供额外的同步。在这种情况下使用 `@fence` 依赖于隐式函数具有不理想的弱排序的原子操作。

理想情况下，隐式函数应该对用户可访问，他们可以简单地在源代码中增加排序。但如果这不可能，最后的手段是引入一个原子变量来模拟栅栏的屏障。例如：

| thread-1        | thread-2                   |
| --------------- | -------------------------- |
| queue.push()    | e = signal.listen()        |
| fence(.seq_cst) | fence(.seq_cst)            |
| signal.notify() | if queue.empty(): e.wait() |

| thread-1              | thread-2                   |
| --------------------- | -------------------------- |
| queue.push()          | e = signal.listen()        |
| fetchAdd(0, .seq_cst) | fetchAdd(0, .seq_cst)      |
| signal.notify()       | if queue.empty(): e.wait() |

### `packed` 结构体相等性

现在可以直接比较 `packed` 结构体，而无需通过 @bitCast 转换为底层整数类型。

```zig
const std = @import("std");
const expect = std.testing.expect;

test "packed struct equality" {
    const S = packed struct {
        a: u4,
        b: u4,
    };
    const x: S = .{ .a = 1, .b = 2 };
    const y: S = .{ .b = 2, .a = 1 };
    try expect(x == y);
}
```

### 原子 `packed` 结构体

现在可以在原子操作中使用 `packed` 结构体，而无需通过 @bitCast 转换为底层整数类型。

```zig
const std = @import("std");
const expect = std.testing.expect;

test "packed struct atomics" {
    const S = packed struct {
        a: u4,
        b: u4,
    };
    var x: S = .{ .a = 1, .b = 2 };
    const y: S = .{ .a = 3, .b = 4 };
    const prev = @atomicRmw(S, &x, .Xchg, y, .seq_cst);
    try expect(prev.b == 2);
    try expect(x.b == 4);
}
```

### `@ptrCast` 可以改变切片长度

具体讨论和实现可以见 PR[#22706](https://github.com/ziglang/zig/pull/22706)

### 移除匿名结构类型，统一元组

此更改重新设计了匿名结构体字面量和元组的工作方式。

以前，一个无类型的匿名结构体字面量（例如 `const x = .{ .a = 123 }`）被赋予了一个“匿名结构体类型”，这是一种特殊的结构体，通过结构等价进行强制转换。这种机制是我们使用结果位置语义作为类型推断的主要机制之前的遗留机制。此更改将语言更改为在此处分配的类型为“普通”结构体类型。它使用一种基于 AST 节点和类型结构的等价形式，非常类似于具体化的 (`@Type`) 类型。

此外，元组也被简化了。“简单”元组类型和“复杂”元组类型之间的区别被消除了。所有元组，即使是那些使用 `struct { ... }` 语法显式声明的元组，也使用结构等价，并且不进行分阶段类型解析。元组的限制非常严格：它们不能有非自动布局，不能有对齐字段，不能有默认值（编译时字段除外）。元组目前没有优化布局，但这在未来可以更改。

此更改简化了语言，并修复了一些通过指针进行的导致非直观行为的问题强制转换。

### 调用约定增强并且替换 `@setAlignStack`

Zig 允许使用 `callconv(...)` 声明函数的调用约定，其中括号中的值是类型为 `std.builtin.CallingConvention`。在之前的 Zig 版本中，这种类型是一个简单的枚举，列出了一些常见的调用约定，例如 x86 的 `.Stdcall` 和 ARM 的 `.AAPCS`。 `.C` 指的是目标的默认 C 调用约定。

Zig `0.14.0` 将 `CallingConvention` 实现更加详细：它现在包含了 Zig 当前支持的每个目标的每个主要调用约定。例如 `.x86_64_sysv`、`.arm_aapcs` 和 `.riscv64_interrupt`。此外，`CallingConvention` 现在是一个标记联合类型，而不是枚举，这允许在调用约定上指定选项。

大多数可用的调用约定都有一个 `std.builtin.CallingConvention.CommonOptions` 的有效负载，这允许在调用函数时覆盖预期的堆栈对齐：

```zig
/// Options shared across most calling conventions.
pub const CommonOptions = struct {
    /// The boundary the stack is aligned to when the function is called.
    /// `null` means the default for this calling convention.
    incoming_stack_alignment: ?u64 = null,
};
```

这在与使用 `-mpreferred-stack-boundary` GCC 标志编译的 C 代码交互时非常有用。

少数调用约定具有更复杂的选项，例如：

```zig
/// Options for x86 calling conventions which support the regparm attribute to pass some
/// arguments in registers.
pub const X86RegparmOptions = struct {
    /// The boundary the stack is aligned to when the function is called.
    /// `null` means the default for this calling convention.
    incoming_stack_alignment: ?u64 = null,
    /// The number of arguments to pass in registers before passing the remaining arguments
    /// according to the calling convention.
    /// Equivalent to `__attribute__((regparm(x)))` in Clang and GCC.
    register_params: u2 = 0,
};
```

默认的 C 调用约定不再由一个特殊标签表示。相反，CallingConvention 包含一个名为 c 的声明，其定义如下：

```zig
/// This is an alias for the default C calling convention for this target.
/// Functions marked as `extern` or `export` are given this calling convention by default.
pub const c = builtin.target.cCallingConvention().?;
```

结合声明字面量，这允许编写 callconv(.c) 来指定此调用约定。

Zig `0.14.0` 包含名为 `Unspecified`、`C`、`Naked`、`Stdcall` 等声明，以允许现有的 `callconv` 用法继续工作，这要归功于声明字面量。这些声明已被弃用，并将在未来的 Zig 版本中移除。

多数调用约定都有一个 `incoming_stack_alignment` 选项，用于指定调用函数时堆栈将对齐的字节边界，这可以用于与使用低于 ABI 要求的堆栈对齐的代码进行互操作。以前，`@setAlignStack` 内置函数可以用于这种情况；然而，它的行为定义得不太明确，并且将其应用于这种情况需要了解 ABI 的预期堆栈对齐。因此，`@setAlignStack` 内置函数已被移除。相反，用户应该在他们的 `callconv` 上注释预期的堆栈对齐，允许优化器在必要时重新对齐。这也允许优化器在调用这样的函数时避免不必要的堆栈重新对齐。为了方便起见，`CallingConvention` 有一个 `withStackAlign` 函数，可以用来改变传入的堆栈对齐。

迁移很简单：

```zig
// This function will be called by C code which uses a 4-byte aligned stack.
export fn foo() void {
    // I know that my target's ABI expects a 16-byte aligned stack.
    @setAlignStack(16);
    // ...
}
```

⬇️

```zig
// This function will be called by C code which uses a 4-byte aligned stack.
// We simply specify that on the `callconv`.
export fn foo() callconv(.withStackAlign(.c, 4)) void {
    // ...
}
```

### 重命名 `std.builtin.Type Fields`

在大多数情况下，Zig 的标准库遵循命名约定。Zig `0.14.0` 更新了 `std.builtin.Type` 标记联合的字段，使其遵循这些约定，将它们小写：

```zig
pub const Type = union(enum) {
    type: void,
    void: void,
    bool: void,
    noreturn: void,
    int: Int,
    float: Float,
    pointer: Pointer,
    array: Array,
    @"struct": Struct,
    comptime_float: void,
    comptime_int: void,
    undefined: void,
    null: void,
    optional: Optional,
    error_union: ErrorUnion,
    error_set: ErrorSet,
    @"enum": Enum,
    @"union": Union,
    @"fn": Fn,
    @"opaque": Opaque,
    frame: Frame,
    @"anyframe": AnyFrame,
    vector: Vector,
    enum_literal: void,
    // ...
};
```

请注意，这需要对 `@"struct"`、`@"union"`、`@"enum"`、`@"opaque"` 和 `@"anyframe"` 使用“带引号的标识符”语法，因为这些标识符也是关键字。

此更改影响广泛，但迁移很简单：

```zig
test "switch on type info" {
    const x = switch (@typeInfo(u8)) {
        .Int => 0,
        .ComptimeInt => 1,
        .Struct => 2,
        else => 3,
    };
    try std.testing.expect(0, x);
}
test "reify type" {
    const U8 = @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = 8,
    } });
    const S = @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &.{},
        .decls = &.{},
        .is_tuple = false,
    } });
    try std.testing.expect(U8 == u8);
    try std.testing.expect(@typeInfo(S) == .Struct);
}
const std = @import("std");
```

⬇️

```zig
⬇️

test "switch on type info" {
    const x = switch (@typeInfo(u8)) {
        .int => 0,
        .comptime_int => 1,
        .@"struct" => 2,
        else => 3,
    };
    try std.testing.expect(0, x);
}
test "reify type" {
    const U8 = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = 8,
    } });
    const S = @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &.{},
        .decls = &.{},
        .is_tuple = false,
    } });
    try std.testing.expect(U8 == u8);
    try std.testing.expect(@typeInfo(S) == .@"struct");
}
const std = @import("std");
```

### 重命名 `std.builtin.Type.Pointer.Size` 的字段

`std.builtin.Type.Pointer.Size` 枚举的字段已被重命名为小写，就像 `std.builtin.Type` 的字段一样。同样，这是一个 break change，但可以非常容易地迁移：

```zig
test "pointer type info" {
    comptime assert(@typeInfo(*u8).pointer.size == .One);
}
test "reify pointer" {
    comptime assert(@Type(.{ .pointer = .{
        .size = .One,
        .is_const = false,
        .is_volatile = false,
        .alignment = 0,
        .address_space = .generic,
        .child = u8,
        .is_allowzero = false,
        .sentinel_ptr = null,
    } }) == *u8);
}
const assert = @import("std").debug.assert;
```

⬇️

```zig
⬇️

test "pointer type info" {
    comptime assert(@typeInfo(*u8).pointer.size == .one);
}
test "reify pointer" {
    comptime assert(@Type(.{ .pointer = .{
        .size = .one,
        .is_const = false,
        .is_volatile = false,
        .alignment = 0,
        .address_space = .generic,
        .child = u8,
        .is_allowzero = false,
        .sentinel_ptr = null,
    } }) == *u8);
}
const assert = @import("std").debug.assert;
```

### 简化在 `std.builtin.Type` 中使用的 `?*const anyopaque`

`std.builtin.Type.StructField` 上的 `default_value` 字段，以及 `std.builtin.Type.Array` 和 `std.builtin.Type.Pointer` 上的 `sentinel` 字段，必须使用 `?*const anyopaque`，因为 Zig 不提供让结构体的类型依赖于字段值的方法。这倒无所谓；然而，有时它并不特别符合人体工程学。

Zig `0.14.0` 分别将这些字段重命名为 `default_value_ptr` 和 `sentinel_ptr`，并添加了辅助方法 `defaultValue()` 和 `sentinel()`，以可选的方式加载具有正确类型的值。

```zig
test "get pointer sentinel" {
    const T = [:0]const u8;
    const ptr = @typeInfo(T).pointer;
    const s = @as(*const ptr.child, @ptrCast(@alignCast(ptr.sentinel.?))).*;
    comptime assert(s == 0);
}
test "reify array" {
    comptime assert(@Type(.{ .array = .{ .len = 1, .child = u8, .sentinel = null } }) == [1]u8);
    comptime assert(@Type(.{ .array = .{ .len = 1, .child = u8, .sentinel = &@as(u8, 0) } }) == [1:0]u8);
}
const assert = @import("std").debug.assert;
```

⬇️

```zig
test "get pointer sentinel" {
    const T = [:0]const u8;
    const ptr = @typeInfo(T).pointer;
    const s = ptr.sentinel().?;
    comptime assert(s == 0);
}
test "reify array" {
    comptime assert(@Type(.{ .array = .{ .len = 1, .child = u8, .sentinel_ptr = null } }) == [1]u8);
    comptime assert(@Type(.{ .array = .{ .len = 1, .child = u8, .sentinel_ptr = &@as(u8, 0) } }) == [1:0]u8);
}
const assert = @import("std").debug.assert;
```

### 不允许非标量哨兵类型

哨兵值现在禁止使用复合类型。换句话说，只允许支持 `==` 操作符的类型。

```zig
export fn foo() void {
    const S = struct { a: u32 };
    var arr = [_]S{ .{ .a = 1 }, .{ .a = 2 } };
    const s = arr[0..1 :.{ .a = 1 }];
    _ = s;
}
```

以上代码会触发以下错误：

```sh
$ zig test non_scalar_sentinel.zig
src/download/0.14.0/release-notes/non_scalar_sentinel.zig:4:26: error: non-scalar sentinel type 'non_scalar_sentinel.foo.S'
    const s = arr[0..1 :.{ .a = 1 }];
                        ~^~~~~~~~~~
src/download/0.14.0/release-notes/non_scalar_sentinel.zig:2:15: note: struct declared here
    const S = struct { a: u32 };
              ^~~~~~~~~~~~~~~~~
referenced by:
    foo: src/download/0.14.0/release-notes/non_scalar_sentinel.zig:1:1
```

### 新增内置函数 `@FieldType`

Zig `0.14.0` 引入了 `@FieldType` 内置函数。它的作用与 `std.meta.FieldType` 函数相同：给定一个类型和其字段名，返回该字段的类型。

```zig
const assert = @import("std").debug.assert;
test "struct @FieldType" {
    const S = struct { a: u32, b: f64 };
    comptime assert(@FieldType(S, "a") == u32);
    comptime assert(@FieldType(S, "b") == f64);
}
test "union @FieldType" {
    const U = union { a: u32, b: f64 };
    comptime assert(@FieldType(U, "a") == u32);
    comptime assert(@FieldType(U, "b") == f64);
}
test "tagged union @FieldType" {
    const U = union(enum) { a: u32, b: f64 };
    comptime assert(@FieldType(U, "a") == u32);
    comptime assert(@FieldType(U, "b") == f64);
}
```

### `@src` 增加了 `Module` 字段

`std.builtin.SourceLocation`:

```zig
pub const SourceLocation = struct {
    /// The name chosen when compiling. Not a file path.
    module: [:0]const u8,
    /// Relative to the root directory of its module.
    file: [:0]const u8,
    fn_name: [:0]const u8,
    line: u32,
    column: u32,
};
```

新增字段 `module`。

### `@memcpy` 规则调整

- `@memcpy` 的语言规范定义已更改，源和目标元素类型必须是内存可强制转换的，允许所有此类调用成为原始复制操作，而不实际应用任何强制转换。
- 为编译时 `@memcpy` 实现别名检查；如果参数别名，现在将发出编译错误。
- 通过一次加载和存储整个数组来实现更高效的编译时 `@memcpy`，类似于 `@memset` 的实现方式。

这是一个 break change，因为虽然旧的强制转换行为在运行时触发了“未实现”的编译错误，但它确实在编译时起作用。

### 不允许不安全的内存强制转换

具体见 PR [#22243](https://github.com/ziglang/zig/pull/22243)。

### `callconv`、`align`、`addrspace`、`linksection` 不能引用函数参数

具体见 PR [#22264](https://github.com/ziglang/zig/pull/22264)。

### 函数调用的分支配额规则已调整

具体见 PR [#22414](https://github.com/ziglang/zig/pull/22414)。

## 标准库

未分类的更改：

- mem：在 `byteSwapAllFields` 中处理 `Float` 和 `Bool` 情况
- fmt：从二进制中移除占位符

### DebugAllocator

`GeneralPurposeAllocator` 依赖于编译时已知的页面大小，因此必须重写。

现在它被重写以减少活动映射，以获得更好的性能，并重命名为 `DebugAllocator`。

性能数据展示，这是在重写前后使用调试版 Zig 编译器运行 ast-check 的结果：

**Benchmark 1 (3 runs)**: `master/bin/zig ast-check ../lib/compiler_rt/udivmodti4_test.zig`

| Measurement      | Mean ± σ        | Min … Max       | Outliers | Delta |
| ---------------- | --------------- | --------------- | -------- | ----- |
| Wall Time        | 22.8s ± 184ms   | 22.6s … 22.9s   | 0 (0%)   | 0%    |
| Peak RSS         | 58.6MB ± 77.5KB | 58.5MB … 58.6MB | 0 (0%)   | 0%    |
| CPU Cycles       | 38.1G ± 84.7M   | 38.0G … 38.2G   | 0 (0%)   | 0%    |
| Instructions     | 27.7G ± 16.6K   | 27.7G … 27.7G   | 0 (0%)   | 0%    |
| Cache References | 1.08G ± 4.40M   | 1.07G … 1.08G   | 0 (0%)   | 0%    |
| Cache Misses     | 7.54M ± 1.39M   | 6.51M … 9.12M   | 0 (0%)   | 0%    |
| Branch Misses    | 165M ± 454K     | 165M … 166M     | 0 (0%)   | 0%    |

**Benchmark 2 (3 runs)**: `branch/bin/zig ast-check ../lib/compiler_rt/udivmodti4_test.zig`

| Measurement      | Mean ± σ       | Min … Max       | Outliers | Delta             |
| ---------------- | -------------- | --------------- | -------- | ----------------- |
| Wall Time        | 20.5s ± 95.8ms | 20.4s … 20.6s   | 0 (0%)   | ⚡- 10.1% ± 1.5%  |
| Peak RSS         | 54.9MB ± 303KB | 54.6MB … 55.1MB | 0 (0%)   | ⚡- 6.2% ± 0.9%   |
| CPU Cycles       | 34.8G ± 85.2M  | 34.7G … 34.9G   | 0 (0%)   | ⚡- 8.6% ± 0.5%   |
| Instructions     | 25.2G ± 2.21M  | 25.2G … 25.2G   | 0 (0%)   | ⚡- 8.8% ± 0.0%   |
| Cache References | 1.02G ± 195M   | 902M … 1.24G    | 0 (0%)   | - 5.8% ± 29.0%    |
| Cache Misses     | 4.57M ± 934K   | 3.93M … 5.64M   | 0 (0%)   | ⚡- 39.4% ± 35.6% |
| Branch Misses    | 142M ± 183K    | 142M … 142M     | 0 (0%)   | ⚡- 14.1% ± 0.5%  |

### SmpAllocator

一个为 `ReleaseFast` 优化模式设计的分配器，启用了多线程。

这个分配器是一个单例；它使用全局状态，并且整个进程中只应实例化一个。

这是一个“sweet spot”——实现大约 200 行代码，但性能与 glibc 相媲美。例如，以下是使用 `glibc malloc` 与 `SmpAllocator` 构建 Zig 自身的比较：

**Benchmark 1 (3 runs)**: `glibc/bin/zig build -Dno-lib -p trash`

| Measurement      | Mean ± σ       | Min … Max     | Outliers | Delta |
| ---------------- | -------------- | ------------- | -------- | ----- |
| Wall Time        | 12.2s ± 99.4ms | 12.1s … 12.3s | 0 (0%)   | 0%    |
| Peak RSS         | 975MB ± 21.7MB | 951MB … 993MB | 0 (0%)   | 0%    |
| CPU Cycles       | 88.7G ± 68.3M  | 88.7G … 88.8G | 0 (0%)   | 0%    |
| Instructions     | 188G ± 1.40M   | 188G … 188G   | 0 (0%)   | 0%    |
| Cache References | 5.88G ± 33.2M  | 5.84G … 5.90G | 0 (0%)   | 0%    |
| Cache Misses     | 383M ± 2.26M   | 381M … 385M   | 0 (0%)   | 0%    |
| Branch Misses    | 368M ± 1.77M   | 366M … 369M   | 0 (0%)   | 0%    |

**Benchmark 2 (3 runs)**: `SmpAllocator/fast/bin/zig build -Dno-lib -p trash`

| Measurement      | Mean ± σ       | Min … Max     | Outliers | Delta           |
| ---------------- | -------------- | ------------- | -------- | --------------- |
| Wall Time        | 12.2s ± 49.0ms | 12.2s … 12.3s | 0 (0%)   | + 0.0% ± 1.5%   |
| Peak RSS         | 953MB ± 3.47MB | 950MB … 957MB | 0 (0%)   | - 2.2% ± 3.6%   |
| CPU Cycles       | 88.4G ± 165M   | 88.2G … 88.6G | 0 (0%)   | - 0.4% ± 0.3%   |
| Instructions     | 181G ± 6.31M   | 181G … 181G   | 0 (0%)   | ⚡- 3.9% ± 0.0% |
| Cache References | 5.48G ± 17.5M  | 5.46G … 5.50G | 0 (0%)   | ⚡- 6.9% ± 1.0% |
| Cache Misses     | 386M ± 1.85M   | 384M … 388M   | 0 (0%)   | + 0.6% ± 1.2%   |
| Branch Misses    | 377M ± 899K    | 377M … 378M   | 0 (0%)   | 💩+ 2.6% ± 0.9% |

设计思路：

每个线程都有一个单独的空闲列表，但是，当线程退出时，数据必须是可恢复的。我们不会直接知道线程何时退出，因此有时一个线程必须尝试回收另一个线程的资源。

超过一定大小的分配直接进行内存映射，不存储分配元数据。这是可行的，因为这个分配器实现拒绝 resize（将从小的 buffer 移动到大的 buffer 或反过来的行为）。

每个分配器操作从线程局部变量检查线程标识符，以确定访问全局状态中的哪个元数据，并尝试获取其锁。这通常会在没有争用的情况下成功，除非另一个线程被分配了相同的 ID。在这种争用的情况下，线程会移动到下一个线程元数据槽，并重复尝试获取锁的过程。

通过将线程局部元数据数组限制为与 CPU 数量相同，确保随着线程的创建和销毁，它们循环通过整个空闲列表集。

要使用这个新的 `allocator`，在你的主函数中放置类似以下内容的代码：

```zig
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };
}
```

更多的信息可以看开发日志 [No-Libc Zig Now Outperforms Glibc Zig](https://ziglang.org/devlog/2025/#2025-02-07)。

### Allocator API 变动 (remap)

此版本在 `std.mem.Allocator.VTable` 中引入了一个新函数 `remap`。

以下为文档注释中的关键部分：

> 尝试扩展或缩小内存，允许重新定位。
>
> 非空返回值表示调整大小成功。
>
> 分配可能具有相同的地址，或者可能已重新定位。
>
> 在任何一种情况下，分配现在的大小都是 new_len。
>
> 空返回值表示调整大小相当于分配新内存，从旧内存复制字节，然后释放旧内存。
>
> 在这种情况下，调用者执行复制操作更为高效。

函数原型：

`remap: *const fn (*anyopaque, memory: []u8, alignment: Alignment, new_len: usize, return_address: usize) ?[*]u8,`

所有 `Allocator.VTable` 函数现在接受 `std.mem.Alignment` 类型而不是 `u8`。具体数值相同，但现在有类型安全和附加到类型的便捷方法。

`resize` 和 `remap` 各有其用途。例如，`resize` 对于 `std.heap.ArenaAllocator` 是必要的，因为它不能重新定位其分配。同时，当容量增加时，`remap` 适用于 `std.ArrayList`。

关于 `remap` 需要注意，除非可以在不执行分配器内部 `memcpy` 的情况下实现 `remap`，否则 `Allocator` 实现 `remap` 通常应与 `resize` 行为相同。

例如，此版本在支持的情况下引入了对调用 `mremap` 的支持，在这种情况下，操作系统重新映射页面，避免了用户空间中昂贵的 `memcpy`。Zig 程序员现在可以期望在使用 `std.heap.page_allocator` 以及将其用作例如 `std.heap.ArenaAllocator` 或 `std.heap.GeneralPurposeAllocator` 的后备分配器时发生这种情况。

另外：

- `std.heap.page_allocator` 现在支持大于页面大小的对齐，这在重写 `DebugAllocator` 时是需要的。
- 删除 `std.heap.WasmPageAllocator`，改用 `std.heap.WasmAllocator`。
- 删除 `std.heap.LoggingAllocator`，它不属于 `std`。
- 删除 `std.heap.HeapAllocator` - 这是仅限 Windows 的，并且依赖于 `kernel32`。

### Zon 解析和序列化

`std.zon.parse` 提供了在运行时将 **ZON** 解析为 **Zig** 结构体的功能：

- `std.zon.parse.fromSlice`
- `std.zon.parse.fromZoir`
- `std.zon.parse.fromZoirNode`
- `std.zon.parse.free`

典型用例将使用 `std.zon.parse.fromSlice`，如果类型需要分配，则需要使用 `std.zon.parse.free`。

对于具有与 Zig 结构体不完全对应的模式的 ZON 值，可以使用 `std.zig.ZonGen` 生成一个可以根据需要解释的树结构（`std.Zoir`）。

有关在编译时导入 ZON，请参见 `Import ZON`。

`std.zon.stringify` 提供了在运行时序列化 ZON 的功能：

- `std.zon.stringify.serialize`
- `std.zon.stringify.serializeMaxDepth`
- `std.zon.stringify.serializeArbitraryDepth`
- `std.zon.stringify.serializer`

示例将使用 `serialize` 和其他函数。

`std.zon.stringify.serializer` 返回一个更细粒度的接口。它可以用于逐块序列化值，例如对值的不同部分应用不同的配置，或者以与内存中布局不同的形式序列化值。

### 运行时页面大小

编译时已知的 `std.mem.page_size` 被移除，因为页面大小实际上是在运行时已知的（对此表示抱歉），并用 `std.heap.page_size_min` 和 `std.heap.page_size_max` 替代，以用于可能页面大小的编译时已知边界。在指针对齐属性中使用页面大小的地方，例如在 `mmap` 中，已迁移到 `std.heap.page_size_min`。

在必须使用页面大小的地方，`std.heap.pageSize()` 提供解决方案。如果可能，它将返回一个编译时已知的值，否则将在运行时查询操作系统，并记忆化结果（原子地）。它还具有 `std.options` 集成，因此应用程序维护者可以覆盖此行为。

值得注意的是，这修复了对运行在苹果新硬件上的 **Linux** 的支持，例如 Asahi Linux。

### Panic 接口

具体改动可以参考该 PR [#22594](https://github.com/ziglang/zig/pull/22594)。

### 传输层安全（std.crypto.tls）

具体信息可以见 PR [#21872](https://github.com/ziglang/zig/pull/21872)。

### `process.Child.collectOutput` API 变动

升级指南：

```zig
var stdout = std.ArrayList(u8).init(allocator);
defer stdout.deinit();
var stderr = std.ArrayList(u8).init(allocator);
defer stderr.deinit();

try child.collectOutput(&stdout, &stderr, max_output_bytes);
```

⬇️

```zig
var stdout: std.ArrayListUnmanaged(u8) = .empty;
defer stdout.deinit(allocator);
var stderr: std.ArrayListUnmanaged(u8) = .empty;
defer stderr.deinit(allocator);

try child.collectOutput(allocator, &stdout, &stderr, max_output_bytes);
```

在此之前，`collectOutput` 包含一个检查，以确保 `stdout.allocator` 与 `stderr.allocator` 相同，这是由于其内部实现的必要性。然而，比较 `Allocator` 接口的 `ptr` 字段可能会导致非法行为，因为在分配器的实现没有任何关联状态的情况下（如 `page_allocator`、`c_allocator` 等），`Allocator.ptr` 被设置为未定义。

通过此更改，`collectOutput` 中的不安全的 `Allocator.ptr` 比较已被清除（这是 Zig 代码库中唯一出现的此类比较）。此外，`Allocator` 和 `Random` 接口的 `ptr` 字段的文档已更新，标注了对这些字段的任何比较都可能导致非法行为。未来，这种比较将被检测为非法行为。

### LLVM 构建器 API

Zig 是为数不多的直接生成 LLVM 位代码的编译器之一，而不是依赖于具有不稳定 API 且非常庞大的 libLLVM。这是我们努力完全消除 Zig 中 LLVM 依赖的一部分（[#16270](https://github.com/ziglang/zig/issues/16270)）。Roc 项目最近[决定](https://gist.github.com/rtfeldman/77fb430ee57b42f5f2ca973a3992532f)用 Zig 重写他们的编译器，部分原因是能够重用 Zig 的 LLVM 位代码构建器。为了使这一过程更加容易，我们决定将构建器 API 移动到 `std.zig.llvm` 以供第三方项目使用。请注意，与 `std.zig` 命名空间中的内容一样，这是 Zig 编译器的实现细节，不一定遵循与标准库其他部分相同的 API 稳定性和弃用规范。

### 拥抱“Unmanaged”风格的容器

`std.ArrayHashMap` 现在已被弃用，并别名到了 `std.ArrayHashMapWithAllocator`。

要迁移代码，请切换到 `ArrayHashMapUnmanaged`，这将需要更新函数调用以向需要分配器的方法传递一个分配器。在 Zig `0.14.0` 发布后，`std.ArrayHashMapWithAllocator` 将被移除，`std.ArrayHashMapUnmanaged` 将成为 `ArrayHashMap` 的弃用别名。在 Zig `0.15.0` 发布后，弃用的别名 `ArrayHashMapUnmanaged` 将被移除。

这一举措来自于资深 Zig 用户的一致意见，他们已经趋向于使用“Unmanaged”容器。它们作为更好的构建块，避免了冗余存储相同的数据，并且分配器参数的存在 / 不存在与保留容量 / 保留插入模式很好地契合。

其他“Unmanaged”容器的派生也被弃用，例如 `std.ArrayList`。

```zig
var list = std.ArrayList(i32).init(gpa);
defer list.deinit();
try list.append(1234);
try list.ensureUnusedCapacity(1);
list.appendAssumeCapacity(5678);
```

⬇️

```zig
const ArrayList = std.ArrayListUnmanaged;
var list: std.ArrayList(i32) = .empty;
defer list.deinit(gpa);
try list.append(gpa, 1234);
try list.ensureUnusedCapacity(gpa, 1);
list.appendAssumeCapacity(5678);
```

### 弃用列表

以下弃用的别名现在会导致编译错误：

- `std.fs.MAX_PATH_BYTES`（重命名为 `std.fs.max_path_bytes`）
- `std.mem.tokenize`（拆分为 `tokenizeAny`、`tokenizeSequence`、`tokenizeScalar`）
- `std.mem.split`（拆分为 `splitSequence`、`splitAny`、`splitScalar`）
- `std.mem.splitBackwards`（拆分为 `splitBackwardsSequence`、`splitBackwardsAny`、`splitBackwardsScalar`）
- `std.unicode`
- `utf16leToUtf8Alloc`、`utf16leToUtf8AllocZ`、`utf16leToUtf8`、`fmtUtf16le`（全部重命名为首字母大写的 `Le`）
- `utf8ToUtf16LeWithNull`（重命名为 `utf8ToUtf16LeAllocZ`）
- `std.zig.CrossTarget`（移动到 `std.Target.Query`）
- `std.fs.Dir: Rename OpenDirOptions to OpenOptions`
- `std.crypto.tls.max_cipertext_inner_record_len` 重命名为 `std.crypto.tls.max_ciphertext_inner_record_len`

被删除的顶级 `std` 命名空间：

- `std.rand`（重命名为 `std.Random`）
- `std.TailQueue`（重命名为 `std.DoublyLinkedList`）
- `std.ChildProcess`（重命名/移动到 `std.process.Child`）

更多弃用：

- `std.posix.iovec`: 使用 `.base` 和 `.len` 代替 `.iov_base` 和 `.iov_len`
- `LockViolation` 被添加到 `std.posix.ReadError`。如果 `std.os.windows.ReadFile` 遇到 `ERROR_LOCK_VIOLATION`，将发生此错误。
- 在所有容器类型中，`popOrNull` 重命名为 `pop`

### `std.c` 重组

现在它由以下主要部分组成：

1. 所有操作系统共享的声明。
2. 具有相同名称但根据操作系统具有不同类型签名的声明。然而，多个操作系统通常共享相同的类型签名。
3. 特定于单个操作系统的声明。
   - 这些声明每行导入一个，以便可以看到它们的来源，并在操作系统特定文件内通过 `comptime` 块保护，以防止访问错误的声明。
4. 底部有一个名为 `private` 的命名空间，它是一个声明包，用于上面的逻辑选择和使用。

通过将不存在的符号的约定从 `@compileError` 更改为使类型为 `void` 和函数为 `{}` 来解决 [#19352](https://github.com/ziglang/zig/issues/19352) 问题，从而可以更新 `@hasDecl` 以使用 `@TypeOf(f) != void` 或 `T != void`。令人高兴的是，这最终删除了一些重复的逻辑并更新了一些过时的功能检测检查。

一些类型已被修改以获得命名空间、类型安全并符合字段命名约定。这是 break change。

通过此更改，标准库中最后一个 `usingnamespace` 的使用被消除。

### 二分查找

具体见此 PR [#20927](https://github.com/ziglang/zig/pull/20927)。

### `std.hash_map` 增加 `rehash` 方法

无序哈希表目前有一个严重缺陷：[删除操作会导致 `HashMaps` 变慢](https://github.com/ziglang/zig/issues/17851)。

未来，哈希表将进行调整以消除这一缺陷，届时该方法将被直接删除。

请注意，array hash maps 没有这个缺陷。

## 构建系统

未分类的更改：

- 报告缺少 `addConfigHeader` 值的错误
- 修复 `WriteFile` 和 `addCSourceFiles` 未添加 `LazyPath` 依赖项的问题
- [破坏性更改] `Compile.installHeader` 现在接受 `LazyPath`。
- [破坏性更改] `Compile.installConfigHeader` 的第二个参数已被移除，现在使用 `include_path` 的值作为其子路径，以与 `Module.addConfigHeader` 保持一致。如果想将子路径设置为不同的值，请使用 `artifact.installHeader(config_h.getOutput(), "foo.h")`。
- [破坏性更改] `Compile.installHeadersDirectory/installHeadersDirectoryOptions` 已合并为 `Compile.installHeadersDirectory`，它接受 `LazyPath` 并允许排除/包含过滤器，就像 `InstallDir` 一样。
- [破坏性更改] `b.addInstallHeaderFile` 现在接受 `LazyPath`。
- [破坏性更改] [#9698](https://github.com/ziglang/zig/issues/9698) 的解决方法，即使用户为 `h_dir` 指定了覆盖，生成的 `-femit-h` 头文件现在也不会被发出。如果您绝对需要发出的头文件，现在需要执行 `install_artifact.emitted_h = artifact.getEmittedH()` 直到 `-femit-h` 被修复。
- 添加了 `WriteFile.addCopyDirectory`，其功能与 `InstallDir` 非常相似。
- `InstallArtifact` 已更新，以便将捆绑的头文件与工件一起安装。捆绑的头文件安装到 `h_dir` 指定的目录（默认为 `zig-out/include`）。
- `std.Build`: 检测带有 "lib" 前缀的 `pkg-config` 名称
- `fetch`: 添加对 SHA-256 Git 仓库的支持
- `fetch`: 添加对 Mach-O 文件头的可执行文件检测
- 允许在 `comptime` 之外添加 `ConfigHeader` 值

### 文件系统监控

- `--watch` 持续监控源文件修改并重新构建
- `--debounce <ms>` 检测到文件更改后重新构建前的延迟

使用构建系统对所有文件系统输入的完美控制，在完成后保持构建运行器活跃，监控最少数量的目录，以便仅重新运行图中脏的步骤。

默认的去抖动时间是 50ms，但它可配置。这有助于防止在源文件快速连续更改时浪费重建，例如在使用 vim 保存时，它不会进行原子重命名，而是实际上删除目标文件然后再次写入，导致短暂的无效状态，如果没有去抖动会导致构建失败（随后会成功构建，但无论如何体验到临时构建失败是令人恼火的）。

此功能的目的是减少开发周期中编辑和调试之间的延迟。在大型项目中，即使是缓存命中，缓存系统也必须调用 `fstat` 来处理大量文件。文件系统监控允许更高效地检测过时的管道步骤。

主要动机是增量编译即将到来，以便我们可以保持编译器运行并尽快响应源代码更改。在这种情况下，保持其余构建管道的最新状态也是基本要求。

### 新的包哈希格式

旧的哈希格式如下所示：`1220115ff095a3c970cc90fce115294ba67d6fbc4927472dc856abc51e2a1a9364d7`

新的哈希格式如下所示：`mime-3.0.0-zwmL-6wgAADuFwn7gr-_DAQDGJdIim94aDIPa6qO-6GT`

除了 200 位的 SHA-256，新哈希还包含以下附加数据：

- 名称
- 版本
- 指纹的 ID 组件
- 磁盘上的总解压大小

这在编译错误或文件路径中显示包哈希时提供了更好的用户体验，并提供了实现依赖树管理工具所需的数据。例如，仅通过了解整个依赖树的包哈希，现在可以知道在完成所有获取后磁盘上所需的总文件大小，以及执行版本选择，而无需进行任何获取。

文件大小还可以作为默认情况下是否获取懒加载包的启发式方法。

这些好处需要一些新的规则来管理 `build.zig.zon` 文件：

- 名称和版本限制为 32 字节。
- 名称必须是有效的裸 Zig 标识符。将来，这一限制可能会被取消；目前选择了保守的规则。

指纹是一个重要的概念：

- 与名称一起，这代表了一个全局唯一的包标识符。该字段在包首次创建时由工具链自动初始化，然后永远不会更改。尽管生态系统是去中心化的，但这允许 Zig 明确检测一个包是否是另一个包的更新版本。
- 当分叉一个 Zig 项目时，如果上游项目仍在维护，则应重新生成此指纹。否则，分叉是敌对的，试图控制原始项目的身份。可以通过删除该字段并运行 `zig build` 来重新生成指纹。
- 这个 64 位整数是 32 位 ID 组件和 32 位校验和的组合。

指纹中的 ID 组件有以下限制：

- `0x00000000` 保留用于旧包。
- `0xffffffff` 保留用于表示“裸”包。

校验和是从名称计算的，用于保护 Zig 用户免受意外的 ID 冲突。

版本选择和利用指纹的相关工具尚未实现。

尽管仍支持旧的哈希格式，但此更改会破坏任何不遵循上述新包命名规则的包。还有一个已知的错误：不必要地获取旧包。

### `WriteFile` Step

如果您使用 `WriteFile` 来更新源文件，该功能已被提取到一个单独的步骤，称为 `UpdateSourceFiles`。其他一切都保持不变，因此迁移如下所示：

```diff
-    const copy_zig_h = b.addWriteFiles();
+    const copy_zig_h = b.addUpdateSourceFiles();
```

### `RemoveDir` Step

`RemoveDir` Step 现在接受 `LazyPath` 而不是 `[]const u8`。迁移如下所示：

```diff
-        const cleanup = b.addRemoveDirTree(tmp_path);
+        const cleanup = b.addRemoveDirTree(.{ .cwd_relative = tmp_path });
```

但是，请考虑不要在配置时选择临时路径，同时运行构建管道有点脆弱。

### `Fmt` Step

这个 Step 用于打印格式检查失败的文件名。

### 从现有模块创建工件

Zig `0.14.0` 修改了创建 `Compile` Step 的构建系统 API，允许从现有的 `std.Build.Module` 对象创建它们。这使得模块图的定义更加清晰，并且这些图的组件可以更容易地重用；例如，作为另一个模块依赖项存在的模块可以轻松创建相应的测试步骤。可以通过修改对 `addExecutable`、`addTest` 等的调用来使用新的 API。不要直接将 `root_source_file`、`target` 和 `optimize` 等选项传递给这些函数，而是应该传递使用这些参数创建的 `*std.Build.Module` 的 `root_module` 字段。Zig `0.14.0` 仍然允许这些函数的旧的、已弃用的用法，但下一版本将移除它们。

旧 API 的用户可以通过将 `addExecutable`（等）调用的模块特定部分移动到 `createModule` 调用中，以最小的努力进行升级。例如，以下是一个简单构建脚本的更新版本：

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
}
const std = @import("std");
```

⬇️

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_module = b.createModule(.{ // this line was added
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }), // this line was added
    });
    b.installArtifact(exe);
}
const std = @import("std");
```

而且，为了展示新 API 的优势，这里有一个示例构建脚本，它优雅地构建了一个包含多个模块的复杂构建图：

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // First, we create our 3 modules.

    const foo = b.createModule(.{
        .root_source_file = b.path("src/foo.zig"),
        .target = target,
        .optimize = optimize,
    });
    const bar = b.createModule(.{
        .root_source_file = b.path("src/bar.zig"),
        .target = target,
        .optimize = optimize,
    });
    const qux = b.createModule(.{
        .root_source_file = b.path("src/qux.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Next, we set up all of their dependencies.

    foo.addImport("bar", bar);
    foo.addImport("qux", qux);
    bar.addImport("qux", qux);
    qux.addImport("bar", bar); // mutual recursion!

    // Finally, we will create all of our `Compile` steps.
    // `foo` will be the root of an executable, but all 3 modules also have unit tests we want to run.

    const foo_exe = b.addExecutable(.{
        .name = "foo",
        .root_module = foo,
    });

    b.installArtifact(foo_exe);

    const foo_test = b.addTest(.{
        .name = "foo",
        .root_module = foo,
    });
    const bar_test = b.addTest(.{
        .name = "bar",
        .root_module = bar,
    });
    const qux_test = b.addTest(.{
        .name = "qux",
        .root_module = qux,
    });

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&b.addRunArtifact(foo_test).step);
    test_step.dependOn(&b.addRunArtifact(bar_test).step);
    test_step.dependOn(&b.addRunArtifact(qux_test).step);
}
const std = @import("std");
```

### 允许包通过名称暴露任意 LazyPaths

在之前的 Zig 版本中，包可以暴露 artifact、`module` 和命名的 WriteFile Step。这些可以分别通过 `installArtifact`、`addModule` 和 `addNamedWriteFiles` 暴露，并可以通过 `std.Build.Dependency` 上的方法访问它们。

除了这些，Zig `0.14.0` 引入了包暴露任意 `LazyPaths` 的能力。依赖项通过 `std.Build.addNamedLazyPath` 暴露它们，依赖包使用 `std.Build.Dependency.namedLazyPath` 访问它们。

此功能的一个用例是让依赖项向其依赖包暴露一个生成的文件。例如，在以下示例中，依赖包 bar 暴露了一个生成的 Zig 文件，主包将其用作可执行文件的模块导入：

**_build.zig_**

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const bar = b.dependency("bar", .{});
    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("generated", bar.namedLazyPath("generated"));
    b.installArtifact(exe);
}
```

**_bar/build.zig_**

```zig
pub fn build(b: *std.Build) {
    const generator = b.addExecutable(.{
        .name = "generator",
        .root_source_file = b.path("generator.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
    });
    const run_gen = b.addRunArtifact(generator);
    const generated_file = run_gen.addOutputFileArg("generated.zig");
    b.addNamedLazyPath("generated", generated_file);
}
```

### `addLibrary` 函数

作为 `addSharedLibrary` 和 `addStaticLibrary` 的替代，但可以更轻松地在 `build.zig` 中更改链接模式，例如：

对于库来说：

```zig
const lib = b.addLibrary(.{
    .linkage = linkage,
    .name = "foo_bar",
    .root_module = mod,
});
```

对于调用库的包来说：

```zig
const dep_foo_bar = b.dependency("foo_bar", .{
    .target = target,
    .optimize = optimize,
    .linkage = .dynamic // or leave for default static
});

mod.linkLibrary(dep_foor_bar.artifact("foo_bar"));
```
