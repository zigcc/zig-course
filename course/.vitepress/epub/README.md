# EPub 导出工具

将本仓库（VitePress 教程）一键导出为符合 **EPUB 3.3** 规范的电子书。纯 TypeScript 实现，运行于 Bun，**无 Python 等外部运行时依赖**。

## 使用

```bash
bun install   # 安装依赖（首次）
bun run epub  # 生成 zig-course.epub（输出在仓库根目录）
```

构建产物默认写入仓库根目录的 `zig-course.epub`，可在 `config.ts` 中调整。

## 特性

| 能力 | 说明 |
| --- | --- |
| 章节顺序 | 直接复用 `course/.vitepress/sidebar.ts`，与网站目录保持一致 |
| 代码高亮 | 使用 [Shiki](https://shiki.style/)，与网站同款主题，支持 Zig |
| 代码片段导入 | 支持 `<<<@/code/xxx.zig#region` 语法（含 region 提取、行内 label） |
| 容器语法 | `::: info / tip / warning / danger / details` 与 GitHub 警告块 `> [!TIP]` 均转为带样式的提示框 |
| 自定义字体 | 与 PDF 同方案：**思源宋体**（中文）+ **Inter**（正文英文，无衬线）+ **JetBrains Mono**（代码）；均取自 Google Fonts 的 glyf 可变字体，按全书字符即时子集 + 钉轴（woff2） |
| 图片嵌入 | 本地 / 远程图片全部内嵌；SVG、WebP 统一栅格化为 PNG（兼容所有阅读器） |
| 站内跳转 | md 间链接重写为电子书内部章节跳转，页内/跨章锚点自动校验，**不会跳到网页** |
| 规范校验 | 通过官方 EPUBCheck 5.1.0：0 错误 / 0 警告 |

## 目录结构

```
course/.vitepress/epub/
├── build.ts        # 入口：串联全流程
├── config.ts       # 配置（书名、作者、字体 URL、Shiki 语言等）
├── sidebar.ts      # 解析 sidebar.ts -> 有序章节 + 路由映射
├── preprocess.ts   # VitePress 专有语法 -> 标准 Markdown
├── render.ts       # markdown-it + Shiki + 中文锚点；XHTML 包装
├── links.ts        # 链接/图片重写、slugify
├── images.ts       # 图片收集、下载、统一转 PNG（sharp + resvg）
├── fonts.ts        # 字体下载 + 子集化 + 钉轴（subset-font，输出 woff2）
├── package.ts      # 组装 EPUB3（JSZip）：OPF / nav / spine
├── style.css       # 电子书样式
└── .cache/         # 字体下载缓存（已 gitignore）
```

## 配置项

编辑 `config.ts` 即可调整书名、作者、输出路径、Shiki 主题与语言、字体来源等。例如新增一种代码语言的高亮，只需把语言 id 加入 `shikiLangs`。

## 实现要点（便于后续维护）

- **每文档锚点去重**：同一页出现重名标题时，后续标题的 `id` 会追加 `-1`、`-2`，与 VitePress 行为一致，避免 EPUBCheck 的重复 ID 报错。
- **图片统一 PNG**：远程图片可能 URL 后缀是 `.png` 实则为 WebP，EPUBCheck 会按文件头严格校验；统一转 PNG 可根除 `OPF-029`/`PKG-021`。
- **锚点兜底**：跨章/页内锚点在打包前会校验目标 `id` 是否真实存在，不存在则降级为指向页首，避免 `RSC-012`。
- **mimetype**：作为 ZIP 第一项且不压缩（`STORE`），符合 OCF 要求。

## 依赖

| 包 | 用途 |
| --- | --- |
| `markdown-it` | Markdown 渲染 |
| `shiki` | 代码高亮 |
| `jszip` | EPUB 打包 |
| `subset-font` | 字体子集化 + 钉轴 |
| `@resvg/resvg-js` | SVG 栅格化为 PNG |
| `sharp` | 位图（WebP/JPG/GIF）转 PNG |
