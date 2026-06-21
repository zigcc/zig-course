---
outline: deep
showVersion: false
---

本篇文档将介绍如何从 `0.15.1` 版本升级到 `0.16.0`。

`0.16.0` 是 Zig 近几个版本里破坏性变更最集中的一次更新之一。最大的主题是：**I/O 被统一到了新的 `std.Io` 接口**，同时语言层也清理了 `@Type`、`@cImport`、`packed` / `extern` 类型规则，以及一批历史 API。

## 语言变动

### `switch` 能力继续增强

`packed struct` 和 `packed union` 现在可以直接作为 switch 的 prong item，并且**比较规则完全基于其 backing integer**——和 packed 类型自身的相等比较保持一致：

```zig
const U = packed union(u2) {
    a: i2,
    b: u2,
};

const u: U = .{ .a = -1 };
switch (u) {
    .{ .b = 3 } => {},
    else => unreachable,
}
```

这一版本里 switch 还新增了以下能力：

- decl literals 以及其他需要结果类型的表达式（例如 `@enumFromInt`）现在可以直接作为 switch prong item
- 联合类型的 tag capture 不再只限于 `inline` prong——所有 prong 都可以使用
- 如果 prong body 是 `=> comptime unreachable`，prong item 中允许出现“当前 error 集合里并不存在的错误”
- **prong capture 不再允许被全部丢弃**——这是一条破坏性改动，如果你之前在 prong 里把所有 capture 都写成了 `_`，需要至少保留一个真实变量名

bug 修复方面：

- 大量 “one-possible-value” 类型上的 switch 相关 bug 被修复
- 在 error 上做 switch 时，关于 unreachable `else` prong 的规则现在适用于**所有**对 error 的 switch，而不仅是 `switch_block_err_union`，且基于 AST 正确判断
- 对 `void` 做 switch 时，不再无条件要求 `else` prong
- lazy values 在与 prong item 比较前会被正确求值
- 不同形式的 switch 语句（带 / 不带 label）求值顺序现在保持一致

绝大多数代码不需要主动迁移，但 prong capture 全部丢弃的这条规则会让一小部分写法直接编译报错。

### `packed union` 的相等比较

`packed union` 现在支持直接相等比较（基于 backing integer），不再需要绕到 backing integer 显式 `@bitCast` 再比。这与上面 switch 中“按 backing integer 比较”的语义是一致的。

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
translate_c.linkSystemLibrary("glfw", .{});
translate_c.linkSystemLibrary("epoxy", .{});

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

