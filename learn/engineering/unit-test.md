---
outline: deep
---

# 单元测试

> 在计算机编程中，单元测试（英语：Unit Testing）又称为模块测试来源请求，是针对程序模块（软件设计的最小单位）来进行正确性检验的测试工作。程序单元是应用的最小可测试部件。

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