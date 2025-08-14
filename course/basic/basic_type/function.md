# 函数

> 函数是编程语言中最为基本的语句。

## 基本使用

Zig 的函数结构清晰，你可以一眼看出其组成部分。我们来用一个简单的函数作为说明：

<<<@/code/release/function.zig#add

> 如果你有 C 的使用经验，一眼就可以看出来各自的作用。

具体说明如下：

1. `pub` 是访问修饰符，表示函数是公共可访问的（其他文件 `import` 该文件后可以直接使用此函数）。
2. `fn` 是关键字，用于定义函数。
3. `add` 是标识符，作为函数名。
4. `a: u8` 是参数的标识符和类型。这里有两个参数 `a` 和 `b`，它们的类型都是 `u8`。
5. `u8` 是函数的返回类型。在 Zig 中，一个函数只能返回一个值。

如果没有返回值，请使用 `void`。**_Zig 原则上不允许忽略函数的返回值_**；如果需要忽略，可将返回值分配给 `_`，编译器将自动忽略该返回值。

:::info 🅿️ 提示

你可能注意到了有的函数定义是这样子的：

<<<@/code/release/function.zig#max

其中 `comptime T: type` 可能对你来说比较陌生，这是[编译期](../../advanced/comptime.md)参数，它是实现鸭子类型（泛型）的关键语法。

:::

:::details 关于函数命名

