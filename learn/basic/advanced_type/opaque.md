---
outline: deep
---

# opaque

`opaque {}` 类型声明一个具有未知（但非零）大小和对齐方式的新类型，它的内部可以包含与结构、联合和枚举相同的声明。

这通常用于与不公开结构详细信息的 C 代码交互时的类型安全。

```zig
const Derp = opaque {};
const Wat = opaque {};

extern fn bar(d: *Derp) void;
fn foo(w: *Wat) callconv(.C) void {
    bar(w);
}
```

TODO: 添加更多关于该类型使用的示例和说明！
