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

## 关键文件及其用途

| 文件/目录 | 用途 |
|-----------|------|
| `build.zig` | 主构建编排器，检测 Zig 版本并委托给对应的构建脚本 |
| `build/0.15.zig` | 当前活跃的构建脚本，具有智能示例发现功能 |
| `course/.vitepress/config.mts` | VitePress 配置（语言、主题、SEO） |
| `course/.vitepress/sidebar.ts` | 定义课程导航结构 |
| `course/code/15/` | Zig 0.15 可运行示例（当前活跃版本） |
| `course/basic/` | Zig 基础概念（变量、类型、控制流） |
| `course/advanced/` | 进阶主题（comptime、异步、内存管理） |
| `course/update/` | 版本迁移指南 |
| `package.json` | 构建脚本和 Node.js 依赖 |
| `.github/workflows/build.yml` | 跨平台和版本的 CI/CD 测试 |

## 代码示例组织方式

示例按 Zig 版本组织在 `course/code/` 目录下：

### 结构模式

1. **独立文件**：简单示例作为单个 `.zig` 文件
   - 示例：`course/code/15/array.zig`、`course/code/15/comptime.zig`
   - 构建脚本自动发现并编译这些文件

2. **子项目**：复杂示例拥有自己的 `build.zig`
   - 示例：`course/code/15/build_system/`、`course/code/15/package_management_importer/`
   - 构建脚本递归调用子构建

### 添加新示例

添加新示例时：

1. **简单概念**：在 `course/code/15/` 创建独立 `.zig` 文件
2. **复杂功能**：创建带有 `build.zig` 的子目录
3. **更新文档**：在相应章节添加对应的 `.md` 文件
4. **确保编译**：运行 `zig build` 验证
5. **格式化代码**：提交前运行 `bun format`

## 文档结构

课程遵循渐进式学习路径：

1. **环境搭建**（`course/environment/`）
   - 安装指南
   - 编辑器配置
   - Zig CLI 参考

2. **基础学习**（`course/basic/`）
   - 变量和类型
   - 控制流
   - 错误处理
   - 类型系统基础

3. **进阶学习**（`course/advanced/`）
   - 编译期计算（comptime）
   - 异步/await
   - 内存管理
   - C 互操作
   - 反射和元编程

4. **工程实践**（`course/engineering/`）
   - 构建系统
   - 包管理
   - 单元测试
   - 代码风格指南

5. **实战示例**（`course/examples/`）
   - 完整项目（如 TCP 服务器）

6. **版本指南**（`course/update/`）
   - 版本发布说明
   - 迁移指南

## 构建系统内部机制

### 主构建脚本（`build.zig`）

主构建脚本：
1. 检测当前 Zig 编译器版本
2. 分发到 `build/` 目录下对应的版本特定构建脚本
3. 优雅处理版本兼容性

### 版本特定构建脚本（`build/0.15.zig`）

每个版本构建脚本：
1. **发现示例**：扫描 `course/code/VERSION/` 目录
2. **分类**：
   - 独立 `.zig` 文件 → 编译为可执行文件
   - 包含 `build.zig` 的目录 → 作为子项目调用
3. **平台处理**：应用平台特定配置
4. **测试执行**：运行内嵌的单元测试

### 示例发现算法

```
对于 course/code/VERSION/ 中的每个项目：
  如果项目是 .zig 文件：
    → 创建可执行文件构建步骤
  否则如果项目是目录：
    如果目录包含 build.zig：
      → 创建对子项目构建的依赖
    否则：
      → 跳过（可能是支持文件）
```

## CI/CD 流水线

### 构建工作流（`.github/workflows/build.yml`）

- **触发器**：`.zig` 文件、构建脚本或配置文件变更
- **矩阵**：3 个操作系统（Ubuntu、macOS、Windows）× 6 个 Zig 版本
- **目的**：确保所有示例在各平台和版本上都能编译
- **调度**：每日运行

### 部署工作流（`.github/workflows/deploy.yml`）

- **触发器**：推送到 `main` 分支
- **目的**：构建并部署文档到 GitHub Pages
- **步骤**：
  1. 安装 Bun
  2. 安装依赖
  3. 构建 VitePress 站点
  4. 上传到 GitHub Pages

### 检查工作流（`.github/workflows/check.yml`）

- **触发器**：Pull Request、推送
- **目的**：验证代码格式
- **工具**：Prettier、Zig fmt、AutoCorrect

## 编码规范

### 提交信息

遵循 Conventional Commits：
```
<type>(<scope>): <description>

类型: feat, fix, docs, refactor, chore, test, style
作用域: course/basic, course/advanced, build, ci 等

示例:
- feat(course/basic): 为 0.15 添加数组示例
- fix(build): 修正平台检测逻辑
- docs(course/update): 更新 0.15.1 迁移指南
- refactor(course/code/15): 简化 comptime 示例
```

### 分支命名

```
feature/<description>    # 新功能
fix/<description>        # Bug 修复
docs/<description>       # 文档更新
update/<description>     # 版本更新

示例: update/fix-0.15.1
```

