# AGENTS.md

本文档帮助 AI 助手理解 Zig 语言圣经项目的结构和开发规范。

## 项目概述

**Zig 语言圣经** 是一个全面的开源 Zig 编程语言中文教程。项目旨在为中文开发者提供高质量的 Zig 学习资源。

- **官方网站**: https://course.ziglang.cc/
- **GitHub Pages**: https://zigcc.github.io/zig-course/
- **代码仓库**: https://github.com/zigcc/zig-course
- **开源协议**: MIT
- **主要语言**: 简体中文
- **文档语言**: 中文为主，技术术语保留英文

## 核心目标

1. 提供全面的 Zig 编程语言中文文档
2. 支持多个 Zig 版本（0.11 至 0.16）
3. 维护可运行的代码示例
4. 记录版本升级指南和破坏性变更
5. 构建高质量的中文 Zig 社区学习资源

## 项目结构

```
zig-course/
├── build.zig                    # 主构建编排器
├── build/                       # 版本特定的构建脚本
│   ├── 0.11.zig                # Zig 0.11 构建逻辑
│   ├── 0.12.zig                # Zig 0.12 构建逻辑
│   ├── 0.13.zig                # Zig 0.13 构建逻辑
│   ├── 0.14.zig                # Zig 0.14 构建逻辑
│   ├── 0.15.zig                # Zig 0.15 构建逻辑（当前重点）
│   └── 0.16.zig                # Zig 0.16 构建逻辑
│
├── course/                      # 主要文档内容
│   ├── .vitepress/             # VitePress 配置
│   │   ├── config.mts          # 站点主配置
│   │   ├── sidebar.ts          # 侧边栏导航结构
│   │   ├── nav.ts              # 顶部导航
│   │   └── theme/              # 自定义主题组件
│   │
│   ├── environment/            # 环境搭建指南
│   ├── basic/                  # Zig 基础概念
│   ├── advanced/               # 进阶主题
│   ├── engineering/            # 软件工程实践
│   ├── examples/               # 实战示例
│   ├── update/                 # 版本升级指南
│   ├── appendix/               # 参考资料
│   │
│   ├── code/                   # 可运行的代码示例
│   │   ├── 11/                 # Zig 0.11 示例
│   │   ├── 12/                 # Zig 0.12 示例
│   │   ├── 13/ → ./12          # 符号链接（与 0.12 兼容）
│   │   ├── 14/                 # Zig 0.14 示例
│   │   ├── 15/                 # Zig 0.15 示例（当前活跃版本）
│   │   └── release/ → ./15     # 符号链接到最新稳定版
│   │
│   ├── picture/                # 图片资源
│   └── public/                 # 静态网站资源
│
├── .github/
│   └── workflows/              # CI/CD 流水线
│       ├── build.yml           # 多平台、多版本构建
│       ├── deploy.yml          # GitHub Pages 部署
│       ├── check.yml           # 代码格式检查
│       ├── autocorrect.yml     # 中文文本格式检查
│       └── pdf.yml             # PDF 导出流程
│
├── package.json                # Node.js 依赖（Bun）
├── bun.lock                    # Bun 锁文件
└── flake.nix                   # Nix 开发环境
```

## 开发工作流

### 构建和测试

项目使用多版本构建系统确保跨 Zig 版本兼容性：

```bash
# 使用当前 Zig 版本构建所有示例
zig build

# 主 build.zig 会根据检测到的 Zig 编译器版本
# 自动分发到 build/ 目录下对应的版本特定脚本
```

### 文档开发

文档站点使用 VitePress 构建：

```bash
# 启动带热重载的开发服务器
bun dev

# 构建生产站点
bun build

# 预览构建后的站点
bun preview

# 导出 PDF 版本
bun export-pdf
```

### 代码格式化

```bash
# 格式化所有代码（Markdown、Zig、中文文本）
bun format

# 检查格式但不修改文件
bun check
```

这会运行：

