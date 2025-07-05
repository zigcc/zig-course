---
outline: deep
---

# 编辑器选择

> **_工欲善其事，必先利其器！_**

## VS Code

官网地址：[https://code.visualstudio.com/](https://code.visualstudio.com/)

> Visual Studio Code 是一款由微软开发且跨平台的免费源代码编辑器。该软件通过扩展支持语法高亮、代码自动补全、代码重构等功能，并内置了命令行工具和 Git 版本控制系统。用户可以更改主题和键盘快捷方式实现个性化设置，也可以通过内置的扩展程序商店安装其他扩展以拓展软件功能。

作为目前最轻量且生态最丰富的编辑器之一，由微软出品。Zig 官方为其开发了 [`Zig Language`](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig) 插件，安装即可使用。初次使用时，插件会推荐安装 language server，确认即可。

![vscode-zig](/picture/basic/vscode-zig.png){data-zoomable}

## Zed

官网地址：[`https://zed.dev/`](https://zed.dev/)

> ZED 是一款新一代代码编辑器，旨在通过 AI 提升开发效率。

这款近年来备受关注的编辑器使用 Rust 编写，拥有不错的颜值和插件系统。它还引入了 Zed AI 体系，可以接入各种 AI 模型，提供更高效的编码体验。

Zig 扩展安装方式：在主界面按下 `Ctrl + Shift + P`，在弹出的命令栏中输入 `extension`，选择 `zed: extensions`，然后搜索 `zig` 并点击右侧的 `Install` 即可完成安装。

![zed-zig](/picture/basic/zed-zig.png){data-zoomable}

## Vim / Neovim

Vim：[https://github.com/vim/vim](https://github.com/vim/vim)

Neovim：[https://github.com/neovim/neovim](https://github.com/neovim/neovim)

历史悠久的编辑器，被誉为“编辑器之神”。

推荐安装由官方维护的 [zig.vim](https://github.com/ziglang/zig.vim) 插件，它提供了基础的语法解析功能。

::: details zig.vim 配置小细节

建议关闭 vim / neovim 保存时自动格式化的功能（默认开启）：

```sh
# for vim
let g:zig_fmt_autosave = 0

# for neovim lua
vim.g.zig_fmt_autosave = false
```

:::

如果使用 Neovim 内置的 LSP（大多数用户的选择），推荐使用 [zig-lamp](https://github.com/jinzhongjia/zig-lamp) 插件。该插件支持自动安装和配置 zls，并提供了可视化管理 `build.zig.zon` 文件的功能。

如果使用 `coc.nvim` 作为 language server，则推荐 [**coc-zig**](https://github.com/UltiRequiem/coc-zig) 插件，它会自动下载并配置好最新的 zls。

![nvim-zig](/picture/basic/nvim-zig.png)

## Emacs

如果说 Vim 是“编辑器之神”，那么 Emacs 就是“神的编辑器”。

Zig 官方维护了 Emacs 的 [zig-mode](https://github.com/ziglang/zig-mode) 插件，参照其说明页面配置即可。

推荐使用 Emacs 28 新引入的 [eglot](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html) 作为 LSP 客户端。

![emacs-zig](/picture/basic/emacs-zig.png){data-zoomable}

## VS

官网地址：[https://visualstudio.microsoft.com/](https://visualstudio.microsoft.com/)

> Microsoft Visual Studio 是微软公司的开发工具包系列产品。VS 是一个基本完整的开发工具集，它包括了整个软件生命周期中所需要的大部分工具，如 UML 工具、代码管控工具、集成开发环境等等。

Windows 上最强大的 IDE 之一，可以通过第三方插件 [ZigVS](https://marketplace.visualstudio.com/items?itemName=LuckystarStudio.ZigVS) 提供 Zig 支持。

## CLion

> CLion 是一款专为开发 C 及 C++ 所设计的跨平台 IDE。它是以 IntelliJ 为基础设计的，包含了许多智能功能来提高开发人员的生产力。CLion 帮助开发人员使用智能编辑器来提高代码质量、自动代码重构并且深度整合 CMake 编译系统，从而提高开发人员的工作效率。

CLion 最初是为 C/C++ 开发设计的 IDE，但通过安装插件，现在也可以作为强大的 Zig IDE 使用。

目前插件市场有两个活跃的 Zig 插件（均为第三方作者维护）：[ZigBrains](https://plugins.jetbrains.com/plugin/22456-zigbrains) 和 [Zig Support](https://plugins.jetbrains.com/plugin/18062-zig-support)。两者均支持 Zig 的 `latest release` 版本。

## Sublime Text

经典的编辑器，其 Zig 插件 [sublime-zig-language](https://github.com/ziglang/sublime-zig-language) 由官方维护，安装即可使用。

::: danger ⛔ 危险
值得注意的是，该插件已超过两年未获更新，可能无法支持最新的 Zig 功能。
:::

## zls 体验优化

zls 已支持保存时自动检查代码的功能，但此功能默认关闭。

只需在 zls 的配置文件（可通过 `zls --show-config-path` 命令找到路径）中加入以下内容即可开启：

```json
{
  "enable_build_on_save": true,
  "build_on_save_step": "check"
}
```

同时，对应项目的 `build.zig` 也需要进行如下调整：

```zig
const exe_check = b.addExecutable(.{
    .name = "foo",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});

const check = b.step("check", "Check if foo compiles");
check.dependOn(&exe_check.step);
```

这意味着编译器在编译时会添加 `-fno-emit-bin` 标志，Zig 将只分析代码而不会调用 LLVM 后端，因此不会生成任何可执行文件。

需要注意的是，zls 的此项设置是全局性的。这意味着你需要为所有希望使用此功能的项目添加上述 `build.zig` 配置，否则诊断功能将无法在这些项目中生效。

更多资料：

- [Improving Your Zig Language Server Experience](https://kristoff.it/blog/improving-your-zls-experience/)
- [Local ZLS config per project](https://github.com/zigtools/zls/issues/1687) （了解如何为单个项目配置 zls）