### 代码风格

**Zig 代码**：
- 使用 `zig fmt`（在 CI 中强制执行）
- 遵循 Zig 风格指南原则
- 为公共 API 添加文档注释

**Markdown**：
- 中文文本使用中文标点（。，！？）
- 中文和英文/数字之间添加空格
- 代码块使用具体语言标记：` ```zig`，不要用 ` ```
- 图片使用相对路径：`![描述](../picture/...)`

**中文文本**：
- 正确使用标点符号（。不是 .）
- 正确使用引号（「」不是 ""）
- 中英文之间加空格
- 由 CI 中的 AutoCorrect 检查

### 文件组织

**文档文件**：
- 放在 `course/` 下的适当分类中
- 使用英文描述性文件名
- 如添加新页面需更新 `course/.vitepress/sidebar.ts`

**代码示例**：
- 放在 `course/code/15/`（或当前版本）
- 尽可能匹配文档结构
- 包含解释概念的文档注释

**图片**：
- 放在 `course/picture/` 中
- 使用子目录组织
- 提交前优化图片

## 常见任务

### 添加新的语言概念

1. **创建文档**：`course/basic/<topic>.md` 或 `course/advanced/<topic>.md`
2. **添加代码示例**：`course/code/15/<topic>.zig`
3. **更新侧边栏**：在 `course/.vitepress/sidebar.ts` 添加条目
4. **测试编译**：运行 `zig build`
5. **格式化**：运行 `bun format`
6. **提交**：使用规范的提交信息

### 为新 Zig 版本更新

1. **创建新构建脚本**：`build/0.XX.zig`（从上一版本复制并修改）
2. **复制示例**：`cp -r course/code/15 course/code/XX`
3. **更新符号链接**：`ln -sf XX course/code/release`
4. **修复破坏性变更**：根据需要更新代码示例
5. **记录变更**：创建 `course/update/upgrade-0.XX.md`
6. **更新 CI**：在 `.github/workflows/build.yml` 矩阵中添加新版本
7. **彻底测试**：确保所有示例都能编译

### 修复文档问题

1. **定位文件**：使用 grep 或文件搜索
2. **编辑内容**：保持中文文档风格
3. **预览**：运行 `bun dev` 查看变更
4. **格式化**：运行 `bun format`
5. **提交**：使用 `docs(<scope>): <description>` 格式

### 添加复杂示例

1. **创建目录**：`course/code/15/<project-name>/`
2. **添加 build.zig**：创建适当的构建配置
3. **添加源文件**：实现示例
4. **添加 README**：解释示例演示的内容
5. **更新文档**：在相关 `.md` 文件中引用示例
6. **测试**：从项目根目录运行 `zig build`

## 版本兼容性策略

项目使用以下方式维护跨 Zig 版本兼容性：

1. **独立代码目录**：每个主要版本有自己的示例
2. **版本特定构建脚本**：处理语法/API 差异
3. **符号链接**：用于兼容版本（如 0.13 → 0.12）
4. **迁移指南**：记录破坏性变更和升级路径
5. **CI 矩阵测试**：通过自动化测试确保兼容性

## 技术栈

- **语言**：Zig（0.11 - 0.16）
- **文档**：VitePress（Vue 3、TypeScript）
- **包管理器**：Bun（也可使用 npm/yarn）
- **CI/CD**：GitHub Actions
- **托管**：GitHub Pages
- **格式化**：Prettier、Zig fmt、AutoCorrect

## AI 助手重要注意事项

### 处理文档时

1. **语言**：使用简体中文编写，使用正确的标点符号
2. **代码块**：始终指定语言：` ```zig`，绝不使用纯 ` ```
3. **格式化**：中文文本应使用中文标点（。而非 .）
4. **间距**：在中文字符和英文/数字之间添加空格
5. **链接**：内部文档使用相对路径

### 处理代码示例时

1. **版本**：除非另有说明，目标版本为 Zig 0.15
2. **位置**：添加到 `course/code/15/`
3. **测试**：确保代码能编译和运行
4. **文档**：代码配合解释性文档
5. **注释**：为公共 API 使用文档注释（`///`）

### 修改构建系统时

1. **主 build.zig**：很少需要更改（处理版本分发）
2. **版本脚本**：修改适当的 `build/0.XX.zig`
3. **发现逻辑**：理解自动示例检测机制
4. **平台处理**：考虑 Linux、macOS、Windows 差异

### 更新 CI/CD 时

1. **构建矩阵**：保持版本矩阵更新
2. **缓存**：保留 Zig 编译器缓存以提高速度
3. **平台测试**：确保跨平台兼容性
4. **部署工作流**：仅在 main 分支运行

## 资源链接

- [Zig 官方文档](https://ziglang.org/documentation/)
- [VitePress 文档](https://vitepress.dev/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [贡献指南](CONTRIBUTING.md)
- [行为准则](CODE_OF_CONDUCT.md)

---

最后更新：2025-10-22（由 AI 助手自动生成）
