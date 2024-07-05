---
outline: deep
---

# 错误处理

程序会在某些时候因为某些已知或未知的原因出错，有的可以正确处理，有的则很棘手，但我们可以捕获它们并有效地报告给用户。

:::info 🅿️ 提示

事实上，目前 zig 的错误处理方案笔者认为是比较简陋的，在 zig 中错误类型很像 `enum`，这导致错误类型无法携带有效的 `payload`，你只能通过 error 的 tagName 来获取有效的信息。

:::

## 基本使用

以下展示了 error 的基本定义和使用：

<<<@/code/release/error_handle.zig#BasicUse

以上代码使用 `error` 关键字定义了两个错误类型，分别是：`FileOpenError` 和 `AllocationError`，这两个类型实现了几种错误的定义。

注意，我们可以定义多个重复的错误的 `tagName`，它们均会分配一个大于 0 的值，多个重复的错误的 `tagName` 的值是相同的，同时 `error` 还支持将错误从子集转换到超集，这里就是将子集 `AllocationError` 通过函数 `foo` 转换到超集 `FileOpenError`。

:::info 🅿️ 提示

在编译时，zig 编译器会做一个额外的工作，那就是确定错误的数量，从 `0.12`开始，默认使用 `u16`，但在编译时如果传入参数 `--error-limit [num]`，则使用恰好可以表示所有错误值的最少位数的整数类型。

:::

## 只有一个值的错误集

如果你打算定义一个只有一个值的错误集，我们这时再使用以上的定义方法未免过于啰嗦，zig 提供了一种简短方式来定义：

<<<@/code/release/error_handle.zig#JustOneError1

以上这行代码相当于：

<<<@/code/release/error_handle.zig#JustOneError2

以上代码定义了一个只有一个错误的匿名集合（编译器会自动分配名字），并使用这个错误。

## 全局错误集

`anyerror` 指的是全局的错误集合，它包含编译单元中的所有错误集，即超集不是子集。

你可以将所有的错误强制转换到 `anyerror`，也可以将 `anyerror` 转换到所有错误集，并在转换时增加一个语言级断言（language-level assert）保证错误一定是目标错误集的值。

::: warning ⚠️ 警告

应尽量避免使用 `anyerror`，它相当于放大了错误的范围，因为它会阻止编译器在编译期就检测出可能存在的错误，增加代码出错 debug 的负担。

:::

## 错误联合类型

> [!TIP]
> ！！！以上所说的错误类型实际上用的大概不多，但错误联合类型大概是经常使用的。

只需要在普通类型的前面增加一个 `!` 就是代表这个类型变成错误联合类型，我们来看一个比较简单的函数：

以下是一个将英文字符串解析为数字的示例：

> [!NOTE]
> 这里代码看不懂没关系，此处代码仅仅用于演示一下联合类型的使用。

<<<@/code/release/error_handle.zig#ConvertEnglishToInteger

注意函数的返回值：`!u64`，这意味函数返回的是一个 `u64` 或者是一个 `error`，错误集在这里被保留在 `!` 左侧，因此该错误集是可以被编译器自动推导的。

事实上，函数无论是返回 `u64` 还是返回 `error`，均会被转换为 `anyerror!u64`。

该函数的具体效果取决于我们如何对待返回的 `error`:

1. 返回错误时我们准备一个默认值
2. 返回错误时我们想将它向上传递
3. 确信本次函数执行后肯定不会发生错误，想要无条件的解构它
4. 针对返回错误集中不同的错误采取不同的处理方式

### `catch`

`catch` 用于发生错误时提供一个默认值，来看一个例子：

<<<@/code/release/error_handle.zig#CatchBasic

`number` 必定是一个类型为 `u64` 的值，当发生错误时，会提供默认值 13 给 `number`。

:::info 🅿️ 提示

`catch` 运算符右侧必须是一个与其左侧函数返回的错误联合类型展开后的类型(也就是除了错误类型外的类型)一致，或者是一个 `noreturn`(例如 `panic`) 的语句。

:::

当然进阶点我们还可以和命名块（named Blocks）功能结合起来，以此来提供进入 `catch` 后执行某些复杂操作以返回值：

<<<@/code/release/error_handle.zig#CatchAdvanced

### try

`try` 用于在出现错误时直接向上层返回错误，没错误就正常执行：

> [!TIP]
> 当然，try 也可以等价使用 catch 实现！

::: code-group

<<<@/code/release/error_handle.zig#TryBasic1 [try]

<<<@/code/release/error_handle.zig#TryBasic2 [catch]

