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

如果你是中文简体用户，那么建议将 windows 的编码修改为UTF-8编码，由于 zig 的源代码编码格式是 UTF-8，导致在windows下向控制台打印输出中文会发生乱码的现象。

修改方法为：

1. 打开 widnows 设置中的 **时间和语言**，进入 **语言和区域**。
2. 点击下方的管理语言设置，在新打开的窗口中点击 **管理**。
3. 点击下方的 **更改系统区域设置**，勾选下方的 “使用 unicode UTF-8 提供全球语言支持”
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
在使用 Scoop 时，推荐将 Zig 作为 global 安装，这样 Zig 会被自动添加进环境变量。
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

通过官方的[发布页面](https://ziglang.org/zh/download/)下载对应的 Zig 版本，普通用户选择 `zig-windows-x86_64` 即可。

执行以下命令：

::: code-group

```powershell [System]
[Environment]::SetEnvironmentVariable(
   "Path",
   [Environment]::GetEnvironmentVariable("Path", "Machine") + ";C:\your-path\zig-windows-x86_64-your-version",
   "Machine"
)
```

```powershell [User]
[Environment]::SetEnvironmentVariable(
   "Path",
   [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\your-path\zig-windows-x86_64-your-version",
   "User"
)
```

:::

::: info 🅿️ 提示
以上的 **_System_** 对应的系统全局的环境变量， **_User_** 对应的是用户的环境变量。如果是个人电脑，使用任意一个没有区别。

首先确保你的路径是正确的，其次你可能注意到路径前面还有一个 `;` ，此处并不是拼写错误！
:::

## Mac

Mac安装 zig 就很方便，但是如果要使用 `nightly` ，还是需要自行下载并添加环境变量

::: code-group

```sh [Homebrew]
brew install zig
```

```sh [MacPorts]
port install zig
```

:::

## Linux

Linux安装的话， 由于发行版的不同，安装的方式五花八门，先列出通过包管理器安装 Zig 的方法，再说明如何手动安装 Zig 并设置环境变量。

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

通过官方的[发布页面](https://ziglang.org/zh/download/)下载对应的 Zig 版本，普通用户选择 `zig-linux-x86_64` 即可。

以下讲述两种两种方法安装 zig ，一种是采取通用的linux安装方式，一种是在个人目录下安装，添加环境变量

#### 通用linux安装方式

创建目录 `/usr/lib/zig`，然后将所有文件内容移动到 `/usr/lib/zig` 目录下，最后将可执行文件 `zig` 通过软链接映射到 `/usr/bin/zig` ，具体命令操作如下：

```sh
tar -xpf archive.tar.xz
cd zig-linux
cp -r . /usr/lib/zig
ln -s /usr/lib/zig/zig /usr/bin/zig
```

#### 个人目录安装

这种方案是采取配置`PATH`来实现：

```sh
# 推荐将资源文件放置在 ~/.local/bin
mkdir ~/.local/bin
mkdir ~/.local/bin/zig

tar -xpf archive.tar.xz
cd zig-linux
cp -r . ~/.local/bin/zig
```

然后像bash写入环境变量配置，如 `~/.bashrc` ：

```sh
export PATH="~/.local/bin/zig/:$PATH"
```

如果使用其他的shell,则需要用户自己参照所使用的shell的配置来设置PATH
