---
outline: deep
---

# 结构体

> 在 zig 中，类型是一等公民！

结构体本身是一个高级的数据结构，用于将多个数据表示为一个整体。

## 基本语法

结构体的组成：

- 首部关键字 `struct`
- 和变量定义一样的结构体名字
- 多个字段
- 方法
- 多个声明

以下是一个简短的结构体声明：

::: code-group

```zig [default]
const Circle = struct {
    radius: u8,

    const PI: f16 = 3.14;

    pub fn init(radius: u8) Circle {
        return Circle{ .radius = radius };
    }

    fn area(self: *Circle) f16 {
        return @as(f16, @floatFromInt(self.radius * self.radius)) * PI;
    }
};
```

```zig [more]
const std = @import("std");

const Circle = struct {
    radius: u8,

    const PI: f16 = 3.14;

    pub fn init(radius: u8) Circle {
        return Circle{ .radius = radius };
    }

    fn area(self: *Circle) f16 {
        return @as(f16, @floatFromInt(self.radius * self.radius)) * PI;
    }
};

pub fn main() void {
    var radius: u8 = 5;
    var circle = Circle.init(radius);
    std.debug.print("The area of a circle with radius {} is {d:.2}\n", .{ radius, circle.area() });
}
```

:::

上方的代码的内容：

- 定义了一个结构体 `Circle`，用于表示一个圆
- 包含字段 `radius`
- 一个声明 `PI`
- 包含两个方法 `init` 和 `area`

:::details 更复杂的例子

下面是一个日常会用到的一个结构体例子，系统账号管理的使用：

::: code-group

```zig [default]
const User = struct {
    userName: []u8,
    password: []u8,
    email: []u8,
    active: bool,

    pub const writer = "learnzig";

    pub fn init(userName: []u8, password: []u8, email: []u8, active: bool) User {
        return User{
            .userName = userName,
            .password = password,
            .email = email,
            .active = active,
        };
    }

    pub fn print(self: *User) void {
        std.debug.print(
            \\username: {s}
            \\password: {s}
            \\email: {s}
            \\active: {}
            \\
        , .{
            self.userName,
            self.password,
            self.email,
            self.active,
        });
    }
};
```

```zig [more]
const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const User = struct {
    userName: []u8,
    password: []u8,
    email: []u8,
    active: bool,

    pub const writer = "learnzig";

    pub fn init(userName: []u8, password: []u8, email: []u8, active: bool) User {
        return User{
            .userName = userName,
            .password = password,
            .email = email,
            .active = active,
        };
    }

    pub fn print(self: *User) void {
        std.debug.print(
            \\username: {s}
            \\password: {s}
            \\email: {s}
            \\active: {}
            \\
        , .{
            self.userName,
            self.password,
            self.email,
            self.active,
        });
    }
};

const name = "xiaoming";
const passwd = "123456";
const mail = "123456@qq.com";

pub fn main() !void {
    // var username = [_]8{};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    const username = try allocator.alloc(u8, 20);
    defer allocator.free(username);

    @memset(username, 0);
    @memcpy(username[0..name.len], name);

    const password = try allocator.alloc(u8, 20);
    defer allocator.free(password);

    @memset(password, 0);
    @memcpy(password[0..passwd.len], passwd);

    const email = try allocator.alloc(u8, 20);
    defer allocator.free(email);

    @memset(email, 0);
    @memcpy(email[0..mail.len], mail);

    var user = User.init(username, password, email, true);
    user.print();
}
```

在以上的代码中，我们使用了内存分配的功能，并且使用了切片和多行字符串，以及 `defer` 语法（在当前作用域的末尾执行语句）。

:::

:::info 🅿️ 提示

值得注意的是，结构体的方法除了使用 `.` 语法来使用外，和其他的函数没有任何区别！这意味着你可以在任何你用普通函数的地方使用结构体的方法。

:::

## 自动推断

zig 在使用结构体的时候还支持省略结构体类型，只要能让 zig 编译器推断出类型即可，例如：

```zig
const Point = struct { x: i32, y: i32 };

var pt: Point = .{
    .x = 13,
    .y = 67,
};
```

## 泛型实现

