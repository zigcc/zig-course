---
outline: deep
---

# 风格指南

::: info 🅿️ 提示

此风格指南来自官方的 [英文参考文档](https://ziglang.org/documentation/master/#Style-Guide)！

:::

本风格指南并不是强制性的，仅作为一份参考！

## 空白

- 采用四空格缩进
- 尽量在同一行打开大括号，除非需要换行
- 如果一个变量（常量）包含的元素数量超过 2，请将每个元素放在单独的行上，并养成在最后一个元素后添加 `,` 的习惯，这有助于格式化。

## 命名

简单来说，使用 **驼峰命名法**、**TitleCase 命名法**、**蛇形命名法**

- 类型声明使用 _TitleCase 命名法_（除非是一个 0 字段的 `struct`，此时它被视为一个命名空间，应使用 _蛇形命名法_）
- 如果 `x` 是可以被调用的，并且它返回一个类型，那么使用 _TitleCase 命名法_
- 如果 `x` 是可被调用，并且返回非类型，应使用 _驼峰命名法_
- 其他情况下，应该使用 _蛇形命名法_

> 首字母缩略词、首字母缩写词、专有名词或任何其他在书面英语中具有大写规则的单词与任何其他单词一样，都受命名约定的约束。即使是只有 2 个字母的首字母缩略词也受这些约定的约束。

文件名分为两类：类型和命名空间，如果文件具有字段，则它应该使用 _TitleCase 命名法_，否则应使用 _蛇形命名法_，目录名称也应使用 _蛇形命名法_

以上的约束是在一般情况下，如果已经有了内部约定，请使用内部约定！

以下是一个示例：

```zig
// 命名空间，使用蛇形命名法
const namespace_name = @import("dir_name/file_name.zig");
// 类型声明，使用 TitleCase 命名法
const TypeName = @import("dir_name/TypeName.zig");
// 其他情况，蛇形命名法
var global_var: i32 = undefined;
// 其他情况，蛇形命名法
const const_name = 42;
// 其他情况，蛇形命名法
const primitive_type_alias = f32;
// 其他情况，蛇形命名法
const string_alias = []u8;

// 类型声明，使用 TitleCase 命名法
const StructName = struct {
    field: i32,
};
// 类型声明，使用 TitleCase 命名法
const StructAlias = StructName;

// 可被调用，且返回非类型，使用驼峰命名法
fn functionName(param_name: TypeName) void {
    var functionPointer = functionName;
    functionPointer();
    functionPointer = otherFunction;
    functionPointer();
}

// 可被调用，且返回非类型，使用驼峰命名法
const functionAlias = functionName;

// 可被调用，且返回类型，使用 TitleCase 命名法
fn ListTemplateFunction(
    comptime ChildType: type,
    comptime fixed_size: usize,
) type {
    return List(ChildType, fixed_size);
}

// 可被调用，且返回类型，使用 TitleCase 命名法
fn ShortList(comptime T: type, comptime n: usize) type {
    return struct {
        field_name: [n]T,
        fn methodName() void {}
    };
}

// 其他情况，蛇形命名法
const xml_document =
    \\<?xml version="1.0" encoding="UTF-8"?>
    \\<document>
    \\</document>
;

// 类型声明，使用 TitleCase 命名法
const XmlParser = struct {
    field: i32,
};

// 可被调用，且返回非类型，使用驼峰命名法
fn readU32Be() u32 {}
```

## 文档注释指南

- 根据名称省略冗余信息，即当可以立即从命名推断出其用途时，无需注释其用途
- 鼓励将注释信息复制到多个类似的函数上，这有助于 IDE 或者其他工具提供更好的帮助说明
- 对不变量使用 **假设** 来表示当违反事先预定情况时会发生未定义行为
- 使用 **断言** 表示当违反预定情况时会触发安全检查的未定义行为
