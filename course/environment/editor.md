---
outline: deep
---

# 编辑器选择

> **_工欲善其事，必先利其器！_**

## VS Code

官网地址：[https://code.visualstudio.com/](https://code.visualstudio.com/)

> Visual Studio Code 是一款由微软开发且跨平台的免费源代码编辑器。该软件以扩展的方式支持语法高亮、代码自动补全、代码重构功能，并且内置了命令行工具和Git 版本控制系统。用户可以更改主题和键盘快捷方式实现个性化设置，也可以通过内置的扩展程序商店安装其他扩展以拓展软件功能。

目前最轻量且生态丰富的编辑器，微软出品，zig 官方为其开发了插件，仅需要安装 [`Zig Language`](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig)这个插件即可，在初次初始化时会推荐安装 _language server_， 确认即可！

![vscode-zig](/picture/basic/vscode-zig.png){data-zoomable}

## Vim / Neovim

Vim：[https://github.com/vim/vim](https://github.com/vim/vim)

Neovim：[https://github.com/neovim/neovim](https://github.com/neovim/neovim)

古老的编辑器之一，被誉为“编辑器之神”！

推荐安装插件 [zig.vim](https://github.com/ziglang/zig.vim)，由官方维护。

::: details 小细节

推荐关闭 vim / neovim 的保存自动格式化功能（默认开启）：

```sh
# for vim
let g:zig_fmt_autosave = 0

# for neovim lua
vim.g.zig_fmt_autosave = false
```

:::

如果使用`coc.nvim`作为 _language server_，则推荐使用 [**coc-zls**](https://github.com/xiyaowong/coc-zls)，会自动下载最新的zls并配置好，如果使用 **neovim** 的内置 LSP 功能，则推荐使用 [**mason.nvim**](https://github.com/williamboman/mason.nvim) 和 [**mason-lspconfig.nvim**](https://github.com/williamboman/mason-lspconfig.nvim)。

::: tip 🅿️ 提示
mason 所安装的 zls 为稳定版本，如果需要 `nightly` 版本，有两种方案可以选择，安装 Zig.nvim 插件，或者手动编译。

- Zig.nvim 插件的仓库地址为：[jinzhongjia/Zig.nvim](https://github.com/jinzhongjia/Zig.nvim)

- 手动编译安装的方法如下：

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

推荐使用 Emacs 28 版本新引入的 [eglot](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html) 作为 LSP 客户端。

![emacs-zig](/picture/basic/emacs-zig.png){data-zoomable}

## VS

官网地址：[https://visualstudio.microsoft.com/](https://visualstudio.microsoft.com/)

> Microsoft Visual Studio是微软公司的开发工具包系列产品。VS是一个基本完整的开发工具集，它包括了整个软件生命周期中所需要的大部分工具，如UML工具、代码管控工具、集成开发环境等等。

windows 上最棒的开发 IDE，存在第三方插件：[ZigVS](https://marketplace.visualstudio.com/items?itemName=LuckystarStudio.ZigVS)。

## CLion

> CLion 是一款专为开发 C 及 C++ 所设计的跨平台 IDE。它是以 IntelliJ 为基础设计的，包含了许多智能功能来提高开发人员的生产力。CLion 帮助开发人员使用智能编辑器来提高代码质量、自动代码重构并且深度整合 CMake 编译系统，从而提高开发人员的工作效率。

原本 CLion 仅仅是 C/C++ 的开发IDE，但在安装插件后可以作为 zig 的 IDE 使用。

目前插件市场活跃的两个 zig 插件（均为第三方作者维护）分别是 [ZigBrains](https://plugins.jetbrains.com/plugin/22456-zigbrains) 和 [Zig Support](https://plugins.jetbrains.com/plugin/18062-zig-support)，均支持 zig 的 `0.11.0` 版本。

## Sublime Text

经典的编辑器，插件也是由 zig 官方维护：[sublime-zig-language](https://github.com/ziglang/sublime-zig-language)，安装即可。

::: danger ⛔ 危险
值得注意的是，该插件已经有两年无人维护！
:::
