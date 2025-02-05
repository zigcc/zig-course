---
outline: deep
---

# 环境安装

::: tip 🅿️ 提示
当前 Zig 还没有发布 1.0 版本，发布周期与 LLVM 的新版本关联，其发布周期约为 6 个月。
因此，Zig 的发布往往要间隔很久，以目前的开发速度，稳定版最终会变得过时（即便此时还没有新的稳定版），所以官方鼓励用户使用 `nightly` 版本。
:::

## Windows

::: details windows 输出中文乱码问题

如果你是中文简体用户，那么建议将 windows 的编码修改为 UTF-8 编码，由于 zig 的源代码编码格式是 UTF-8，导致在 windows 下向控制台打印输出中文会发生乱码的现象。

修改方法为：

1. 打开 windows 设置中的 **时间和语言**，进入 **语言和区域**。
2. 点击下方的管理语言设置，在新打开的窗口中点击 **管理**。
3. 点击下方的 **更改系统区域设置**，勾选下方的“使用 unicode UTF-8 提供全球语言支持”
4. 重启计算机。

:::

### Scoop

推荐使用 [Scoop](https://scoop.sh/#/) 工具进行安装，Scoop 的 **main** 仓库和 **version** 仓库分别有着最新的 `release` 和 `nightly` 版本。

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

- 使用 `scoop reset zig-dev` 或者 `scoop reset zig` 可以从 nightly 和 release 版本相互切换
- 使用 `scoop install zig@0.11.0` 可以安装指定版本的 zig，同理 `scoop reset zig@0.11.0` 也能切换到指定版本！
  :::

### 其他的包管理器

也可以使用诸如 [WinGet](https://github.com/microsoft/winget-cli)，[Chocolatey](https://chocolatey.org/)

::: code-group

```sh [WinGet]
winget install -e --id zig.zig
```

```sh [Chocolatey]
choco install zig
```

:::

### 手动安装

通过官方的 [发布页面](https://ziglang.org/zh/download/) 下载对应的 Zig 版本，普通用户选择 `zig-windows-x86_64` 即可。

执行以下命令：

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
以上的 **_System_** 对应的系统全局的环境变量， **_User_** 对应的是用户的环境变量。如果是个人电脑，使用任意一个没有区别。

首先确保你的路径是正确的，其次你可能注意到路径前面还有一个 `;` ，此处并不是拼写错误！
:::

## Mac

Mac 安装 zig 就很方便，但是如果要使用 `nightly` ，还是需要自行下载并添加环境变量

::: code-group

```sh [Homebrew]
brew install zig
```

```sh [MacPorts]
port install zig
```

:::

## Linux

Linux 安装的话，由于发行版的不同，安装的方式五花八门，先列出通过包管理器安装 Zig 的方法，再说明如何手动安装 Zig 并设置环境变量。

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

通过官方的[发布页面](https://ziglang.org/zh/download/)下载对应的 Zig 版本，之后将包含 Zig 二进制的目录加入到 PATH 环境变量即可。

## 多版本管理

由于 Zig 还在快速开发迭代中，因此在使用社区已有类库时，有可能出现新版本 Zig 无法编译的情况，这时候一方面可以跟踪上游进展，看看是否有解决方案；另一个就是使用固定的版本来编译这个项目，显然这种方式更靠谱一些。

目前为止，Zig 的版本管理工具主要有如下几个：

- [marler8997/zigup](https://github.com/marler8997/zigup): Download and manage zig compilers
- [tristanisham/zvm](https://github.com/tristanisham/zvm): Lets you easily install/upgrade between different versions of Zig
- [hendriknielaender/zvm](https://github.com/hendriknielaender/zvm): Fast and simple zig version manager

读者可根据自身需求选择，这里介绍一个通用的版本管理工具：[asdf](https://asdf-vm.com/)。

1. 参考 [Getting Started](https://asdf-vm.com/guide/getting-started.html) 下载 asdf，一般而言，常见的系统管理器，如 brew、apt 均可直接安装
2. 安装 asdf [Zig 插件](https://github.com/asdf-community/asdf-zig)

```bash
asdf plugin-add zig https://github.com/asdf-community/asdf-zig.git
```

3. 之后就可以用 asdf 管理 Zig 版本。这里列举一些 asdf 常用命令：

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
