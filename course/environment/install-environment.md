---
outline: deep
---

# 环境安装

::: tip 🅿️ 提示
当前 Zig 尚未发布 1.0 版本，其发布周期与 LLVM 的新版本发布（约每 6 个月一次）相关联。
因此，Zig 的稳定版发布间隔较长。鉴于 Zig 的快速发展，稳定版可能很快会落后于最新功能，所以官方鼓励用户使用更新更频繁的 `nightly` 版本。
:::

## Windows

::: details windows 输出中文乱码问题

如果你是简体中文用户，建议将 Windows 的系统区域设置修改为 UTF-8。由于 Zig 源代码及默认输出使用 UTF-8 编码，此举可以避免在控制台输出中文时出现乱码。

修改步骤如下：

1. 打开 Windows 设置中的 **时间和语言**，进入 **语言和区域**。
2. 点击下方的管理语言设置，在新打开的窗口中点击 **管理**。
3. 点击下方的 **更改系统区域设置**，勾选下方的“Beta: 使用 Unicode UTF-8 提供全球语言支持”。
4. 重启计算机。

:::

### Scoop

推荐使用 [Scoop](https://scoop.sh/#/) 工具进行安装。Scoop 的 **main** 仓库提供最新的 `release` 版本，而 **versions** 仓库提供 `nightly` 版本。

安装方式如下：

::: code-group

```sh [Release]
scoop bucket add main
scoop install main/zig
```

```sh [Nightly]
scoop bucket add versions
scoop install versions/zig-dev
```

:::

::: info 🅿️ 提示

- 使用 `scoop reset zig-dev` 或 `scoop reset zig` 可以在 `nightly` 和 `release` 版本之间切换。
- 使用 `scoop install zig@0.11.0` 可以安装特定版本，同理，`scoop reset zig@0.11.0` 可以切换到该指定版本。
  :::

### 其他的包管理器

也可以使用诸如 [WinGet](https://github.com/microsoft/winget-cli) 或 [Chocolatey](https://chocolatey.org/) 等包管理器。

::: code-group

```sh [WinGet]
winget install -e --id zig.zig
```

```sh [Chocolatey]
choco install zig
```

:::

### 手动安装

从官方 [发布页面](https://ziglang.org/zh/download/) 下载对应的 Zig 版本，大多数用户应选择 `zig-windows-x86_64`。

解压后，将包含 `zig.exe` 的目录路径添加到系统的 `Path` 环境变量中。可以通过以下 PowerShell 命令完成：

::: code-group

```powershell [System]
[Environment]::SetEnvironmentVariable(
   "Path",
   [Environment]::GetEnvironmentVariable("Path", "Machine")
   + ";C:\your-path\zig-windows-x86_64-your-version",
   "Machine"
)
```

```powershell [User]
[Environment]::SetEnvironmentVariable(
   "Path",
   [Environment]::GetEnvironmentVariable("Path", "User")
   + ";C:\your-path\zig-windows-x86_64-your-version",
   "User"
)
```

:::

::: info 🅿️ 提示
**_System_** 对应系统全局环境变量，**_User_** 对应当前用户环境变量。如果是个人电脑，两者通常没有太大区别。

请确保将 `C:\your-path\zig-windows-x86_64-your-version` 替换为你的实际解压路径。路径前的分号 `;` 是必需的，并非拼写错误，它用于在 `Path` 变量中分隔多个路径。
:::

## Mac

在 macOS 上安装 Zig 非常方便。但若要使用 `nightly` 版本，仍需手动下载并设置环境变量。

::: code-group

```sh [Homebrew]
brew install zig
```

```sh [MacPorts]
port install zig
```

:::

## Linux

由于 Linux 发行版众多，安装方式各异。下面将先列出通过包管理器安装的方法，然后说明手动安装的步骤。

### 包管理器安装

以下列出了支持通过包管理器安装 Zig 的发行版和对应命令：

| 发行版            |               命令                |                                                                 备注 |
| ----------------- | :-------------------------------: | -------------------------------------------------------------------: |
| Arch Linux        |           pacman -S zig           | AUR: [`zig-dev-bin`](https://aur.archlinux.org/packages/zig-dev-bin) |
| Fedora            |          dnf install zig          |                                                                      |
| Fedora Silverblue |      rpm-ostree install zig       |                                                                      |
| Gentoo            |      emerge -av dev-lang/zig      |                                                                      |
| NixOS             |          nix-env -i zig           |                                                                      |
| Ubuntu (snap)     | snap install zig --classic --beta |                                                                      |
| Void Linux        |       xbps-install -Su zig        |                                                                      |

### 手动安装

从官方[发布页面](https://ziglang.org/zh/download/)下载对应的 Zig 版本，解压后将包含 Zig 二进制文件的目录加入到 `PATH` 环境变量即可。

## 多版本管理

由于 Zig 仍在快速迭代，使用新版 Zig 编译器时，可能会遇到无法编译旧有社区库的问题。此时，除了向上游社区寻求解决方案，更可靠的方式是使用特定版本的 Zig 来编译特定项目。这就需要版本管理工具。

目前，Zig 的版本管理工具主要有以下几个：

- [marler8997/zigup](https://github.com/marler8997/zigup): Download and manage zig compilers
- [tristanisham/zvm](https://github.com/tristanisham/zvm): Lets you easily install/upgrade between different versions of Zig
- [hendriknielaender/zvm](https://github.com/hendriknielaender/zvm): Fast and simple zig version manager

读者可根据需求自行选择。本文将介绍一个通用的多语言版本管理工具：[asdf](https://asdf-vm.com/)。

1. 请参考官方文档 [Getting Started](https://asdf-vm.com/guide/getting-started.html) 安装 asdf。通常，可以通过 Homebrew (macOS) 或 apt (Debian/Ubuntu) 等包管理器直接安装。
2. 安装 asdf [Zig 插件](https://github.com/asdf-community/asdf-zig)：

```bash
asdf plugin-add zig https://github.com/asdf-community/asdf-zig.git
```

3. 安装完成后，便可使用 asdf 管理 Zig 版本。以下是一些常用命令：

```bash
# 列举所有可安装的版本
asdf list-all zig

# 安装指定版本的 Zig
asdf install zig <version>

# 卸载指定版本的 Zig
asdf uninstall zig <version>

# 设置全局默认版本，会写到 $HOME/.tool-versions 文件
asdf global zig <version>

# 设置当前目录使用的版本，会写到 $(pwd)/.tool-versions 文件
asdf local zig <version>
```
