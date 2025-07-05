---
outline: deep
---

# `unreachable` 关键字

在 `Debug` 和 `ReleaseSafe` 模式下，`unreachable` 会触发 `panic`，并报告“不可达代码”错误。

在 `ReleaseFast` 和 `ReleaseSmall` 模式下，编译器会假定永远不会执行到 `unreachable` 处，从而对代码进行优化。

<<<@/code/release/unreachable.zig#unreachable
