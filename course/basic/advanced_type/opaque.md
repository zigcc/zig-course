---
outline: deep
---

# opaque

`opaque` 类型用于声明一个大小和对齐方式未知（但非零）的新类型。其内部可以像结构体、联合或枚举一样包含声明。

这通常用于与 C 代码交互时，确保类型安全，尤其是在 C 代码没有公开结构体细节的情况下。

<<<@/code/release/opaque.zig#opaque

## anyopaque

`anyopaque` 是一个特殊的类型，它可以代表任意一种 `opaque` 类型（因为每个 `opaque` 类型根据其内部声明的不同而被视为不同类型）。它常用于与 C 交互的函数中，类似于 C 的 `void*`，通常用于类型擦除的指针。

:::info 🅿️ 提示

需要注意的是，`void` 的大小为 0 字节，而 `anyopaque` 的大小未知但非零。

:::

TODO: 添加更多关于该类型使用的示例和说明！