依托于“类型是 zig 的一等公民”，我们可以很容易的实现泛型。

此处仅仅是简单提及一下该特性，后续我们会专门讲解泛型这一个利器！

以下是一个链表的类型实现：

```zig
fn LinkedList(comptime T: type) type {
    return struct {
        pub const Node = struct {
            prev: ?*Node,
            next: ?*Node,
            data: T,
        };

        first: ?*Node,
        last:  ?*Node,
        len:   usize,
    };
}
```

:::info 🅿️ 提示

当然这种操作不局限于声明变量，你在函数中也可以使用（当编译器无法完成推断时，它会给出一个完整的堆栈跟踪）！

:::

## 字段默认值

结构体允许使用默认值，只需要在定义结构体的时候声明默认值即可：

```zig
const Foo = struct {
    a: i32 = 1234,
    b: i32,
};

const x = Foo{
    .b = 5,
};
```

## 空结构体

你还可以使用空结构体，具体如下：

::: code-group

```zig [default]
const Empty = struct {
    // const PI = 3.14;
};
```

```zig [more]
const std = @import("std");

const Empty = struct {
    // const PI = 3.14;
};

pub fn main() void {
    std.debug.print("{}\n", .{@sizeOf(Empty)});
}
```

:::

:::info 🅿️ 提示

使用 Go 的朋友对这个可能很熟悉，在 Go 中经常用空结构体做实体在 chan 中传递，它的内存大小为 0 ！

:::

## 通过字段获取基指针

为了获得最佳的性能，结构体字段的顺序是由编译器决定的，但是，我们可以仍然可以通过结构体字段的指针来获取到基指针！

```zig
const Point = struct {
    x: f32,
    y: f32,
};

fn setYBasedOnX(x: *f32, y: f32) void {
    const point = @fieldParentPtr(Point, "x", x);
    point.y = y;
}
```

