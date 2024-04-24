---
outline: deep
---

# opaque

`opaque` 类型声明一个具有未知（但非零）大小和对齐方式的新类型，它的内部可以包含与结构、联合和枚举相同的声明。

这通常用于保证与不公开结构详细信息的 C 代码交互时的类型安全。

<<<@/code/release/opaque.zig#opaque

## anyopaque

`anyopaque` 是一个比较特殊的类型，代表可以接受任何类型的 `opaque`（由于 `opaque` 拥有不同的变量/常量声明和方法的定义，故是不同的类型），常用于与 C 交互的函数中，相当于是 C 的 `void` 类型！

TODO: 添加更多关于该类型使用的示例和说明！