:::

`try` 会尝试评估联合类型表达式，如果是错误则直接从当前函数返回，否则解构它。

::: info 🅿️ 提示

那么如何假定函数不会返回错误呢？

使用 `unreachable`，这会告诉编译器此次函数执行不会返回错误，`unreachable` 在 `Debug` 和 `ReleaseSafe` 模式下会产生恐慌，在 `ReleaseFast` 和 `ReleaseSmall` 模式下会产生未定义的行为。所以当调试应用程序时，如果函数执行到了这里，那就会发生 `panic`。

<<<@/code/release/error_handle.zig#AssertNoError

:::

::: details 细粒度处理错误

有时需要对错误进行细粒度处理，只需将 `if` 和 `switch` 联合起来：

<<<@/code/release/error_handle.zig#PreciseErrorHandle

:::

::: details 不处理错误

如果不想处理错误怎么办呢？

直接在捕获错误的地方使用 `_` 来通知编译器忽略它即可。

<<<@/code/release/error_handle.zig#NotHandleError

:::

### errdefer

`errdefer` 可以看作是 `defer` 的一个特殊变体，它用于处理错误，仅在函数作用域返回错误时，才会执行 `errdefer`。

还可以使用捕获语法来捕获错误，这对于在清理期间打印错误信息很有用。

<<<@/code/release/error_handle.zig#DeferErrorCapture

::: details `defer` 和 `errdefer`结合使用

<<<@/code/release/error_handle.zig#DeferErrDefer

这样做的好处是，可以获得强大的错误处理能力，而无需尝试确保覆盖每个退出路径的冗长和认知开销。释放代码始终紧跟在分配代码之后。

:::

::: warning

关于 `defer` 和 `errdefer`，需要注意的是如果他们在 `for` 循环的作用域中，那么它们会在 `for` 循环结束前执行 `defer` 和 `errdefer`，在使用该特性时需要谨慎对待。

:::

### 合并和推断错误

你可以通过使用 `||` 运算符将两个错误合并到一起，注意，文档注释会优先使用运算符左侧的注释。

推断错误集，事实上我们使用的 `!T` 就是推断错误集，我们并未显式声明返回的错误，返回的错误类型将会由 zig 编译器自行推导而出，这是一个很好的特性，但有时也会给我们带来困扰。

<<<@/code/release/error_handle.zig#ReferError

::: info 🅿️ 提示

> _当函数返回自动推导的错误集时，相对的这个函数会变成一个类泛型函数（因为这需要编译器在编译时进行推导），因此在执行某些操作时会变得有些不方便，例如获取函数指针或者在不同构建目标之间保持相同的错误集合。另外，推导错误和递归并不兼容。_

上面这句话看起来有点云里雾里，我们来两个例子来说明就可以：

1. 不同构建目标之间可能存在着专属于架构的错误定义，这使得在不同架构上构建出来的代码的实际错误集并不相同，函数也同理（与cpu指令集实现有关）。
2. 当我们使用自动推导时，推导出的错误集是最小错误集，故可能一个函数被推导出 `ErrorSetOne!type` 和 `ErrorSetTwo!type` 两个错误集，这就使得在递归上出现了不兼容，不过可以使用 `switch` 来匹配错误集来解决该问题。

对于上面的问题，其实更好的解决办法就是显式声明一个错误集，这会明确告诉编译器返回的错误种类都有什么。

> _根据文档说明，上面的这些限制可能在未来会被改善。_

:::

## 堆栈跟踪

zig 本身有着良好的错误堆栈跟踪，错误堆栈跟踪显示代码中将错误返回到调用函数的所有点。这使得在任何地方使用 `try` 都很实用，并且如果错误最终从应用程序中一直冒出来，我们很容易能够知道发生了什么。

> [!WARNING]
> 但需要注意的是，当链接 libc 时，堆栈跟踪不一定是完整的，因为 zig 有时会无法跟踪链接库的堆栈，这点在 windows 平台尤为明显，因为 windows 平台有很多私有的库。

具体的信息可见 _[这里](https://ziglang.org/documentation/master/#Error-Return-Traces)_。

完整堆栈跟踪生效的几个方式：

- 从 `main` 返回一个错误
- 使用 `catch unreachable` 捕获的错误（并且没有覆盖默认的 `panic` 处理函数）
- 使用 `@errorReturnTrace` 来访问当前的函数 trace。

具体的堆栈跟踪实现细节可以看 _[这里](https://ziglang.org/documentation/master/#Implementation-Details)_。
