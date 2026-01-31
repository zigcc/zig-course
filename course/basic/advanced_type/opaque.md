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

## 常见使用场景

### 与 C 语言互操作

`opaque` 类型最常见的用途是在与 C 代码交互时处理 **不透明指针**（opaque pointer）。当 C 库不公开结构体的内部细节时，Zig 可以使用 `opaque` 类型来安全地表示这些类型：

```zig
// 对应 C 中的 typedef struct FILE FILE;
const FILE = opaque {};
const c = @cImport(@cInclude("stdio.h"));

// 使用不透明指针
fn readFile(file: *FILE) void {
    // file 指向一个大小未知的结构体
    // 只能通过 C 函数来操作它
    _ = file;
}
```

### 类型擦除

使用 `*anyopaque` 可以实现类似 C 语言 `void*` 的类型擦除功能。这在需要存储任意类型指针的场景中很有用：

```zig
const Context = struct {
    data: *anyopaque,  // 可以指向任意类型
    callback: *const fn (*anyopaque) void,
};
```

::: info 🅿️ 提示
使用 `anyopaque` 时需要格外小心类型安全。在可能的情况下，优先考虑使用泛型或联合类型来保持类型信息。
:::
