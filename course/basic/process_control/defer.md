---
outline: deep
---

# defer

`defer` 用于注册一个表达式（或代码块），使其在当前作用域结束时自动执行。这是 Zig 提供的一种**确定性资源管理**机制，功能上类似于 C++ 的 RAII（Resource Acquisition Is Initialization）或 Go 的 `defer`，用于确保资源（如内存、文件句柄、锁等）在离开作用域时得到正确释放。

## 执行顺序

如果存在多个 `defer`，它们将会按照**后进先出（LIFO）**的顺序执行——即最后注册的 `defer` 最先执行，类似栈的出栈顺序。

<<<@/code/release/defer.zig#Defer

## 使用细节

- `defer` 可以执行单个语句，也可以执行一个代码块（由 `{}` 包裹）。
- 如果控制流没有经过 `defer` 语句（例如在 `defer` 之前就 `return` 了），则该 `defer` 不会被注册，自然也不会执行。
- `defer` 中的表达式在**作用域退出时**才会被求值，而非在 `defer` 语句出现的位置求值。

## 典型用法

`defer` 最常见的用途是配合内存分配器使用，确保分配的内存在作用域正常结束时被释放：

```zig
const allocator = std.heap.page_allocator;
const data = try allocator.alloc(u8, 100);
defer allocator.free(data);
// 使用 data...
// 当作用域正常退出时，data 会被释放
```

:::warning ⚠️ 注意
`defer` 仅在作用域**正常退出**时执行。如果函数因返回错误而退出，已注册的 `defer` **不会执行**。如果需要在错误返回时执行清理操作，请使用 `errdefer`。

因此在实际的资源管理中，通常需要 `defer` 和 `errdefer` 搭配使用——`defer` 负责正常路径的清理，`errdefer` 负责错误路径的清理。
:::

## `errdefer`

对应 `defer` 的还有 `errdefer`，它仅在函数返回错误时才执行，具体见这里 [`errdefer`](/basic/error_handle#errdefer)。
