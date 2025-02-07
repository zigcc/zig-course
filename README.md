# Zig 语言圣经

> Zig is a general-purpose programming language and toolchain for maintaining robust, optimal and reusable software.
>
> Zig 是一种通用的编程语言和工具链，用于维护健壮、最优和可重用的软件

## 参与贡献

欢迎各位志同道合的“道友”参与贡献本文档，并一起壮大 zig 中文社区！

本仓库使用的文档工具是 vitepress，建议了解一下 [vitepress 的 markdown 扩展](https://vitepress.dev/zh/guide/markdown)。

贡献方法：

- fork 本文档仓库
- 创建一个新的分支，请勿直接使用主分支进行修改
- 发起 pull request
- 等待 review
- 合并到上游仓库，并由 github action 自动构建

```sh
bun i // 安装依赖
bun dev // 启动热更开发服务
bun format // 运行 prettier, zig fmt 和 autocorrect 格式化程序
bun run build // 构建产物
bun run preview // 运行预览
```

> [!NOTE]
> 请自行安装 `bun` （建议也安装 `autocorrect`，并且在提交前运行 `bun format`）

> [!NOTE]
> 本文档所使用的构建工具为 [bunjs](https://bun.sh/)，在提交时请勿将其他 nodejs 的包管理工具的额外配置文件添加到仓库中。

> 如需要更新依赖，请参照此处 [Lockfile](https://bun.sh/docs/install/lockfile) 先设置 git 使用 bun 来 diff 文件！