这里命名规则没什么强制性的要求，你只需要保证符合变量声明的 [_标识符规范_](/basic/define-variable.html#标识符命名) 即可。

如果你需要命名规范的建议，可以参考 Zig 源码的命名方式，它使用的是[小驼峰命名法](#)。

:::

::: warning

函数体和函数指针之间存在区别：函数体是仅限编译时的类型，而函数指针可能是运行时已知的。

例如，`*const fn (a: i8, b: i8) i8` 就是一个函数指针类型。

:::

## 参数传递

> 参数传递是一个经典问题。在高级语言中，存在“值传递”和“引用传递”两种情况，这无疑增加了程序员的认知负担。

Zig 在这方面的处理是：原始类型（如整型、布尔）完全使用值传递。对于原始类型，这种策略开销非常小，通常只需设置对应的寄存器即可。

对于复合类型（如结构体、联合、数组），编译器会根据具体情况决定是使用“值传递”还是“引用传递”。

但作为开发者，你只需要记住：**_函数的参数是不可变的_**。

:::info 🅿️ 提示

对于外部函数（使用 `extern` 修饰），Zig 遵循 C ABI（应用程序二进制接口）按值传递结构体和联合类型。

:::

## 内建函数

内建函数由编译器提供，并以 `@` 为前缀。参数上的 `comptime` 关键字意味着该参数必须在编译期已知。

由于内建函数数量众多，本教程不进行系统讲解，仅在相关章节说明涉及到的内建函数。

更多内建函数的文档请参考[这里](https://ziglang.org/documentation/master/#Builtin-Functions)。

## 高阶使用

以下是一些更加高级的用法，可以之后再学习！

### 闭包

首先，我们来看维基百科对闭包的定义：

> 在计算机科学中，闭包（英语：Closure），又称词法闭包（Lexical Closure）或函数闭包（function closures），是在支持头等函数的编程语言中实现词法绑定的一种技术。
>
> 闭包在实现上是一个结构体，它存储了一个函数（通常是其入口地址）和一个关联的环境（相当于一个符号查找表）。
>
> 环境里是若干对符号和值的对应关系，它既要包括约束变量（该函数内部绑定的符号），也要包括自由变量（在函数外部定义但在函数内被引用），有些函数也可能没有自由变量。闭包跟函数最大的不同在于，当捕捉闭包的时候，它的自由变量会在捕捉时被确定，这样即便脱离了捕捉时的上下文，它也能照常运行。
>
> 捕捉时对于值的处理可以是值拷贝，也可以是名称引用，这通常由语言设计者决定，也可能由用户自行指定（如 C++）。

在 Zig 中，由于语言设计上的某些限制，我们无法像在某些其他语言中那样自由地使用闭包特性。

广义上讲，**闭包是指一个函数与其引用的词法作用域（lexical scope）形成的组合。简言之，闭包允许一个函数访问其外部作用域中的变量，即使这个函数在其外部作用域之外被调用。其主要特性是能够“记住”其创建时的环境。**

在许多支持内存垃圾回收（GC）的语言中，它们的使用大概是这样的：

```python
def outer_function():
    message = "Hello, World!"  # 外部函数的局部变量

    def inner_function():
        print(message)  # 内部函数访问外部函数的变量

    return inner_function  # 返回内部函数

# 创建闭包
closure = outer_function()

# 调用闭包
closure()  # 输出：Hello, World!
```

以上是一段 Python 代码。其中 `outer_function` 函数最终返回一个函数类型（实际上它返回了 `inner_function` 函数，但在解释执行时，它不再以 `inner_function` 的名称存在）。

Zig 语言不允许在函数内部声明函数，也不允许直接创建匿名函数。这两个特性在其他编程语言（例如 JavaScript、PowerQuery-M 等）中是实现闭包模式的常见方式。

因此，在 Zig 中实现闭包，通常需要其在编译期是已知的：

<<<@/code/release/function.zig#closure

函数 `bar` 返回一个 `fn (i32) i32` 类型的函数，并接收一个编译期参数。这使得该函数可以访问编译期传入的数据。需要注意的是，这里我们使用了匿名结构体方法。

关于闭包的更多内容可以参考以下文章或帖子：

- [Implementing Closures and Monads in Zig](https://zig.news/andrewgossage/implementing-closures-and-monads-in-zig-23kf)
- [Closure Pattern in Zig Zig](https://zig.news/houghtonap/closure-pattern-in-zig-19i3#zig-closure-pattern)

关于 Andrew Kelley 拒绝匿名函数提案的解释：

- [RFC: Make function definitions expressions](https://github.com/ziglang/zig/issues/1717#issuecomment-1627790251)

### `anytype`

函数参数可以用 `anytype` 代替类型来声明。在这种情况下，调用函数时将推断参数类型。使用 `@TypeOf` 和 `@typeInfo` 获取有关推断类型的信息。

<<<@/code/release/function.zig#addFortyTwo

### `noreturn`

`noreturn` 是一个特殊类型，表示函数不会返回。它通常用于以下情况：

- `break`
- `continue`
- `return`
- `unreachable`
- `while (true) {}`

当一个函数不会返回时，可以使用它来代替 `void`。

该类型常用于内核开发，因为内核本身通常是一个不会退出的程序。另一个使用场景是 `exit` 函数。

<<<@/code/release/function.zig#ExitProcess

### `export`

`export` 关键字确保函数在生成的目标文件 (object file) 中可见，并遵循 C ABI。

<<<@/code/release/function.zig#sub

### `extern`

`extern` 说明符用于声明一个将在链接时解析的函数（即该函数并非由 Zig 定义，而是由外部库定义，通常遵循 C ABI，但 C ABI 本身有多种规范）。链接可以是静态链接或动态链接。`extern` 关键字后面引号中的标识符指定了包含该函数的库（例如 `c` -> `libc.so`）。`callconv` 说明符用于更改函数的调用约定。

<<<@/code/release/function.zig#atan2

::: tip
`extern` 用于引用非 Zig 实现的库，而 `export` 则是 Zig 将函数对外暴露供其他语言使用！
:::

### `@setCold`

`@setCold(comptime is_cold: bool) void`

告诉优化器当前函数很少被调用（或不被调用）。该函数仅在函数作用域内有效。

<<<@/code/release/function.zig#abort

### `callconv`

`callconv` 关键字用于指定函数的调用约定，这在对外暴露函数或编写裸汇编时非常有用。

<<<@/code/release/function.zig#shiftLeftOne

关于可用的调用约定格式，请参考[`std.builtin.CallingConvention`](https://ziglang.org/documentation/master/std/#std.builtin.CallingConvention)。
