---
outline: deep
---

# 单元测试

> 在计算机编程中，单元测试（英语：Unit Testing）又称为模块测试来源请求，是针对程序模块（软件设计的最小单位）来进行正确性检验的测试工作。程序单元是应用的最小可测试部件。

## 基本使用

在 zig 中，单元测试的是实现非常简单，只需要使用 `test` 关键字 + 字符串（测试名字，一般填测试的用途）+ 块即可。

```zig
const std = @import("std");

test "expect addOne adds one to 41" {

    // 标准库提供了不少有用的函数
    // testing 下的函数均是测试使用的
    // expect 会假定其参数为 true，如果不通过则报告错误
    // try 用于当 expect 返回错误时，直接返回，并通知测试运行器测试结果未通过
    try std.testing.expect(addOne(41) == 42);
}

test addOne {
    // test 的名字也可以使用标识符，例如我们在这里使用的就是函数名字 addOne
    try std.testing.expect(addOne(41) == 42);
}

/// 定义一个函数效果是给传入的参数执行加一操作
fn addOne(number: i32) i32 {
    return number + 1;
}
```

假设以上这段代码在文件 `testing_introduction.zig` 中，则我们可以这样子来执行检测：

```shell
$ zig test testing_introduction.zig
1/2 test.expect addOne adds one to 41... OK
2/2 decltest.addOne... OK
All 2 tests passed.
```

我们通过 `zig test` 这个命令来执行单个文件的 test，它默认会使用标准库提供的“测试器”，源码位于 `lib/test_runner.zig`。

::: info 🅿️ 提示

当测试名字是一个标识符时，将会输出类似 `decltest.addOne...` 这种信息，开头将会是 decltest。

事实上，测试块具有隐式的返回值类型 `anyerror!void`，并且测试在正常构建时会被忽略。

当测试失败时，zig 会将错误堆栈跟踪输出到标准错误输出，并在所有测试运行后将报告失败数目。

:::

## 嵌套测试

`zig test` 执行时会仅执行文件内的顶级测试块，如果想执行非顶级的测试块，则可以定义一个名字为空的定义测试块，在其内部引用你需要执行测试的容器即可。

```zig
const std = @import("std");
const expect = std.testing.expect;

test {
    std.testing.refAllDecls(S);
    _ = S;
    - = U;
}

const S = struct {
    test "S demo test" {
        try expect(true);
    }

    const SE = enum {
        V,

        // 此处测试由于未被引用，将不会执行.
        test "This Test Won't Run" {
            try expect(false);
        }
    };
};

const U = union { // U 被顶层测试块引用了
    s: US,        // 并且US在此处被引用，则US容器中的测试块也会被执行测试

    const US = struct {
        test "U.US demo test" {
            // This test is a top-level test declaration for the struct.
            // The struct is nested (declared) inside of a union.
            try expect(true);
        }
    };

    test "U demo test" {
        try expect(true);
    }
};
```

值得注意的是，嵌套引用测试在全局测试块中引用另一个容器后，并不会递归，也就是说它仅仅会执行容器的顶层测试块和它引用的容器的顶层测试块。

zig 的标准库还为我们提供了一个函数 `std.testing.refAllDecls`，专门处理上面这种语法（ `_=...` 这种语法看起来并不好看）。

## 跳过测试

跳过测试的一种方法是使用 `zig test` 命令行参数 `--test-filter [text]` 将其过滤掉。这使得测试构建仅包含名称包含提供的过滤器文本的测试。请注意，即使使用 `--test-filter [text]` 命令行参数，也会运行非命名测试（名字为空的测试块）。

要以编程方式跳过测试，请使测试返回错误 `error.SkipZigTest` 并且默认测试运行程序将认为该测试被跳过。所有测试运行后，将报告跳过的测试总数。

## 检测内存泄漏

在测试中，我们可以使用 `std.testing.allocator` 这个内存分配器来检测内存泄漏，默认测试器将报告使用该分配器发现的任何内存泄漏。

## 检查测试模式

我们可以通过 `@import("builtin").is_test` 来查看当前是否运行在测试器下。
