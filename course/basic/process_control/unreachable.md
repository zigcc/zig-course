---
outline: deep
---

# unreachable

在 `Debug` 和 `ReleaseSafe` 模式下，`unreachable` 会调用 `panic` ，并显示消息达到 unreachable code。

在 `ReleaseFast` 和 `ReleaseSmall` 模式下，编译器假设永远不会执行到 `unreachable` 来对代码进行优化。

<<<@/code/release/unreachable.zig#unreachable