这里使用了内置函数 [`@fieldParentPtr`](https://ziglang.org/documentation/0.11.0/#toc-fieldParentPtr) ，它会根据给定字段指针，返回对应的结构体基指针。

## 元组

元组实际上就是不指定字段的（匿名）结构体。

由于没有字段名，zig 会为每个值分配一个整数的字段名，但是它无法通过正常的 `.` 语法来访问，但可以增加一个修饰符 `@""`，通过它使用 `.` 语法访问元组中的元素。

```zig
// 我们定义了一个元组类型
const Tuple = struct{ u8, u8 };

// 直接使用字面量来定义一个元组
const values = .{
    @as(u32, 1234),
    @as(f64, 12.34),
    true,
    "hi",
};

const hi = values.@"3"; // "hi"
```

当然，以上的语法很啰嗦,所以 zig 提供了类似数组的语法来访问元组，例如 `values[3]` 的值就是 "hi"。

:::info 🅿️ 提示

元组还有一个和数组一样的字段 `len`，并且支持 `++` 和 `**` 运算符，以及[内联 for](#)。

:::

<!-- TODO：增加内联for的地址 -->

## 高级特性

以下特性如果你连名字都没有听说过，那就代表你目前无需了解以下部分，待需要时再来学习即可！

> zig 并不保证结构体字段的顺序和结构体大小，但保证它是 ABI 对齐的。

### extern

`extern` 关键字用于修饰结构体，使其内存布局保证匹配对应目标的 C ABI。

这个关键字适合使用于嵌入式或者裸机器上，其他情况下建议使用 `packed` 或者普通结构体。

### packed

`packed` 关键字修饰结构体，普通结构体不同，它保证了内存布局：

- 字段严格按照声明的顺序排列
- 在不同字段之间不会存在位填充（不会发生内存对齐）
- zig 支持任意位宽的整数（通常不足8位的仍然使用8位），但在 `packed` 下，会只使用它们的位宽
- `bool` 类型的字段，仅有一位
- 枚举类型只使用其整数标志位的位宽
- 联合类型只使用其最大位宽
- 根据目标的字节顺序，非 ABI 字段会被尽量压缩为占用尽可能小的 ABI 对齐整数的位宽。

以上几个特性就有很多有意思的点值得我们使用和注意。

1. zig 允许我们获取字段指针，但这些指针并不是普通指针（涉及到了位偏移），无法作为普通的函数参数使用，这个情况可以使用 [`@bitOffsetOf`](https://ziglang.org/documentation/0.11.0/#bitOffsetOf) 和 [`@offsetOf`](https://ziglang.org/documentation/0.11.0/#offsetOf) 观察到：

:::details 示例

```zig
const std = @import("std");
const expect = std.testing.expect;

const BitField = packed struct {
    a: u3,
    b: u3,
    c: u2,
};

test "pointer to non-bit-aligned field" {
    comptime {
        try expect(@bitOffsetOf(BitField, "a") == 0);
        try expect(@bitOffsetOf(BitField, "b") == 3);
        try expect(@bitOffsetOf(BitField, "c") == 6);

        try expect(@offsetOf(BitField, "a") == 0);
        try expect(@offsetOf(BitField, "b") == 0);
        try expect(@offsetOf(BitField, "c") == 0);
    }
}
```

:::

2. 使用位转换 [`@bitCast`](https://ziglang.org/documentation/0.11.0/#bitCast) 和指针转换 [`@ptrCast`](https://ziglang.org/documentation/0.11.0/#ptrCast) 来强制对 `packed` 结构体进行转换操作：

:::details 示例

```zig
const std = @import("std");
// 这里获取目标架构是字节排序方式，大端和小端
const native_endian = @import("builtin").target.cpu.arch.endian();
const expect = std.testing.expect;

const Full = packed struct {
    number: u16,
};
const Divided = packed struct {
    half1: u8,
    quarter3: u4,
    quarter4: u4,
};

test "@bitCast between packed structs" {
    try doTheTest();
    try comptime doTheTest();
}

fn doTheTest() !void {
    try expect(@sizeOf(Full) == 2);
    try expect(@sizeOf(Divided) == 2);
    var full = Full{ .number = 0x1234 };
    var divided: Divided = @bitCast(full);
    try expect(divided.half1 == 0x34);
    try expect(divided.quarter3 == 0x2);
    try expect(divided.quarter4 == 0x1);

    var ordered: [2]u8 = @bitCast(full);
    switch (native_endian) {
        .Big => {
            try expect(ordered[0] == 0x12);
            try expect(ordered[1] == 0x34);
        },
        .Little => {
            try expect(ordered[0] == 0x34);
            try expect(ordered[1] == 0x12);
        },
    }
}
```

:::

3. 还可以对 `packed` 的结构体的指针设置内存对齐来访问对应的字段：

> 这里说明可能有些不清楚，请见谅！

```zig
const std = @import("std");
const expect = std.testing.expect;

const S = packed struct {
    a: u32,
    b: u32,
};
test "overaligned pointer to packed struct" {
    var foo: S align(4) = .{ .a = 1, .b = 2 };
    const ptr: *align(4) S = &foo;
    const ptr_to_b: *u32 = &ptr.b;
    try expect(ptr_to_b.* == 2);
}
```

### 命名规则

由于在 zig 中很多结构是匿名的（例如可以把一个源文件看作是一个匿名的结构体），所以 zig 基于一套规则来进行命名：

- 如果一个结构体位于变量的初始化表达式中，它就以该变量命名（实际上就是声明结构体类型）。
- 如果一个结构体位于 `return` 表达式中，那么它以返回的函数命名，并序列化参数。
- 其他情况下，结构体会获得一个类似 `filename.funcname.__struct_ID` 的名字。
- 如果该结构体在另一个结构体中声明，它将以父结构体和前面的规则推断出的名称命名，并用点分隔。

上面几条规则看着很模糊是吧，我们来几个小小的示例来演示一下：

::: code-group

```zig [default]
const std = @import("std");

pub fn main() void {
    const Foo = struct {};
    std.debug.print("variable: {s}\n", .{@typeName(Foo)});
    std.debug.print("anonymous: {s}\n", .{@typeName(struct {})});
    std.debug.print("function: {s}\n", .{@typeName(List(i32))});
}

fn List(comptime T: type) type {
    return struct {
        x: T,
    };
}
```

```sh [output]
variable: struct_name.main.Foo
anonymous: struct_name.main__struct_3509
function: struct_name.List(i32)
```

:::
