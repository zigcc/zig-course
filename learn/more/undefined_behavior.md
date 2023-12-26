---
outline: deep
---

# 未定义操作

zig 本身有许多未定义行为，它们可以很方便地帮助开发者找出错误。

如果在编译期就检测到了未定义的行为，那么 zig 会发出编译错误并停止继续编译，大多数编译时无法检测到的未定义行为均会在运行时被检测到。这就是 zig 的安全检查！

安全检查会在debug、ReleaseSafe 模式下开启，但可以使用 [`@setRuntimeSafety`](https://ziglang.org/documentation/master/#setRuntimeSafety) 来强制指定在单独的块中是否开启安全检查（这将忽略构建模式）。

当出现安全检查失败时，zig 会编译失败并触发堆栈跟踪：

```zig
test "safety check" {
    unreachable;
}
```

```sh
$ zig test test_undefined_behavior.zig
1/1 test.safety check... thread 892159 panic: reached unreachable code
/home/ci/actions-runner/_work/zig-bootstrap/zig/docgen_tmp/test_undefined_behavior.zig:2:5: 0x222c65 in test.safety check (test)
    unreachable;
    ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/test_runner.zig:181:28: 0x22da7d in mainTerminal (test)
        } else test_fn.func();
                           ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/test_runner.zig:36:28: 0x223c8a in main (test)
        return mainTerminal();
                           ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:575:22: 0x22319c in posixCallMainAndExit (test)
            root.main();
                     ^
/home/ci/actions-runner/_work/zig-bootstrap/out/host/lib/zig/std/start.zig:253:5: 0x222cf1 in _start (test)
    asm volatile (switch (native_arch) {
    ^
???:?:?: 0x0 in ??? (???)
error: the following test command crashed:
/home/ci/actions-runner/_work/zig-bootstrap/out/zig-local-cache/o/4558e134302b78f1a543202d094b3e06/test
```

以下说明各种未定义行为。

## 不可达代码

即 `unreachabel`，如果程序执行到它，那么会触发完整的堆栈跟踪！

## 索引越界访问

无论是数组还是切片，发生越界访问会发生错误导致程序终止进而触发堆栈跟踪！

## 负数转换为无符号整数

这本身就是非法行为，故会直接出现报错，如果仅仅是想要将负数当作无符号整数看待，可以使用 [`@bitCast`](https://ziglang.org/documentation/master/#bitCast)。

如果想要获取到无符号整数的最大值，可以使用 `std.math.maxInt`。

## 数据截断

注意我们这里指的是数据类型的范围变小了，不足以容纳数据的值，例如：

```zig
const spartan_count: u16 = 300;
const byte: u8 = @intCast(spartan_count);
```

上面这段代码毫无疑问会失败，因为 `u8` 类型无法容纳下 300 这个数。

除非，我们显示强制截断位，使用 [`@truncate`](https://ziglang.org/documentation/master/#truncate)。

## 整数溢出

常规的运算可能导致溢出，如加 `+` 减 `-` 乘 `*` 除 `/` 取反 `-`


## 移位溢出

## 除零操作

## 精确触发溢出

## 尝试解开 Null

## 尝试解开 Error

## 无效错误码

## 无效枚举转换

## 无效错误集合转换

## 指针对齐错误

## 联合类型字段访问错误

## 浮点转换整数发生越界

## 指针强制转换为 Null