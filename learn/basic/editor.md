---
outline: deep
---

# 编辑器选择

目前有以下几种编辑器推荐：

## VS Code

官网地址：[https://code.visualstudio.com/](https://code.visualstudio.com/)

> Visual Studio Code是一款由微软开发且跨平台的免费源代码编辑器。该软件以扩展的方式支持语法高亮、代码自动补全、代码重构功能，并且内置了命令行工具和Git 版本控制系统。用户可以更改主题和键盘快捷方式实现个性化设置，也可以通过内置的扩展程序商店安装其他扩展以拓展软件功能。

目前最轻量且生态丰富的编辑器，微软出品，zig 官方为其开发了插件，仅需要安装 [`Zig Language`](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig)这个插件即可，在初次初始化时会推荐安装 _language server_， 确认即可！

![vscode-zig](/picture/basic/vscode-zig.png){data-zoomable}

## Cloin

> Clion 是一款专为开发C及C++所设计的跨平台IDE。它是以IntelliJ为基础设计的，包含了许多智能功能来提高开发人员的生产力。CLion帮助开发人员使用智能编辑器来提高代码质量、自动代码重构并且深度整合CMake编译系统，从而提高开发人员的工作效率。

原本 Clion 仅仅是 C/C++ 的开发IDE，但在安装插件后可以作为 zig 的 IDE 使用。

目前插件市场活跃的两个 zig 插件（均为第三方作者维护）分别是 [ZigBrains](https://plugins.jetbrains.com/plugin/22456-zigbrains) 和 [Zig Support](https://plugins.jetbrains.com/plugin/18062-zig-support)，均支持 zig 的 `0.11.0` 版本。

## Vim / Neovim

Vim：[https://github.com/vim/vim](https://github.com/vim/vim)

Neovim：[https://github.com/neovim/neovim](https://github.com/neovim/neovim)

古老的编辑器之一，被誉为“编辑器之神”！

推荐安装插件 [zig.vim](https://github.com/ziglang/zig.vim)，由官方维护。

::: details

推荐关闭 vim / neovim 的保存自动格式化功能（默认开始）：

```sh
# for vim
let g:zig_fmt_autosave = 0

# for neovim lua
vim.g.zig_fmt_autosave = false
```

:::

如果使用`coc.nvim`作为 _language server_，则推荐使用 [**coc-zls**](https://github.com/xiyaowong/coc-zls)，会自动下载最新的zls并配置好，如果使用 **neovim** 的内置 LSP 功能，则推荐使用 [**mason.nvim**](https://github.com/williamboman/mason.nvim) 和 [**mason-lspconfig.nvim**](https://github.com/williamboman/mason-lspconfig.nvim)。

::: tip
mason 所安装的 zls 为稳定版本，如果需要 `nightly` 版本，则需要克隆最新版的源码进行编译，具体可以参照如下：

```sh
# 单独创建一个source目录
mkdir source
cd source
git clone https://github.com/zigtools/zls.git
cd zls
zig build -Doptimize=ReleaseSafe
# 此处将编译后的zls直接覆盖mason的zls
cp zig-out/bin/zls  ~/.local/share/nvim/mason/packages/zls/bin/zls
```

:::

![nvim-zig](/picture/basic/nvim-zig.png)

## Emacs

如果说 Vim 是编辑器之神，那么Emacs就是神的编辑器！

Zig 官方维护了 Emacs 的插件 [zig-mode](https://github.com/ziglang/zig-mode)，参照页面配置即可。

Emacs 也可以使用 [lsp-mode](https://github.com/emacs-lsp/lsp-mode) 来使用 **zls** 。

## Sublime Text

经典的编辑器，插件也是由 zig 官方维护：[sublime-zig-language](https://github.com/ziglang/sublime-zig-language)，安装即可。

::: danger
值得注意的是，该插件已经有两年无人维护！
:::
