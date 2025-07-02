# Zig 语言圣经

[![autocorrect](https://github.com/zigcc/zig-course/actions/workflows/autocorrect.yml/badge.svg)](https://github.com/zigcc/zig-course/actions/workflows/autocorrect.yml)
[![build](https://github.com/zigcc/zig-course/actions/workflows/build.yml/badge.svg)](https://github.com/zigcc/zig-course/actions/workflows/build.yml)
[![check](https://github.com/zigcc/zig-course/actions/workflows/check.yml/badge.svg)](https://github.com/zigcc/zig-course/actions/workflows/check.yml)
[![deploy](https://github.com/zigcc/zig-course/actions/workflows/deploy.yml/badge.svg)](https://github.com/zigcc/zig-course/actions/workflows/deploy.yml)
[![pdf](https://github.com/zigcc/zig-course/actions/workflows/pdf.yml/badge.svg)](https://github.com/zigcc/zig-course/actions/workflows/pdf.yml)

> Zig is a general-purpose programming language and toolchain for maintaining robust, optimal and reusable software.
>
> Zig 是一种通用的编程语言和工具链，用于维护健壮、最优和可重用的软件

![Cover Image](./course/public/cover_image.png "Cover Image")

**Zig 语言圣经** 是一份开源的 Zig 语言综合教程，旨在为中文 Zig 爱好者提供一份高质量的学习资源，内容涵盖从基础语法到高级特性的方方面面。

## ✨ 内容特色

本教程覆盖了 Zig 学习和实践中的多个重要领域：

- **环境配置**: 指导如何安装和配置 Zig 开发环境。
- **基础入门**: 包括变量、类型、流程控制、错误处理等基础知识。
- **高级主题**: 深入探讨 `comptime`、异步、内存管理、C 语言交互等高级特性。
- **工程实践**: 涵盖构建系统、包管理、单元测试和代码风格指南。
- **版本示例**: 提供与 Zig 不同版本相对应的代码示例。

## 🚀 如何阅读

本项目使用 VitePress 构建。您可以直接在本地启动开发服务器以阅读最新内容：

```sh
bun i # 安装依赖
bun dev # 启动热更开发服务
```

## 🤝 参与贡献

欢迎各位志同道合的“道友”参与贡献本文档，并一起壮大 zig 中文社区！

贡献方法：

- Fork 本文档仓库
- 创建一个新的分支，请勿直接使用主分支进行修改
- 发起 Pull Request
- 等待 Review
- 合并到上游仓库，并由 GitHub Action 自动构建

**开发命令：**

```sh
bun i # 安装依赖
bun dev # 启动热更开发服务
bun format # 运行 prettier, zig fmt 和 autocorrect 格式化程序
bun run build # 构建产物
bun run preview # 运行预览
```

> [!NOTE]
> 请自行安装 `bun` （建议也安装 `autocorrect`，并且在提交前运行 `bun format`）

> [!NOTE]
> 本文档所使用的构建工具为 [bunjs](https://bun.sh/)，在提交时请勿将其他 nodejs 的包管理工具的额外配置文件添加到仓库中。

> 如需要更新依赖，请参照此处 [Lockfile](https://bun.sh/docs/install/lockfile) 先设置 git 使用 bun 来 diff 文件！
