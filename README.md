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

## 📖 在线阅读

- **官方网站**: [https://course.ziglang.cc/](https://course.ziglang.cc/)
- **GitHub Pages**: [https://zigcc.github.io/zig-course/](https://zigcc.github.io/zig-course/)

## ✨ 内容特色

本教程覆盖了 Zig 学习和实践中的多个重要领域：

- **环境配置**: 指导如何安装和配置 Zig 开发环境，支持多种编辑器配置
- **基础入门**: 包括变量、类型、流程控制、错误处理等基础知识
- **高级主题**: 深入探讨 `comptime`、异步、内存管理、C 语言交互等高级特性
- **工程实践**: 涵盖构建系统、包管理、单元测试和代码风格指南
- **版本兼容**: 提供与 Zig 0.11-0.15 版本相对应的代码示例
- **实战案例**: 包含 TCP 服务器等实际项目示例

## 📁 项目结构

```
zig-course/
├── .github/                    # GitHub Actions 工作流
│   ├── workflows/              # CI/CD 配置
│   └── dependabot.yml         # 依赖更新配置
├── build/                      # 不同 Zig 版本的构建脚本
│   ├── 0.11.zig              # Zig 0.11 构建配置
│   ├── 0.12.zig              # Zig 0.12 构建配置
│   └── ...                    # 其他版本
├── course/                     # 教程主要内容
│   ├── .vitepress/            # VitePress 配置
│   │   ├── config.mts         # 站点配置
│   │   ├── theme/             # 主题定制
│   │   └── ...
│   ├── basic/                 # 基础教程
│   │   ├── basic_type/        # 基本类型
│   │   ├── advanced_type/     # 高级类型
│   │   ├── process_control/   # 流程控制
│   │   └── ...
│   ├── advanced/              # 高级教程
│   │   ├── comptime.md        # 编译期计算
│   │   ├── async.md           # 异步编程
│   │   ├── memory_manage.md   # 内存管理
│   │   └── ...
│   ├── engineering/           # 工程实践
│   │   ├── build-system.md    # 构建系统
│   │   ├── package_management.md # 包管理
│   │   └── ...
│   ├── environment/           # 环境配置
│   ├── examples/              # 示例项目
│   ├── code/                  # 代码示例（按版本分类）
│   │   ├── 11/                # Zig 0.11 示例
│   │   ├── 12/                # Zig 0.12 示例
│   │   └── ...
│   ├── picture/               # 图片资源
│   ├── public/                # 静态资源
│   └── update/                # 版本更新说明
├── draw/                       # 绘图源文件
├── build.zig                   # 主构建文件
├── package.json               # Node.js 依赖配置
├── CONTRIBUTING.md            # 贡献指南
├── CODE_OF_CONDUCT.md         # 行为准则
└── README.md                  # 项目说明
```

## 🚀 本地开发

### 环境要求

- **Node.js**: 推荐使用 [Bun](https://bun.sh/) 作为包管理器
- **Zig**: 支持 0.11-0.15 版本
- **autocorrect**: 用于中英文排版优化（可选）

### 快速开始

```sh
# 克隆仓库
git clone https://github.com/zigcc/zig-course.git
cd zig-course

# 安装依赖
bun install

# 启动开发服务器
bun dev

# 在浏览器中访问 http://localhost:5173
```

### 可用命令

```sh
bun dev          # 启动开发服务器（热重载）
bun run build        # 构建生产版本
bun preview      # 预览构建结果
bun format       # 格式化代码（prettier + zig fmt + autocorrect）
bun check        # 检查代码格式
bun export-pdf   # 导出 PDF 版本
```

## 🤝 参与贡献

我们热烈欢迎各位"道友"参与贡献，一起壮大 Zig 中文社区！

### 贡献方式

1. **内容贡献**
   - 修正错误和改进现有内容
   - 添加新的章节或示例
   - 翻译和本地化改进
   - 添加代码示例和实战案例

2. **技术贡献**
   - 改进网站功能和用户体验
   - 优化构建流程和 CI/CD
   - 修复 bug 和性能问题

3. **社区贡献**
   - 参与讨论和问题解答
   - 推广和分享项目
   - 提供反馈和建议

### 贡献流程

1. **Fork 仓库**

   ```sh
   # 在 GitHub 上 Fork 本仓库
   git clone https://github.com/YOUR_USERNAME/zig-course.git
   cd zig-course
   ```

2. **创建功能分支**

   ```sh
   git checkout -b feature/your-feature-name
   # 或
   git checkout -b fix/your-fix-name
   ```

3. **进行修改**
   - 遵循现有的代码风格和文档格式
   - 确保所有代码示例都能正常运行
   - 运行 `bun format` 格式化代码

4. **测试修改**

   ```sh
   bun dev    # 本地测试
   bun build  # 确保构建成功
   ```

5. **提交更改**

   ```sh
   git add .
   git commit -m "feat: 添加新功能描述"
   # 或
   git commit -m "fix: 修复问题描述"
   ```

6. **推送并创建 PR**
   ```sh
   git push origin feature/your-feature-name
   # 在 GitHub 上创建 Pull Request
   ```

### 贡献规范

- **提交信息**: 使用 [约定式提交](https://www.conventionalcommits.org/zh-hans/) 格式
- **代码风格**: 运行 `bun format` 确保代码格式一致
- **文档规范**:
  - 中英文之间添加空格
  - 使用中文标点符号
  - 代码块指定语言类型
- **分支命名**:
  - 功能：`feature/功能描述`
  - 修复：`fix/问题描述`
  - 文档：`docs/文档更新`

### 内容编写指南

1. **Markdown 格式**
   - 使用标准 Markdown 语法
   - 代码块指定语言 `zig`
   - 适当使用表格和列表

2. **代码示例**
   - 确保代码能在对应 Zig 版本下运行
   - 添加必要的注释说明
   - 提供完整的可运行示例

3. **图片和资源**
   - 图片放在 `course/picture/` 目录下
   - 使用相对路径引用
   - 提供 alt 文本描述

### 版本兼容性

本项目支持多个 Zig 版本，在贡献代码时请注意：

- 在 `course/code/` 目录下按版本分类存放示例代码
- 确保代码示例在对应版本下能正常编译运行
- 如有版本差异，请在文档中明确说明

## 📋 开发注意事项

- **包管理器**: 本项目使用 [Bun](https://bun.sh/)，请勿提交其他包管理器的配置文件
- **依赖更新**: 更新依赖前请参考 [Bun Lockfile 文档](https://bun.sh/docs/install/lockfile)
- **格式化**: 提交前务必运行 `bun format` 进行代码格式化
- **构建测试**: 确保 `bun build` 能成功构建

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)，欢迎自由使用和分发。

## 🙏 致谢

感谢所有为本项目做出贡献的开发者和 Zig 中文社区的支持！

## 📞 联系我们

- **GitHub Issues**: [提交问题和建议](https://github.com/zigcc/zig-course/issues)
- **GitHub Discussions**: [参与社区讨论](https://github.com/zigcc/zig-course/discussions)

---

如果这个项目对你有帮助，请给我们一个 ⭐️ Star！