这样翻译出来的 C 代码与以前用 `@cImport` 的结果是一致的；如果需要更细的[翻译参数控制](https://codeberg.org/ziglang/translate-c/src/commit/41c10fa66ac81343c33f2b8c746f181b41eaaa27/build/Translator.zig#L40)，可以把官方 [`translate-c`](https://codeberg.org/ziglang/translate-c/src/commit/41c10fa66ac81343c33f2b8c746f181b41eaaa27/build/Translator.zig#L40) 包作为显式依赖加入。

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

```zig
@EnumLiteral() type

@Int(comptime signedness: std.builtin.Signedness, comptime bits: u16) type

@Tuple(comptime field_types: []const type) type

@Pointer(
    comptime size: std.builtin.Type.Pointer.Size,
    comptime attrs: std.builtin.Type.Pointer.Attributes,
    comptime Element: type,
    comptime sentinel: ?Element,
) type

@Fn(
    comptime param_types: []const type,
    comptime param_attrs: *const [param_types.len]std.builtin.Type.Fn.Param.Attributes,
    comptime ReturnType: type,
    comptime attrs: std.builtin.Type.Fn.Attributes,
) type

@Struct(
    comptime layout: std.builtin.Type.ContainerLayout,
    comptime BackingInt: ?type,
    comptime field_names: []const []const u8,
    comptime field_types: *const [field_names.len]type,
    comptime field_attrs: *const [field_names.len]std.builtin.Type.StructField.Attributes,
) type

@Union(
    comptime layout: std.builtin.Type.ContainerLayout,
    /// Either the integer tag type, or the integer backing type, depending on `layout`.
    comptime ArgType: ?type,
    comptime field_names: []const []const u8,
    comptime field_types: *const [field_names.len]type,
    comptime field_attrs: *const [field_names.len]std.builtin.Type.UnionField.Attributes,
) type

@Enum(
    comptime TagInt: type,
    comptime mode: std.builtin.Type.Enum.Mode,
    comptime field_names: []const []const u8,
    comptime field_values: *const [field_names.len]TagInt,
) type
```

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

为了简化语言，**不再支持反射出带 `comptime` 字段的 tuple 类型**。

`@Pointer` 等价于 `@Type(.{ .pointer = ... })`，但配合新的 `std.builtin.Type.Pointer.Attributes` 类型——后者借助 struct 字段默认值，使得用法更接近字面 pointer 类型语法：

```zig
@Type(.{ .pointer = .{
    .size = .one,
    .is_const = true,
    .is_volatile = false,
    .alignment = @alignOf(u32),
    .address_space = .generic,
    .child = u32,
    .is_allowzero = false,
    .sentinel_ptr = null,
} })
```

⬇️

```zig
@Pointer(.one, .{ .@"const" = true }, u32, null)
```

```zig
@Type(.{ .pointer = .{
    .size = .many,
    .is_const = false,
    .is_volatile = false,
    .alignment = 1,
    .address_space = .generic,
    .child = u64,
    .is_allowzero = false,
    .sentinel_ptr = &@as(u64, 0),
} })
```

⬇️

```zig
@Pointer(.many, .{ .@"align" = 1 }, u64, 0)
```

`@Fn` 等价于 `@Type(.{ .@"fn" = ... })`。参数分两段：第一段是所有参数类型，第二段是“参数属性”（目前只有 `noalias` 这个 flag）：

```zig
@Type(.{ .@"fn" = .{
    .calling_convention = .c,
    .is_generic = false,
    .is_var_args = true,
    .return_type = u32,
    .params = &.{.{
        .is_generic = false,
        .is_noalias = false,
        .type = f64,
    }, .{
        .is_generic = false,
        .is_noalias = true,
        .type = *const anyopaque,
    }},
} })
```

⬇️

```zig
@Fn(
    &.{ f64, *const anyopaque },
    &.{ .{}, .{ .@"noalias" = true } },
    u32,
    .{ .@"callconv" = .c, .varargs = true },
)
```

这是几个新 builtin 中用 “struct of arrays” 风格接收参数的代表。这种风格的好处是“给所有元素一个统一默认值”非常容易——比如想给所有参数用默认属性 `.{}`，用 `&@splat(.{})` 即可：

```zig
@Fn(param_types, &@splat(.{}), ReturnType, .{ .@"callconv" = .c })
```

`@Struct` 同样采用 “struct of arrays”：字段名、字段类型、字段属性各自传一组数组，属性里包含 alignment、`comptime` 标志、字段默认值：

```zig
@Type(.{ .@"struct" = .{
    .layout = .@"extern",
    .fields = &.{.{
        .name = "foo",
        .type = [2]f64,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = 1,
    }, .{
        .name = "bar",
        .type = u32,
        .default_value_ptr = &@as(u32, 123),
        .is_comptime = true,
        .alignment = @alignOf(u32),
    }},
    .decls = &.{},
    .is_tuple = false,
} })
```

⬇️

```zig
@Struct(
    .@"extern",
    null,
    &.{ "foo", "bar" },
    &.{ [2]f64, u32 },
    &.{
        .{ .@"align" = 1 },
        .{ .@"comptime" = true, .default_value_ptr = &@as(u32, 123) },
    },
)
```

同样可以用 `&@splat(.{})` 表达“所有字段都用默认属性”，甚至连 field types 都可以——例如要构造一个所有字段都是 `FieldType`，并且字段名跟 `MyEnum` 的枚举名一致的 struct：

```zig
const MyStruct = @Struct(.auto, null, std.meta.fieldNames(MyEnum), &@splat(FieldType), &@splat(.{}));
```

`@Union` 用法与 `@Struct` 类似：

```zig
@Type(.{ .@"union" = .{
    .layout = .auto,
    .tag_type = MyEnum,
    .fields = &.{.{
        .name = "foo",
        .type = i64,
        .alignment = @alignOf(i64),
    }, .{
        .name = "bar",
        .type = f64,
        .alignment = @alignOf(f64),
    }},
    .decls = &.{},
} })
```

⬇️

```zig
@Union(
    .auto,
    MyEnum,
    &.{ "foo", "bar" },
    &.{ i64, f64 },
    &@splat(.{}),
)
```

`@Enum` 和 `@Struct` 风格相近，但接收的是字段 **tag 值** 数组而不是字段类型数组：

```zig
@Type(.{ .@"enum" = .{
    .tag_type = u32,
    .fields = &.{.{
        .name = "foo",
        .value = 0,
    }, .{
        .name = "bar",
        .value = 1,
    }},
    .decls = &.{},
    .is_exhaustive = true,
} })
```

⬇️

```zig
@Enum(
    u32,
    .exhaustive,
    &.{ "foo", "bar" },
    &.{ 0, 1 },
)
```

需要注意的是，**这套新 builtin 里没有 `@Float`**——因为运行时浮点类型只有 5 种，在用户代码里实现这件事很轻松；如果非要从位数构造浮点类型，可以用 `std.meta.Float`。

这套新 builtin 里也没有下面这些类型构造函数：

- 没有 `@Array`：直接用普通数组语法即可。一个通用 `Array` 函数可以写成这样：

  ```zig
  fn Array(comptime len: usize, comptime Elem: type, comptime sentinel: ?Elem) type {
      return if (sentinel) |s| [len:s]Elem else [len]Elem;
  }
  ```

  实际使用时通常不需要这么泛化，直接把调用点替换为 `[len]Elem` 或 `[len:s]Elem` 即可。

- 没有 `@Opaque`：直接写 `opaque {}`。
- 没有 `@Optional`：直接写 `?T`。
- 没有 `@ErrorUnion`：直接写 `E!T`。
- 没有 `@ErrorSet`：为了简化语言，不再支持 reify error set。请用 `error{ ... }` 语法显式声明 error set。

如果你的项目大量依赖元编程，这一项往往是升级时最先爆出来的报错来源。建议先全局搜索 `@Type(` 和 `std.meta.`，再逐个迁移。

### 小整数类型现在可以安全地隐式转换为浮点

如果某个整数类型的所有可能值都能放进目标浮点类型而不发生舍入，那么这个整数可以在不显式转换的情况下 coercion 到该浮点类型。这个判断通过比较整数类型的精度位数和浮点类型的 significand 位数完成。更大的整数类型仍然需要 `@floatFromInt`。

旧写法：

```zig
var foo_int: u24 = 123;
var foo_float: f32 = @floatFromInt(foo_int);

var bar_int: u25 = 123;
var bar_float: f32 = @floatFromInt(bar_int);
```

新写法：

```zig
var foo_int: u24 = 123;
var foo_float: f32 = foo_int; // 安全 coercion

var bar_int: u25 = 123;
var bar_float: f32 = @floatFromInt(bar_int); // 仍然需要显式转换
```

这是“改善 Zig 游戏开发人体工学”这项更大工作的组成部分。

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

这项变化是 `Reworked Byval Syntax Lowering` 的一部分。

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

报错形式如下：

```sh
test.zig:3:13: error: returning address of expired local variable 'x'
    return &x;
            ^
test.zig:2:9: note: declared runtime-known here
    var x: i32 = 1234;
        ^
```

这个变化背后有点小故事。返回无效指针本身在 Zig 里是合法的——非法只发生在解引用：

```zig
fn foo() *i32 {
    return undefined;
}
```

甚至下面这种“无条件触发非法行为”的函数也是合法的：

```zig
fn bar() noreturn {
    unreachable; // equivalent to foo().*
}
```

也就是说 `bar()` 的语义等价于 `unreachable`。那要怎么把“返回局部变量地址”变成编译错误？答案是“句法层面的较真”：编译器禁止所有“不需要类型检查就能 trivially 降级为 `return undefined` 的表达式”，理由是这种代码应当写成规范的 `return undefined`。`return &x;`（其中 `x` 是局部变量）正属于这一类。

如果你在升级后遇到这类错误，正确修复方式通常是三种之一：

- 直接返回值，而不是返回指针
- 让调用方传入 buffer / 输出参数
- 改用堆分配，并明确约定释放责任

后续官方计划继续以同样的思路加入更多类似的编译错误。

### `packed union` 中不再允许 unused bits

此前 `packed union` 的表示到 bit 的映射并不总是只有一种明显方式，而这种唯一性是其他 packed 类型想要具备的属性。例如，`enum(u5) { ... }` 明确表示 5 个 bit，方式也显然，因此允许出现在 packed 上下文中；但 `?u8` 有两种合理方式映射到 9 个 bit，因此不允许出现在 packed 上下文中。

现在通过要求 `packed union` 的所有字段都具有与 backing integer 类型相同的 `@bitSizeOf` 来消除这种歧义。

升级指南：

```zig
const U = packed union {
    x: u8,
    y: u16,
};
```

⬇️

```zig
const U = packed union(u16) {
    x: packed struct(u16) {
        data: u8,
        padding: u8 = 0,
    },
    y: u16,
};
```

### `packed struct` / `packed union` 不再允许指针字段

`packed struct` 和 `packed union` 类型的字段不再允许是指针。这实现了 proposal [#24657](https://github.com/ziglang/zig/issues/24657)。

这项变化的主要原因是：包含非字节对齐指针的常量值无法在绝大多数二进制格式中表示。另外，一些目标平台上的指针不能仅用地址位表示，还包含额外 metadata bit；在这种情况下，把指针打包进整数没有意义，而 `packed` 类型承诺的正是这种整数式位级表示。

如果你依赖了 `packed` 类型中的指针字段，可以改用 `usize` 字段，并通过 `@ptrFromInt` 和 `@intFromPtr` 在指针与整数之间转换：

```zig
const addr: usize = @intFromPtr(ptr);
const ptr_again: *T = @ptrFromInt(addr);
```

### `packed union` 允许显式 backing integer

旧版本 Zig 已经允许 `packed struct` 类型用 `packed struct(T)` 语法指定 backing integer 类型，但不允许 `packed union` 这么做。Zig `0.16.0` 现在允许了。

`packed_union_explicit_backing_int.zig`

```zig
// 常规声明 packed union 类型
const Split16 = packed union(u16) {
    raw: MaybeSigned16,
    split: packed struct { low: u8, high: u8 },
};

// 使用 `@Union` 构造 packed union 类型
const MaybeSigned16 = @Union(
    .@"packed",
    u16, // backing integer type
    &.{ "unsigned", "signed" },
    &.{ u16, i16 },
    &@splat(.{}),
);

test "use packed union type with explicit backing integer" {
    const u: Split16 = .{ .raw = .{ .unsigned = 0xFFFE } };
    try testing.expectEqual(-2, u.raw.signed);
    try testing.expectEqual(0xFE, u.split.low);
    try testing.expectEqual(0xFF, u.split.high);
}

const testing = @import("std").testing;
```

Shell：

```sh
$ zig test packed_union_explicit_backing_int.zig
1/1 packed_union_explicit_backing_int.test.use packed union type with explicit backing integer...OK
All 1 tests passed.
```

注意，由于下面 “`extern` 场景必须显式指定 tag type / backing type” 这条规则的存在，现在某些场景下显式指定 packed union 的 backing integer 是必须的。

### `extern` 场景下必须显式指定 tag type / backing type

具有推断整数 tag type 的 `enum` 类型，以及具有推断整数 backing type 的 `packed struct` 和 `packed union` 类型，不再被视为合法的 `extern` 类型。这实现了 proposal [#24714](https://github.com/ziglang/zig/issues/24714)。

这项 breaking change 是为了避免一个类型的 ABI 完全由字段隐式决定。尤其是因为 `u8` 和 `i8` 在某些上下文中可能有不同 ABI；如果选择是隐式的，就不清楚到底使用哪一个。

如果这在你的代码中引入了编译错误，请添加显式 tag type 或 backing type 来解决。（另见上面 “`packed union` 允许显式 backing integer” 这项 Zig `0.16.0` 相关语言变化。）

`extern_implicit_backing_type.zig`

```zig
const Enum = enum { a, b, c, d };
const PackedStruct = packed struct { a: u4, b: u4 };
const PackedUnion = packed union { a: u8, b: i8 };

export var some_enum: Enum = .a;
export var some_packed_struct: PackedStruct = .{ .a = 1, .b = 2 };
export var some_packed_union: PackedUnion = .{ .a = 123 };
```

Shell：

```sh
$ zig test extern_implicit_backing_type.zig
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:5:1: error: unable to export type 'extern_implicit_backing_type.Enum'
export var some_enum: Enum = .a;
^~~~~~
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:1:14: note: integer tag type of enum is inferred
const Enum = enum { a, b, c, d };
 ^~~~~~~~~~~~~~~~~~~
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:1:14: note: consider explicitly specifying the integer tag type
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:1:14: note: enum declared here
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:6:1: error: unable to export type 'extern_implicit_backing_type.PackedStruct'
export var some_packed_struct: PackedStruct = .{ .a = 1, .b = 2 };
^~~~~~
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:6:1: note: inferred backing integer of packed struct has unspecified signedness
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:2:29: note: struct declared here
const PackedStruct = packed struct { a: u4, b: u4 };
 ~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:7:1: error: unable to export type 'extern_implicit_backing_type.PackedUnion'
export var some_packed_union: PackedUnion = .{ .a = 123 };
^~~~~~
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:7:1: note: inferred backing integer of packed union has unspecified signedness
/home/ci/.cache/act/0d10aab40ec56bb3/hostexecutor/src/download/0.16.0/release-notes/extern_implicit_backing_type.zig:3:28: note: union declared here
const PackedUnion = packed union { a: u8, b: i8 };
 ~~~~~~~^~~~~~~~~~~~~~~~~~~~~~
```

⬇️ `extern_explicit_backing_type.zig`

```zig
const Enum = enum(u8) { a, b, c, d };
const PackedStruct = packed struct(u8) { a: u4, b: u4 };
const PackedUnion = packed union(u8) { a: u8, b: i8 };

export var some_enum: Enum = .a;
export var some_packed_struct: PackedStruct = .{ .a = 1, .b = 2 };
export var some_packed_union: PackedUnion = .{ .a = 123 };
```

Shell：

```sh
$ zig test extern_explicit_backing_type.zig
All 0 tests passed.
```

### 浮点取整内建现在可以直接产出整数

`@floor`、`@ceil`、`@round` 和 `@trunc` 现在可以用于把浮点值转换成整数值：

`float-conversion.zig`

```zig
const std = @import("std");
const expectEqual = std.testing.expectEqual;

test "round to int" {
    try example(12, 12.34);
    try example(13, 12.50);
}

fn example(expected: u8, value: f32) !void {
    const actual: u8 = @round(value);
    try expectEqual(expected, actual);
}
```

Shell：

```sh
$ zig test float-conversion.zig
1/1 float-conversion.test.round to int...OK
All 1 tests passed.
```

`@intFromFloat` 现在与 `@trunc` 重复，因此已被 deprecated。

这是“改善 Zig 游戏开发人体工学”这项更大工作的组成部分。

### 一元浮点内建会向下转发结果类型

过去 Zig 不会通过下面这些 builtin 函数继续转发结果类型：

```zig
@sqrt
@sin
@cos
@tan
@exp
@exp2
@log
@log2
@log10
@floor
@ceil
@trunc
@round
```

现在这一点已经改变。过去你不能写：

```zig
const x: f64 = @sqrt(@floatFromInt(N));
```

因为 `@sqrt` 不会把 `f64` 这个结果类型传给 `@floatFromInt`；现在可以了。

这是“改善 Zig 游戏开发人体工学”这项更大工作的组成部分。

### `*u8` 与 `*align(1) u8` 不再是同一个类型

在 `0.16.0` 之前，Zig 把这两者视为完全相同的类型（甚至 `==` 比较都为真）。从这个版本开始，它们变成了两个不同的类型。

不过**两者仍然可以互相强转，包括嵌套在指针里的“in-memory coercion”**，所以日常用法绝大多数情况下不需要任何改动。可以把这种区分理解为类似 `u32` 与 `c_uint` 的关系：技术上不同，但行为一致。

只有在你显式比较 `@TypeOf(...)` 的相等性、或者依赖 `@typeInfo` 反射时，才需要顺手处理一下。

这项变化是 `Reworked Type Resolution` 的一部分。

### 依赖环规则被简化

现在有一些新场景会被视为 dependency loop，而旧版本里不会。

不过，由于类型检查规则被简化、编译错误信息被增强，现在 dependency loop 为什么存在会更明显。这也降低了正式描述 Zig 语言规范的难度。

这项变化是 `Reworked Type Resolution` 的一部分。

### Zero-bit tuple 字段不再被隐式标记为 `comptime`

在 `0.14.0` 时，一个无意引入的规则会把 zero-bit 类型的 tuple 字段隐式提升为 `comptime` 字段：

```zig
comptime {
    const S = struct { void };
    @compileLog(@typeInfo(S).@"struct".fields[0].is_comptime); // @as(bool, true)
}
```

Zig `0.16.0` 回滚了这个变化：上面的 tuple 字段不再被视为 `comptime` 字段。不过，这**不会**阻止该字段的值始终是 comptime-known：

```zig
test "zero-bit tuple field is comptime-known" {
    const S = struct { u32, void };
    var runtime_known: S = undefined;
    runtime_known = .{ 123, {} };
    // 即便 tuple 是 runtime-known，zero-bit 字段仍然是 comptime-known：
    comptime assert(runtime_known[1] == {});
}
const assert = @import("std").debug.assert;
```

换句话说，这项变化几乎完全不是 breaking。唯一可能影响旧代码的情况是：你直接依赖 `@typeInfo` 中的 `std.builtin.StructField.is_comptime`，或者依赖“带显式 `comptime` 字段的 tuple 与不带显式 `comptime` 字段的 tuple 互相等价”：

```zig
//! 这两个测试在 Zig 0.15.x 中都会通过，但在 Zig 0.16.x 中会失败。
test "zero-bit tuple field is comptime" {
    const S = struct { void };
    try expect(@typeInfo(S).@"struct".fields[0].is_comptime);
}
test "comptime annotation on zero-bit field is irrelevant to type equivalence" {
    const A = struct { void };
    const B = struct { comptime void = {} };
    try expect(A == B);
}
const expect = @import("std").testing.expect;
```

### 字段分析变成 lazy

引入新的 `std.Io` 接口之后，官方注意到一个问题：只要把某个类型当成命名空间使用，它的字段也会被分析。例如代码里用了 `std.Io.Writer`，就会把 `std.Io` 的整个 vtable 拉进来——某些场景下这甚至会引入不必要的 codegen，让产物体积明显膨胀。

`0.16.0` 把 `struct`（提醒一下，`.zig` 文件本身就是 struct）、`union`、`enum`、`opaque` 改成只在“需要它的尺寸”或“需要它的某个字段类型”时才解析字段。这意味着：

- 把类型当作命名空间引用时，不会触发字段解析
- 即便构造非解引用指针 `*T`，只要从不实际取尺寸或字段，`T` 也不会被解析

这是一项内部行为优化，对绝大多数代码透明。但如果你以前刻意依赖“引用一个类型就能强迫它被解析”这种隐式行为（例如某些 trait 风格的元编程），可能需要显式触发字段解析（比如调用 `@sizeOf(T)` 或访问一个具体字段）。这条改动是 `Reworked Type Resolution` 的一部分。

### 指向 comptime-only 类型的指针不再是 comptime-only

虽然 `comptime_int` 是 comptime-only 类型，但在 `0.16.0` 里：

- `*comptime_int` 不是 comptime-only
- `[]comptime_int` 也不是 comptime-only

最直观的例子是函数指针：`*const fn () void` 是运行时类型——你不能在运行时解引用它，因为元素类型 `fn () void` 是 comptime-only；但这个指针本身可以在运行时存在。也就是说，这类指针“可以在运行时存在，但只能在编译期解引用”。

这条规则在反射场景下意外地有用。比如你拿到一个 `[]const std.builtin.Type.StructField`，想把每个字段的 `name` 传给运行时代码。

旧写法：先把 `name` 抽成一个 `[]const []const u8`，再把后者传给运行时函数。

新写法：可以直接把 `[]const std.builtin.Type.StructField` 传给运行时函数。这个函数自然不能在运行时从切片里加载一个 `StructField`（毕竟 `StructField` 是 comptime-only），但**可以**加载它的 `name` 字段——因为 `name` 的类型是运行时类型！

这条改动同样是 `Reworked Type Resolution` 的一部分。

### Reworked Byval 语法降级

这是一条编译器内部的改动，但因为它直接影响 `Forbid Runtime Vector Indexes` 等语义，所以值得在升级时知道。

编译器前端早期为了减少中间指令数，曾经尝试用“byval”语义降级表达式。这个实验最后被认定为失败，因为它带来了：

- 数组访问的性能问题
- 显式拷贝下出现意料之外的别名
- 退化场景里代码质量极差

`0.16.0` 改成全程“byref”降级，只在最终一次 load 时才取值。这不仅修掉了上面这些问题，也是为什么本版本会顺手禁止运行时向量索引（详见前面对应小节）。

对应用代码而言，这条改动总体是无感的——但如果你以前观察到“某些数组 / 向量代码有奇怪的别名表现”，升级到 `0.16.0` 后大概率会自动消失。

### 类型解析规则被重做，依赖环错误会更清晰

`0.16.0` 彻底重做了编译器内部的类型解析流程。结果是：

- 大多数以前能工作的代码会继续工作
- 一些以前会莫名其妙报 dependency loop 的代码，现在反而能正常工作
- 也有一小部分旧代码会因为真正的依赖环而在 `0.16.0` 开始报错

最常见的两类“现在会报错”的写法：

1. **结构体在自身字段上做对齐查询**：

   ```zig
   const S = struct {
       foo: [*]align(@alignOf(@This())) u8,
   };
   ```

   `@alignOf(@This())` 需要先知道 `S` 的对齐，但 `S` 的对齐又依赖这个字段的对齐——直接构成依赖环，这版编译器会直接给出明确的错误：`type 'S' depends on itself for alignment query here`。

2. **结构体默认字段值与 `@typeInfo` 反射形成环**：

   ```zig
   const S = struct { x: u32 = default_val };
   const default_val = other_val;
   const other_val = @typeInfo(S).@"struct".fields.len;
   ```

   编译器现在会按依赖顺序把每一跳都列出来，并提示“破坏其中任何一条都能解开环”。

这类问题没有统一的机械式修法，但 `0.16.0` 的错误信息比以前清楚很多，通常你只需要打断这条环上的任意一条依赖即可。如果实在排查不出来，建议加入 Zig 社区交流。

## 标准库

### 标准库总览：新增 / 移除 / 错误集合改名

具体迁移点之外，先把 `0.16.0` 在标准库根命名空间一级的几类总体调整列出来，方便你在升级时一次性扫一遍。

新增：

- `Io.Dir.renamePreserve`：不会替换目标文件的 rename 操作
- `Io.net.Socket.createPair`

直接移除（不再有替代）：

- `SegmentedList`
- `meta.declList`
- `Io.GenericWriter` / `Io.AnyWriter` / `Io.null_writer`
- `Io.CountingReader`
- `Thread.Mutex.Recursive`

错误集合改名 / 合并：

- `error.RenameAcrossMountPoints` ➡️ `error.CrossDevice`
- `error.NotSameFileSystem` ➡️ `error.CrossDevice`
- `error.SharingViolation` ➡️ `error.FileBusy`
- `error.EnvironmentVariableNotFound` ➡️ `error.EnvironmentVariableMissing`
- `std.Io.Dir.rename` 现在返回 `error.DirNotEmpty` 而不是 `error.PathAlreadyExists`

其它零散调整：

- `fmt.Formatter` ➡️ `fmt.Alt`
- `fmt.format` ➡️ `std.Io.Writer.print`
- `fmt.FormatOptions` ➡️ `fmt.Options`
- `fmt.bufPrintZ` ➡️ `fmt.bufPrintSentinel`
- `compress`：`lzma` / `lzma2` / `xz` 已迁到 `Io.Reader` / `Io.Writer`
- `DynLib`：Windows 支持被移除——用户应该直接使用 `LoadLibraryExW` 和 `GetProcAddress`（实际多数人本来就是这么做的）
- `math.sign`：现在返回能容纳所有可能值的最小整数类型
- Windows 上现在会自动触发拉取根证书
- `tar.extract`：对路径穿越进行清理
- `BitSet` / `EnumSet`：`initEmpty` / `initFull` 改为 decl literal

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
const err = std.process.execv(arena, argv);
```

⬇️

```zig
const err = std.process.replace(io, .{ .argv = argv });
```

### 网络 API 全面迁到 `std.Io`

`std.net` 下的所有网络 API 都被迁到了 `std.Io`，统一通过 `Io` 实例发起调用。Windows 下的网络实现也彻底改成直接基于 AFD，不再依赖 `ws2_32.dll`，因此 cancelation 和 Batch 在 Windows 上也能正确工作。

需要注意：

- `Io.Evented` 目前**还没有实现网络**，依赖 evented 网络的代码暂时只能选 `Io.Threaded` 或其它实现
- `Io.net` 当前**也还缺乏非 IP 协议的能力**

如果你过去使用 `std.net.Stream` / `std.net.tcpConnectToHost` 等 API，请按相同思路改为接收 `io: std.Io` 并使用 `std.Io.net.*`；具体迁移建议关注后续标准库文档，因为这部分接口还在快速演进中。

### `std.Thread.Pool` 被移除

`std.Thread.Pool` 已经从标准库中移除。官方迁移建议更谨慎：如果旧代码只是用 `spawnWg` 这类“启动一组任务，然后等待 group 完成”的简单模式，可以迁到 `std.Io.async` / `std.Io.Group.async`；如果依赖复杂同步、必须保证任务真正并发执行才正确，或需要控制并发度，应参考 `std.Io.concurrent` 相关文档，而不是直接机械替换。

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

### 同步原语全面迁到 `std.Io`

`0.16.0` 中，绝大多数同步原语都从 `std.Thread` 迁到了 `std.Io` 命名空间。这样做的核心原因是：**被同步的代码必须能与应用所选的 I/O 实现正确集成**——只有这样，等待行为才能跟随当前 `Io` 实现走。例如，在 `Io.Threaded` 下争用的 mutex 会阻塞线程；在 `Io.Evented` 下则会切换栈而不是阻塞当前线程。这些同步原语同样会正确接入新的 cancelation 模型。

需要注意的是，纯 lock-free 的同步原语并不需要接入 `std.Io`。

完整迁移表：

- `std.Thread.ResetEvent` ➡️ `std.Io.Event`
- `std.Thread.WaitGroup` ➡️ `std.Io.Group`
- `std.Thread.Futex` ➡️ `std.Io.Futex`
- `std.Thread.Mutex` ➡️ `std.Io.Mutex`
- `std.Thread.Condition` ➡️ `std.Io.Condition`
- `std.Thread.Semaphore` ➡️ `std.Io.Semaphore`
- `std.Thread.RwLock` ➡️ `std.Io.RwLock`
- `std.once` 已被移除，建议直接避免全局变量，或者自行实现等价逻辑

### 随机数与熵 API 接入 `std.Io`

随机数生成相关接口在 `0.16.0` 也被收敛到了 `std.Io`：日常熵直接通过 `io.random` 获取，而需要绕开进程内 RNG 状态、强制走 syscall 的“安全熵”则改用 `io.randomSecure`。

`std.crypto.random.bytes` 迁移：

```zig
var buffer: [123]u8 = undefined;
std.crypto.random.bytes(&buffer);
```

⬇️

```zig
var buffer: [123]u8 = undefined;
io.random(&buffer);
```

需要 `std.Random` 接口时：

```zig
const rng = std.crypto.random;
```

⬇️

```zig
const rng_impl: std.Random.IoSource = .{ .io = io };
const rng = rng_impl.interface();
```

`posix.getrandom` 也统一走 `io.random`：

```zig
var buffer: [64]u8 = undefined;
posix.getrandom(&buffer);
```

⬇️

```zig
var buffer: [64]u8 = undefined;
io.random(&buffer);
```

另外，`std.Options.crypto_always_getrandom` 和 `std.Options.crypto_fork_safety` 这两个全局选项也被移除了，对应能力变成了 `io.random` / `io.randomSecure` 两条不同的 API 路径。

### 时间 API 迁到 `std.Io`

时间相关接口也并入 `std.Io`，并允许查询时钟分辨率（可能失败）。`error.Unexpected` 和 `error.ClockUnsupported` 因此从超时和时钟读取的错误集合里被剔除——分辨率被视为无穷大，由用户自行通过 `Clock.resolution` 单独检查。

迁移表：

- `std.time.Instant` ➡️ `std.Io.Timestamp`
- `std.time.Timer` ➡️ `std.Io.Timestamp`
- `std.time.timestamp` ➡️ `std.Io.Timestamp.now`

### `{D}` 格式说明符被移除

为了配合新的 `std.Io.Duration` 类型并增强类型安全，`{D}` 这个旧的 duration 格式说明符已经被移除：

```zig
writer.print("{D}", .{ns});
```

⬇️

```zig
writer.print("{f}", .{std.Io.Duration{ .nanoseconds = ns }});
```

### 调试栈追踪 API 重做

`0.16.0` 重做了一批调试相关 API，特别是栈追踪。核心目标是：**在不依赖帧指针（如 libc 用 `-fomit-frame-pointer` 编译）的情况下，也能实现快速且不会因为越界访问而崩溃的栈展开**。这其实是个很复杂的问题，真正的解法是 unwind information，而不同目标对 unwind 信息的编码方式各不相同；旧实现既 buggy 又不完整，而且常常拖慢性能。

从这个版本开始，标准库**默认使用基于 unwind 信息的“安全”栈展开**；和原来基于帧指针的展开相比，性能开销在大多数场景下是可以接受的。

主要 API 变化：

- `captureStackTrace` ➡️ `captureCurrentStackTrace`
- `dumpStackTraceFromBase` ➡️ `dumpCurrentStackTrace`
- `walkStackWindows` ➡️ `captureCurrentStackTrace`
- `writeStackTraceWindows` ➡️ `writeCurrentStackTrace`
- `std.debug.StackIterator` 现在是内部 API，已从公开导出中移除

新 API 签名示例：

```zig
/// 把已经捕获的栈追踪写入 `t`，并附上源码位置。
pub fn writeStackTrace(st: *const StackTrace, t: Io.Terminal) Writer.Error!void { ... }

/// 捕获当前栈追踪到 `addr_buf`。`addr_buf` 的生命周期需要不短于返回的 StackTrace。
pub noinline fn captureCurrentStackTrace(
    options: StackUnwindOptions,
    addr_buf: []usize,
) StackTrace { ... }
```

`StackUnwindOptions` 提供了几个常用选项：

- `first_address`：忽略到指定返回地址前的所有栈帧（典型用法是把 panic handler 自身从 trace 里抹掉）
- `context`：从指定的 `cpu_context.Native` 而不是当前栈顶开始展开（典型用法是从信号处理函数里打印 trace）
- `allow_unsafe_unwind`：作为最后手段，允许使用可能崩溃的展开策略；默认为 `false`

绝大多数情况下用 `captureCurrentStackTrace` 就够了；如果需要打印当前栈，对应的还有 `writeCurrentStackTrace` / `dumpCurrentStackTrace`。`StackIterator` 已经不再适合直接使用，如果你以前依赖它，可以考虑直接用 `std.debug.SelfInfo` 提供的更底层 API；后者还可以通过定义 `@import("root").debug.SelfInfo` 替换实现，从而让栈追踪在标准库不直接支持的目标（甚至 freestanding 目标）上也能工作。

### `ucontext_t` 与相关类型 / 函数被移除

`std.posix` 不再提供 `ucontext_t` 系列绑定。原因有两条：

- 用 `ucontext.h` 函数做非局部控制流的能力本来就不在 Zig 支持范围内，且 POSIX 已弃用，musl 也不再提供
- 用 `ucontext_t` 在信号处理函数里读取机器状态这件事，标准库做得很差——这类类型在不同架构下变化很快，标准库一直没跟上

如果你的代码确实需要在信号处理里访问机器状态，建议自行定义贴合具体场景的 `ucontext_t` / `mcontext_t`。`std.debug.cpu_context.signal_context_t` 也在这一版本里相应调整。

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

`fs` 全部 API 都迁到了 `Io`。和 0.15 那次 “writergate” 不同，这次虽然 breaking 范围很大，但绝大多数迁移机械、不需要特别多的判断。最典型的形态就是给原本无参的方法加一个 `io`：

```zig
file.close();
```

⬇️

```zig
file.close(io);
```

升级 diff 可能很长，但每一处都很容易看懂。

新增 API：

- `Io.Dir.hardLink`
- `Io.Dir.Reader`
- `Io.Dir.setFilePermissions`
- `Io.Dir.setFileOwner`
- `Io.File.NLink`

无对应替代被直接移除的 API：

- `fs.realpathZ` / `fs.realpathW` / `fs.realpathW2`
- `fs.makeDirAbsoluteZ` / `fs.deleteDirAbsoluteZ` / `fs.openDirAbsoluteZ`
- `fs.renameAbsoluteZ` / `fs.renameZ`
- `fs.deleteTreeAbsolute`
- `fs.symLinkAbsoluteW`
- `fs.Dir.realpathZ` / `fs.Dir.realpathW` / `fs.Dir.realpathW2`
- `fs.Dir.deleteFileZ` / `fs.Dir.deleteFileW` / `fs.Dir.deleteDirZ` / `fs.Dir.deleteDirW`
- `fs.Dir.renameZ` / `fs.Dir.renameW`
- `fs.Dir.symLinkWasi` / `fs.Dir.symLinkZ` / `fs.Dir.symLinkW`
- `fs.Dir.readLinkWasi` / `fs.Dir.readLinkZ` / `fs.Dir.readLinkW`
- `fs.Dir.adaptToNewApi` / `fs.Dir.adaptFromNewApi`
- `fs.File.isCygwinPty`
- `fs.File.adaptToNewApi` / `fs.File.adaptFromNewApi`

重命名 / 迁移过的 API（节选最常用的部分）：

| 0.15.x                                      | 0.16.0                                                          |
| ------------------------------------------- | --------------------------------------------------------------- |
| `fs.Dir`                                    | `std.Io.Dir`                                                    |
| `fs.File`                                   | `std.Io.File`                                                   |
| `fs.cwd`                                    | `std.Io.Dir.cwd`                                                |
| `fs.copyFileAbsolute`                       | `std.Io.Dir.copyFileAbsolute`                                   |
| `fs.makeDirAbsolute`                        | `std.Io.Dir.createDirAbsolute`                                  |
| `fs.deleteDirAbsolute`                      | `std.Io.Dir.deleteDirAbsolute`                                  |
| `fs.openDirAbsolute`                        | `std.Io.Dir.openDirAbsolute`                                    |
| `fs.openFileAbsolute`                       | `std.Io.Dir.openFileAbsolute`                                   |
| `fs.accessAbsolute`                         | `std.Io.Dir.accessAbsolute`                                     |
| `fs.createFileAbsolute`                     | `std.Io.Dir.createFileAbsolute`                                 |
| `fs.deleteFileAbsolute`                     | `std.Io.Dir.deleteFileAbsolute`                                 |
| `fs.renameAbsolute`                         | `std.Io.Dir.renameAbsolute`                                     |
| `fs.readLinkAbsolute`                       | `std.Io.Dir.readLinkAbsolute`                                   |
| `fs.symLinkAbsolute`                        | `std.Io.Dir.symLinkAbsolute`                                    |
| `fs.realpath`                               | `std.Io.Dir.realPathFileAbsolute`                               |
| `fs.realpathAlloc`                          | `std.Io.Dir.realPathFileAbsoluteAlloc`                          |
| `fs.rename`                                 | `std.Io.Dir.rename`                                             |
| `fs.has_executable_bit`                     | `std.Io.File.Permissions.has_executable_bit`                    |
| `fs.defaultWasiCwd`                         | `std.os.defaultWasiCwd`                                         |
| `fs.openSelfExe`                            | `std.process.openExecutable`                                    |
| `fs.selfExePath`                            | `std.process.executablePath`                                    |
| `fs.selfExePathAlloc`                       | `std.process.executablePathAlloc`                               |
| `fs.selfExeDirPath`                         | `std.process.executableDirPath`                                 |
| `fs.selfExeDirPathAlloc`                    | `std.process.executableDirPathAlloc`                            |
| `fs.Dir.setAsCwd`                           | `std.process.setCurrentDir`                                     |
| `fs.Dir.realpath`                           | `std.Io.Dir.realPathFile`                                       |
| `fs.Dir.realpathAlloc`                      | `std.Io.Dir.realPathFileAlloc`                                  |
| `fs.Dir.makeDir`                            | `std.Io.Dir.createDir`                                          |
| `fs.Dir.makePath`                           | `std.Io.Dir.createDirPath`                                      |
| `fs.Dir.makeOpenDir`                        | `std.Io.Dir.createDirPathOpen`                                  |
| `fs.Dir.atomicSymLink`                      | `std.Io.Dir.symLinkAtomic`                                      |
| `fs.Dir.chmod`                              | `std.Io.Dir.setPermissions`                                     |
| `fs.Dir.chown`                              | `std.Io.Dir.setOwner`                                           |
| `fs.File.Mode`                              | `std.Io.File.Permissions`                                       |
| `fs.File.PermissionsWindows`                | `std.Io.File.Permissions`                                       |
| `fs.File.PermissionsUnix`                   | `std.Io.File.Permissions`                                       |
| `fs.File.default_mode`                      | `std.Io.File.Permissions.default_file`                          |
| `fs.File.getOrEnableAnsiEscapeSupport`      | `std.Io.File.enableAnsiEscapeCodes`                             |
| `fs.File.setEndPos`                         | `std.Io.File.setLength`                                         |
| `fs.File.getEndPos`                         | `std.Io.File.length`                                            |
| `fs.File.seekTo` / `seekBy` / `seekFromEnd` | `std.Io.File.Reader.seekTo` / `Reader.seekBy` / `Writer.seekTo` |
| `fs.File.getPos`                            | `std.Io.File.Reader.logicalPos` / `std.Io.Writer.logicalPos`    |
| `fs.File.mode`                              | `std.Io.File.stat().permissions.toMode`                         |
| `fs.File.chmod`                             | `std.Io.File.setPermissions`                                    |
| `fs.File.chown`                             | `std.Io.File.setOwner`                                          |
| `fs.File.updateTimes`                       | `std.Io.File.setTimestamps` / `setTimestampsNow`                |
| `fs.File.read` / `readv`                    | `std.Io.File.readStreaming`                                     |
| `fs.File.pread` / `preadv`                  | `std.Io.File.readPositional`                                    |
| `fs.File.preadAll`                          | `std.Io.File.readPositionalAll`                                 |
| `fs.File.write` / `writev`                  | `std.Io.File.writeStreaming`                                    |
| `fs.File.pwrite` / `pwritev`                | `std.Io.File.writePositional`                                   |
| `fs.File.writeAll`                          | `std.Io.File.writeStreamingAll`                                 |
| `fs.File.pwriteAll`                         | `std.Io.File.writePositionalAll`                                |
| `fs.File.copyRange` / `copyRangeAll`        | `std.Io.File.writer`                                            |

这一表里许多函数除了改名，还顺手在签名里塞了一个 `io: std.Io` 参数。

另外这些三个老的命名空间常量被 deprecated：

- `fs.path` ➡️ `std.Io.Dir.path`
- `fs.max_path_bytes` ➡️ `std.Io.Dir.max_path_bytes`
- `fs.max_name_bytes` ➡️ `std.Io.Dir.max_name_bytes`

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

#### 选择性遍历目录树

旧的 `Dir.walk` 没法跳过特定子目录。`0.16.0` 新增了 `walkSelectively`，每次进入新目录都需要显式 `enter`，从而避免对被跳过目录做无谓的 open/close syscall。

```zig
var walker = try dir.walk(gpa);
defer walker.deinit();

while (try walker.next(io)) |entry| {
    // ...
}
```

⬇️

```zig
var walker = try dir.walkSelectively(gpa);
defer walker.deinit();

while (try walker.next(io)) |entry| {
    if (failsFilter(entry)) continue;
    if (entry.kind == .directory) {
        try walker.enter(io, entry);
    }
    // ...
}
```

另外 `Walker.Entry` 增加了 `depth` 函数，`Walker` 与 `SelectiveWalker` 都增加了 `leave`，便于在遍历到一半时跳出当前子目录。

#### `fs.path` 对 Windows 路径处理更一致

`std.fs.path` 全部函数都更正确地处理 Windows 的 UNC、"rooted" 和 drive-relative 路径。API 上的具体变化：

- `windowsParsePath` / `diskDesignator` / `diskDesignatorWindows` ➡️ `parsePath` / `parsePathWindows` / `parsePathPosix`
- 新增 `getWin32PathType`
- `componentIterator` / `ComponentIterator.init` 不再返回错误

#### `File.MemoryMap` 语义收紧

内存映射的指针内容现在被定义为只在显式 sync point 后同步，这让基于普通文件操作的回退实现成为合法选择，也允许 evented I/O 用 evented 文件 I/O 来实现 sync point。

技术上这是 breaking change：positional 文件读写的错误集合更窄；在 WASI 上现在会正确返回 `error.IsDir` 而不是 `error.NotOpenForReading`。

#### 内存锁定 / 保护 API 迁到 `std.process`

`mmap` / `mprotect` 的标志现在改为类型安全的结构体字段：

```zig
std.posix.PROT.READ | std.posix.PROT.WRITE,
```

⬇️

```zig
.{ .READ = true, .WRITE = true },
```

`mlock` 系列也搬到了 `std.process`：

```zig
try std.posix.mlock();
try std.posix.mlock2(slice, std.posix.MLOCK_ONFAULT);
try std.posix.mlockall(slice, std.posix.MCL_CURRENT|std.posix.MCL_FUTURE);
```

⬇️

```zig
try std.process.lockMemory(slice, .{});
try std.process.lockMemory(slice, .{ .on_fault = true });
try std.process.lockMemoryAll(.{ .current = true, .future = true });
```

#### "Preopens" 迁到 `std.process`

WASI 上预先打开的文件句柄从 `std.fs.wasi.Preopens` 搬到了 `std.process.Preopens`：

```zig
const wasi_preopens: std.fs.wasi.Preopens = try .preopensAlloc(arena);
```

⬇️

```zig
const preopens: std.process.Preopens = try .init(arena);
```

或者直接通过前面 `Juicy Main` 部分介绍的 `std.process.Init.preopens` 拿到。在非 WASI 系统上数据类型是 `void`——你不用就不会付出代价。

#### `atomicFile` 重构为 `createFileAtomic`

这次重构主要动机是把 `std.crypto.random` 的调用挪到 `std.Io.VTable` 之下（具体是 `std.Io.File.Atomic.init` 里那一处），同时顺手在 Linux 上接入了 `O_TMPFILE`——也就是“创建一个无名 fd，操作完后再 link 到目标位置；如果进程提前结束，OS 会自动回收，不留临时垃圾”这套机制。

不过 `O_TMPFILE` 在内核 / libc 这一层有不少坑（`linkat()` 缺 `AT_REPLACE`、错误码为 `EISDIR`/`ENOENT` 这种反直觉行为等），所以当前实现是“能用上 `O_TMPFILE` 的场景用，其余场景仍然走原来的随机文件名 + `renameat()`”。这套封装让 Zig 端不用感知差异，将来 OS 修了 bug 直接受益。

旧写法：

```zig
var buffer: [1024]u8 = undefined;
var atomic_file = try dest_dir.atomicFile(io, dest_path, .{
    .permissions = actual_permissions,
    .write_buffer = &buffer,
});
defer atomic_file.deinit();

// do something with atomic_file.file_writer;

try atomic_file.flush();
try atomic_file.renameIntoPlace();
```

⬇️

```zig
var atomic_file = try dest_dir.createFileAtomic(io, dest_path, .{
    .permissions = actual_permissions,
    .make_path = true,
    .replace = true,
});
defer atomic_file.deinit(io);

var buffer: [1024]u8 = undefined; // 仅在没有直接 fd-to-fd 通路时使用
var file_writer = atomic_file.file.writer(io, &buffer);

// do something with file_writer

try file_writer.flush();
try atomic_file.replace(io); // 或者把上面的 .replace 改为 false，再调用 link()
```

另外这一版还新增了 `std.Io.File.hardLink` API（目前仅 Linux）——它是 `O_TMPFILE` 没有 replace 语义时把 fd 物化为常规文件的必备工具。

#### 其他值得顺手处理的文件系统改动

- `fs.getAppDataDir` 已被移除，应用应自行决定“应用数据目录”的策略；可考虑第三方包 `known-folders`
- `Io.Writer.Allocating` 新增了 `alignment: std.mem.Alignment` 字段（运行时已知对齐，配合 Allocator API 的 raw 函数变体使用）

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

- 新增 `heap.MemoryPoolUnmanaged` / `heap.MemoryPoolAlignedUnmanaged` / `heap.MemoryPoolExtraUnmanaged`
- `PriorityDequeue` 不再持有 `Allocator` 字段
- `PriorityQueue` 不再持有 `Allocator` 字段
- `ArrayHashMap`、`AutoArrayHashMap`、`StringArrayHashMap` 被移除
- `AutoArrayHashMapUnmanaged` ➡️ `std.array_hash_map.Auto`
- `StringArrayHashMapUnmanaged` ➡️ `std.array_hash_map.String`
- `ArrayHashMapUnmanaged` ➡️ `std.array_hash_map.Custom`
- `PriorityQueue` 和 `PriorityDequeue` 都继续往 `.empty` / `push` / `pop` 风格迁移

`PriorityQueue` 现在可以通过 `.empty` 初始化（不再需要 `init` 方法），最小堆和最大堆只需要换比较函数即可：

```zig
fn lessThan(context: void, a: u32, b: u32) Order {
    _ = context;
    return std.math.order(a, b);
}
const MinHeap = std.PriorityQueue(u32, void, lessThan);
var queue: MinHeap = .empty;
```

```zig
fn greaterThan(context: void, a: u32, b: u32) Order {
    _ = context;
    return std.math.order(a, b).invert();
}
const MaxHeap = std.PriorityQueue(u32, void, greaterThan);
var queue: MaxHeap = .empty;
```

常见重命名：

- `init` ➡️ `initContext`
- `add` ➡️ `push`
- `addUnchecked` ➡️ `pushUnchecked`
- `addSlice` ➡️ `pushSlice`
- `remove` ➡️ `pop`
- `removeOrNull` ➡️ `pop`
- `removeIndex` ➡️ `popIndex`

`PriorityDequeue` 的改动整体跟随 `Deque`：含 `add` 的方法改名为 `push`，含 `remove` 的方法改名为 `pop`；`popMinOrNull` / `popMaxOrNull` 与 `popMin` / `popMax` 合并（功能不变）；默认字段值通过 `.empty` 常量而不是 `init()` 方法初始化。

常见重命名：

- `init` ➡️ `.empty`
- `add` ➡️ `push`
- `addSlice` ➡️ `pushSlice`
- `addUnchecked` ➡️ `pushUnchecked`
- `removeMinOrNull` / `removeMin` ➡️ `popMin`
- `removeMaxOrNull` / `removeMax` ➡️ `popMax`
- `removeIndex` ➡️ `popIndex`

### 分配器与并发模型继续调整

有两条需要直接注意：

- `std.heap.ArenaAllocator` 现在变成了 thread-safe 且 lock-free。它在单线程场景下的性能与旧实现相当，在最多 7 线程并发的场景下，则比“旧实现 + `ThreadSafeAllocator` 包装”略快；同样地，未来 `std.heap.DebugAllocator` 也会朝这个方向走
- `std.heap.ThreadSafeAllocator` 被移除——“mutex 包一层 allocator”这种实现既必然要求 `Io` 实例又通常很慢，已经被官方视为反模式

如果你的旧代码是“在外层包一层 `ThreadSafeAllocator`”，现在应改为直接选用本身适合并发场景的 allocator，或者改造调用结构，避免再依赖这层包装器。

### Deflate 压缩与解压重做

`std.compress.flate` 这一轮**新增了从零实现的 deflate 压缩器**：

- 默认 writer：以 writer 缓冲区作为历史窗口、用链式哈希表寻找匹配，token 累积到阈值后整块输出
- 新增 `Raw` writer：完全只输出 store block（即未压缩字节），借助数据向量高效发送 block header 与数据
- 新增 `Huffman` writer：只做 Huffman 压缩，不做匹配

`Raw` 与 `Huffman` 因为不需要保留历史，可以更直接地利用新的 writer 语义。

`token` 中的字面量与距离编码参数也被重做：参数现在是数学方法推导出来的，更昂贵的那部分依然走查表（`ReleaseSmall` 例外）。

解压侧的 bit 读取也大幅简化，充分利用了底层 reader 可以 peek 的能力，并修掉了若干和 limit 处理相关的 bug。

性能数据（与 zlib 对比，越快越好）：

- **默认级别压缩**：std-deflate 比 zlib 快约 **9.7%**，cache miss 与分支误预测都明显更少
- **最高级别压缩**：与 zlib 持平（差异 1% 以内）
- **解压（vs 上一版 std）**：新实现快约 **9.5%**，CPU 周期与指令数都减少约 10%

压缩比层面，zlib 在默认级别下高约 1.00%，最高级别下高约 0.77%——这是后续打磨的方向。

### `std.crypto` 新增 AES-SIV 与 AES-GCM-SIV

针对 nonce 重用敏感的场景，`std.crypto` 现在内置了：

- **AES-SIV**：在密钥包装（key wrapping）这类场景里特别有用
- **AES-GCM-SIV**：在嵌入式 / 受限目标上尤其合适

如果你的项目以前不得不靠第三方 crate 提供这两个原语，现在可以直接换到标准库版本。

### `std.crypto` 新增 Ascon-AEAD / Ascon-Hash / Ascon-CHash

NIST SP 800-232 已经发布之后，Zig 标准库一次性补齐基于 Ascon 置换的高层构造：

- `Ascon-AEAD`：AEAD 加密
- `Ascon-Hash`：定长哈希
- `Ascon-CHash`：可定制化的哈希

之前 Ascon 置换本身已经在标准库里，但建立在它之上的高层构造一直被刻意推迟到 NIST 最终规范公布。现在终于可以在标准库内直接使用。

### `std.Progress` 支持 Windows 跨进程上报

`std.Progress` 现在支持在 Windows 下报告子进程的进度，子进程的进度会自动反映到父进程的进度树中。同时，最大节点名称长度从 40 提升到 120。

如果你以前因为 Windows 下 progress 不能跨进程聚合而做了 workaround，可以删掉那部分代码。

### Windows 上网络 API 不再依赖 `ws2_32.dll`

Windows 上所有网络 API 现在直接基于 AFD 实现，不再走 `ws2_32.dll`。这意味着：

- 一批网络相关历史 bug 被修复
- cancelation 与 Batch 在 Windows 上能正确生效
- 避开了 `ws2_32.dll` 的性能陷阱（例如 socket handle 旁挂的 hash table）

对应用层代码这通常是透明的，但如果你以前手写了 `extern "ws2_32"` 的绑定来补标准库不足，现在可以重新评估是否还需要继续维护这部分代码。

### Windows 上向 NtDll 的迁移基本完成

`0.16.0` 之后，Windows 上几乎所有标准库功能都直接基于最低层级的稳定 syscall API 实现。仍会调用 Windows DLL 的 extern 函数仅剩：

- `kernel32.CreateProcessW`
- `crypt32` 一组：`CertOpenStore` / `CertCloseStore` / `CertEnumCertificatesInStore` / `CertFreeCertificateContext` / `CertAddEncodedCertificateToStore` / `CertOpenSystemStoreW` / `CertGetCertificateChain` / `CertFreeCertificateChain` / `CertVerifyCertificateChainPolicy`

短期内不打算继续迁移这两组。如果你需要在 XP 这类老 Windows 上运行，或者更倾向走高层 DLL，建议作为社区项目实现一个不依赖 NtDll 的第三方 `Io`。

### 各目标上的栈回溯能力进一步扩大

`0.16.0` 在“几乎所有真正在用的目标”上都补齐了崩溃和 `DebugAllocator` 场景下的栈追踪能力。Windows 下打印 stack trace 时，inline caller 会从 PDB debug info 中被解析；如果 debug info 模糊，所有候选 caller 都会被打印出来。error return trace 现在在所有平台上都包含 inline caller。

这一切都是“为做游戏开发改善 Zig 体验”这条更大计划的一部分，对应用代码通常透明，但意味着遇到崩溃时你能拿到更多有用信息。

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

`--error-style` 与 `--multiline-errors` 都额外支持通过环境变量 `ZIG_BUILD_ERROR_STYLE` / `ZIG_BUILD_MULTILINE_ERRORS` 设默认值，便于你在 shell 配置里一次性写好。`--multiline-errors` 可选值为 `indent`（新默认）、`newline`、`none`，分别对应“后续行缩进对齐第一行”“在第一行前补一个换行让所有行从首列起头”“原样输出不做处理”。

另外，Zig 不再读取 `ZIG_BTRFS_WORKAROUND` 这个旧环境变量——上游 Linux 那边的 bug 早已修复（[#17095](https://github.com/ziglang/zig/issues/17095)）。

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