- Prettier 处理 Markdown/TypeScript/JavaScript
- `zig fmt` 处理 Zig 源文件
- AutoCorrect 处理中文文本格式

## 版本兼容性维护

### 多版本构建系统架构

项目采用版本分发架构来支持多个 Zig 版本：

1. **主构建入口** (`build.zig`): 检测当前 Zig 编译器版本，自动分发到对应的版本特定构建脚本
2. **版本构建脚本** (`build/0.XX.zig`): 每个版本有独立的构建逻辑
3. **代码示例目录** (`course/code/XX/`): 每个版本维护独立的示例代码

### 修复不同版本编译问题的工作流程

当需要修复特定 Zig 版本的编译问题时，需要处理以下目录：

#### 1. 更新构建脚本

**路径**: `build/0.XX.zig`

当 Zig 编译器 API 发生变更时需要更新：
- 构建系统 API 变更（如 `std.Build` 接口改变）
- 模块系统变更（如 `root_module` 相关 API）
- 目标平台和优化选项变更

**示例场景**:
- Zig 0.12 引入模块系统，需要从 `addExecutable` 迁移到 `addModule`
- Zig 0.14 更改了目标解析方式，需要更新 `resolved_target` 相关代码

#### 2. 更新代码示例

**路径**: `course/code/XX/`

此目录包含两类文件需要维护：

##### a) 单文件示例（直接的 .zig 文件）
这些文件会被构建脚本直接编译为可执行文件和测试：
- `hello_world.zig`
- `array.zig`
- `comptime.zig`
- 等等...

**修复重点**:
- 标准库 API 变更（如 `std.debug.print`、`std.mem.Allocator`）
- 语法变更（如错误处理、可选类型语法）
- 类型系统变更

##### b) 项目类型示例（子目录包含 build.zig）
这些是完整的 Zig 项目，有自己的构建系统：
- `build_system/` - 构建系统示例
- `import_dependency_build/` - 依赖管理示例
- `import_vcpkg/` - C 库集成示例

**修复重点**:
- 项目自己的 `build.zig` 需要同步更新
- 依赖声明方式的变更（如 `build.zig.zon`）
- 模块导入和导出方式的变更

#### 3. 版本符号链接维护

**当前符号链接**:
- `course/code/13/` → `./12` (Zig 0.13 与 0.12 兼容)
- `course/code/release/` → `./15` (指向最新稳定版)

**维护规则**:
- 如果新版本完全兼容旧版本，可以创建符号链接而不是复制代码
- 当有破坏性变更时，必须创建独立目录并更新所有示例

#### 4. 验证流程

在根目录运行 `zig build` 验证修复：

```bash
# 主 build.zig 会自动选择对应版本的构建脚本
zig build

# 构建过程会：
# 1. 编译 course/code/XX/ 下的所有单文件示例
# 2. 运行所有测试
# 3. 递归构建子目录中的项目示例
```

#### 5. 常见破坏性变更类型

**标准库变更**:
- 分配器 API (`std.heap.GeneralPurposeAllocator`)
- 文件系统 API (`std.fs`)
- 网络 API (`std.net`)

**语言特性变更**:
- 错误处理语法
- 可选类型语法
- 编译时特性

**构建系统变更**:
- `std.Build` API
- 模块系统
- 依赖管理（`build.zig.zon`）

#### 6. 实用技巧

**批量测试多个版本**:
项目的 CI 系统（`.github/workflows/build.yml`）会在多个平台和 Zig 版本上运行构建，可以参考 CI 配置来本地测试多版本兼容性。

**创建新版本支持**:
1. 复制最近版本的 `build/0.XX.zig` 到新版本
2. 复制或链接 `course/code/XX/` 目录
3. 在主 `build.zig` 中添加新版本的 case 分支
4. 运行构建并修复所有编译错误
5. 更新 `course/code/release/` 符号链接（如果是最新稳定版）

**检查依赖项目**:
不要忘记检查子目录项目的构建：
```bash
cd course/code/15/build_system
zig build
```
