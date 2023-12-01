---
outline: deep
---

# 包管理

随着 `0.11` 的发布，zig 终于迎来了一个正式的官方包管理器，此前已知是通过第三方包管理器下载并处理包。

zig 当前并没有一个中心化存储库，包可以来自任何来源，无论是本地还是网络上。

## 新的文件结构

`build.zig.zon` 这个文件存储了包的信息，它是 zig 新引入的一种简单数据交换格式，使用了 zig 的匿名结构和数组初始化语法。

```zig
.{
    .name = "my_package_name",
    .version = "0.1.0",
    .dependencies = .{
        .dep_name = .{
            .url = "https://link.to/dependency.tar.gz",
            .hash = "12200f41f9804eb9abff259c5d0d84f27caa0a25e0f72451a0243a806c8f94fdc433",
        },
    },
    // 这里的 paths 字段是当前 nightly 版本新引入的
    // 它用于显式声明包含的源文件，如果包含全部则指定为空
    .paths = .{
        "",
    },
}
```

以上字段含义为：

- `name`：当前你所开发的包的名字
- `version`：包的版本，使用[Semantic Version](https://semver.org/)。
- `dependencies`：依赖项，内部是一连串的匿名结构体，字段 `dep_name` 是依赖包的名字，`url` 是源代码地址，`hash` 是对应的hash（源文件内容的hash）
- `paths`：显式声明包含的源文件，包含所有则指定为空，当前仅 `nightly` 可用。

目前为止，`0.11` 版本支持两种打包格式的源文件：`tar.gz` 和 `tar.xz`。

## 包对外暴露模块

每个作为依赖的包都可以对外暴露模块，使用 `std.Build.addModule` 实现，通过该函数暴露的模块是完全公开的，如果需要使用私有的模块，请使用 `std.Build.createModule`。关于二进制构建结果（例如动态链接库），任何会被执行 `install` 的构建均会被暴露出去。

## 引入依赖项

在 `build.zig` 中，可以使用 `std.Build.dependency` 函数引入依赖项，它使用在 `.zon` 中的依赖项名字并返回一个 `*std.Build.Dependency`，返回的结果可以使用 `artifact` 和 `module` 方法来访问依赖项的构建结果和暴漏的模块。

如果需要引入本地具有 `build.zig` 的依赖项，可以使用 `std.Build.anonymousDependency`， 它会将依赖项的包构建根目录和通过 `@import` 导入的依赖项的 `build.zig` 作为参数。

`dependency` 和 `anonymousDependency` 都包含一个额外的参数 `args`，这是传给对应的依赖项构建的参数（类似在命令行构建时使用的 `-D` 参数，通过 `std.Build.option` 实现），当前包的参数并不会向依赖项传递，需要手动显式指定转发。

TODO：更多的示例说明，当前的包管理讲解并不清楚！
