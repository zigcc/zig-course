# PDF 导出器（jsPDF + TypeScript）

为 zig-course（VitePress）自带的离线 PDF 生成器。直接读取项目的
`course/.vitepress/sidebar.ts`，逐页解析 Markdown 并用
[jsPDF](https://github.com/parallax/jsPDF) 矢量绘制，输出带书签与可点击链接的
`books/zig_course.pdf`。**不依赖无头浏览器**（替代旧的 `vitepress-export-pdf` 方案）。

## 使用

```bash
bun pdf          # 全量构建 -> books/zig_course.pdf
bun pdf:sample   # 仅渲染几篇代表页 -> books/zig_course_sample.pdf（快速验证）
```

本项目用 [Bun](https://bun.sh) 直接执行 TypeScript，无需预编译或 tsx。运行依赖：
`shiki`、`jspdf`、`marked`、`sharp`（均在 `devDependencies` 中）。

## 设计概览

| 文件            | 职责                                                                       |
| --------------- | -------------------------------------------------------------------------- |
| `main.ts`       | 入口：`import sidebar`，按目录顺序逐页渲染，写 PDF 书签（outline），输出文件 |
| `parse.ts`      | Markdown 预处理与分词：展开代码引用、GitHub alert、VitePress 容器，转 token |
| `renderer.ts`   | 核心布局引擎：标题/段落/列表/表格/代码块/图片/提示框绘制，链接坐标收集与绑定 |
| `highlight.ts`  | 用 Shiki（VitePress 同款引擎）将代码着色为 `{content, color}` 片段          |
| `utils.ts`      | sidebar 扁平化、站内链接归一化、图片路径解析、代码引用 `<<<@/...` 解析      |
| `tsconfig.json` | 仅用于本目录的类型检查（`tsc --noEmit`），不参与 VitePress 构建            |

### 与项目的集成点

1. **同源 sidebar**：`main.ts` 直接 `import sidebar from "../../course/.vitepress/sidebar.js"`，
   PDF 目录与网页侧边栏始终一致，无需维护第二份顺序表。
2. **排除路由**：`main.ts` 的 `EXCLUDE` 当前**仅排除 `/code/**`**（纯代码片段目录，
   由正文以 `<<<@` 引用导入，本身非正文页面）。`appendix / update / about / epilogue`
   等章节均收入 PDF。调整收录范围改 `EXCLUDE` 即可。
3. **字体**：三套——`zigcourse-cjk.ttf`（Noto Serif SC，即思源宋体同源设计，中文）、
   `zigcourse-sans.ttf`（Inter，正文英文/数字，无衬线）、`zigcourse-mono.ttf`
   （JetBrains Mono，代码/行内代码）。CJK / 正文拉丁 / 代码三路分流绘制。三个 TTF 均为子集
   （只含课程用到的字形）。课程文本变化后用 `bun pdf:fonts` 重新生成并提交。

### 处理的 VitePress 语法

- 代码导入 `<<<@/code/xxx.zig#anchor`：按 `#region/#endregion` 提取片段，
  **保留行尾式结束标记前的代码**（如 `} // #endregion two` 会保留 `}`），
  剥离所有 `// [!code ...]` 行级指令与 region 标记，并 **dedent 去公共缩进**
  （与 VitePress 一致，避免代码整体右移）。
- GitHub alert（`> [!TIP]` 等）与容器（`::: info/tip/warning/danger/details`、
  `code-group`）统一渲染为带色块的提示框。
- 图片 `![](x){data-zoomable}` 的属性指令会被剔除；本地与远程图片均支持。

## 深入文档

维护者 / AI Agent 请阅读同目录的 [`AGENTS.md`](./AGENTS.md)，其中包含设计方法、
数据流、两遍渲染与页号机制、后续开发指南、验证回归清单与已知陷阱速查。

## 备注

字体子集脚本 `build-fonts.ts` 是**纯 Bun/JS**：用 `subset-font`（harfbuzz）从 Google Fonts
的 glyf 型可变字体「子集 + 钉轴」生成静态 TTF，无需 Python 或任何 CFF→glyf 转换。仅在重新
生成字体时运行；CI 与日常 `bun pdf` 只消费已提交的子集 TTF。
