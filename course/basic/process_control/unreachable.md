---
outline: deep
---

# `unreachable` 关键字

`unreachable` 用于标记程序中**理论上不可能到达的代码路径**。它在 Zig 的类型系统中对应 `noreturn` 类型——这是一种**底类型（Bottom Type）**，表示该表达式永远不会产生值。

## 构建模式下的行为

- 在 `Debug` 和 `ReleaseSafe` 模式下，`unreachable` 会触发 `panic`，并报告"不可达代码"错误，帮助开发者发现逻辑漏洞。
- 在 `ReleaseFast` 和 `ReleaseSmall` 模式下，编译器会**假定**永远不会执行到 `unreachable` 处，从而对代码进行优化（例如消除死代码分支）。如果程序实际运行到此处，则是未定义行为。

## 使用场景

`unreachable` 通常用于以下场景：

1. **`switch` 语句中排除不可能的分支**：当你确定某些情况不会发生时。
2. **类型转换中的断言**：如 `@intCast` 等操作中，编译器在某些模式下会插入 `unreachable` 来检测非法值。
3. **配合 `noreturn` 函数**：标记在调用永不返回的函数（如 `@panic`、无限循环）之后的代码。

<<<@/code/release/unreachable.zig#unreachable
