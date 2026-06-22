# AGENTS.md — zig-course PDF 导出器

> 本文件面向后续维护本目录的 **AI Agent / LLM** 与 **人类开发者**。
> 阅读后应能：理解整体设计、在不破坏既有特性的前提下扩展功能、把工具集成进
> zig-course（VitePress）项目，并避开已知的若干隐蔽陷阱。
>
> 适用范围：`scripts/pdf/` 目录下的全部代码。修改本目录代码时请优先遵循本文件的约定。

---

## 1. 这是什么

一个**不依赖无头浏览器**的离线 PDF 生成器，把整套 zig-course 课程渲染为带书签、
可点击站内/外链的单一 PDF（`PDF/zig_course.pdf`）。它替代了旧的
`vitepress-export-pdf`（基于 Puppeteer）方案。

核心实现思路：直接复用项目的 `course/.vitepress/sidebar.ts` 作为目录与顺序的**唯一数据源**，
逐篇读取 Markdown → 预处理与分词（`marked`）→ 用 [`jsPDF`](https://github.com/parallax/jsPDF)
矢量绘制 → 收集并绑定跳转链接 → 写入 PDF outline（书签）→ 输出文件。代码高亮使用
VitePress 同款的 [Shiki](https://shiki.style/) 引擎。

### 运行方式

```bash
bun pdf          # 全量构建 -> PDF/zig_course.pdf
bun pdf:sample   # 仅渲染几篇代表页 -> PDF/zig_course_sample.pdf（快速验证，秒级）
```

两个脚本都通过 [Bun](https://bun.sh) **直接执行 TypeScript**（`bun run scripts/pdf/main.ts`），
无需预编译或 tsx。类型检查（不产出文件）：

```bash
node_modules/.bin/tsc --noEmit -p scripts/pdf/tsconfig.json
```

---

## 2. 目录与模块职责

| 文件              | 职责                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `main.ts`         | 入口：`import sidebar`，扁平化为有序节点，逐页渲染，创建 PDF 书签（outline），写出文件      |
| `parse.ts`        | Markdown **预处理 + 分词**：展开代码引用、转换 GitHub alert、解析 VitePress 容器，产出 token |
| `renderer.ts`     | **核心布局引擎**：标题/段落/列表/表格/代码块/图片/提示框/引用块绘制，链接坐标收集与最终绑定 |
| `highlight.ts`    | 用 Shiki 把代码着色为 `{content, color}` 片段（只取 token 颜色，不生成 HTML）              |
| `utils.ts`        | sidebar 扁平化、站内链接归一化、`slugify`、图片路径解析、代码引用 `<<<@/...` 解析 + dedent  |
| `tsconfig.json`   | 仅供本目录 `tsc --noEmit` 类型检查与编辑器使用，**不参与** VitePress 构建                   |
| `README.md`       | 面向使用者的简明说明                                                                        |
| `AGENTS.md`       | 本文件，面向维护者/Agent 的深入说明                                                         |

> 模块依赖方向（无环）：`main → {parse, renderer, highlight, utils}`；
> `parse → utils`；`renderer → {utils, highlight, parse(类型)}`。

---

## 3. 数据流（端到端）

```
sidebar.ts
   │  flattenSidebar()               (utils.ts)
   ▼
FlatNode[]  ──filter EXCLUDE/SAMPLE──►  有序页面/分组节点          (main.ts)
   │  对每个页面节点 route:
   │    readFile(route.md)
   ▼
parseMarkdown(content, courseDir)                                  (parse.ts)
   │  预处理 step A→D（见 §4）后 marked.lexer，再把 [[ADMONITION]] 收拢为自定义 token
   ▼
PdfToken[]
   │  renderer.renderPage(route, title, tokens)                    (renderer.ts)
   │    renderTokens() 按 token.type 分发到各 drawXxx；
   │    标题登记 anchors，页面登记 routeStart，链接坐标入 pendingLinks
   ▼
（全部页面渲染完）
   │  renderer.finalize()   用 anchors/routeStart 把 pendingLinks 绑定为 doc.link 跳转
   │  main.ts 同步用 outline.add() 写书签
   ▼
renderer.output()  ->  PDF/zig_course.pdf
```

---

## 4. Markdown 预处理管线（`parse.ts` 的 `preprocess`）

按**固定顺序**执行，顺序不可随意调换：

1. **step A — 去除 front matter**：删除文件开头 `--- ... ---` 区块。
2. **step B — 展开代码引用**：把 `<<<@/code/xxx.zig#anchor` 行替换为对应代码 fence。
   实际抽取在 `utils.resolveCodeImport`（见 §6）。
3. **step B2 — GitHub alert**：把 `> [!NOTE|TIP|IMPORTANT|WARNING|CAUTION|DETAILS]`
   多行 blockquote 转成统一的 `[[ADMONITION:type:title]] ... [[/ADMONITION]]` 标记块。
4. **step C — VitePress 容器**：用**栈**跟踪 `::: info/tip/warning/danger/details`、
   `code-group/raw/v-pre`（支持 `:::` 数量 ≥3 的嵌套）。提示类容器转成 `[[ADMONITION]]` 标记块；
   `code-group` 等仅去除围栏标记、保留内部内容。
5. **step D — 剔除属性指令**：去掉图片/链接尾部的 `{data-zoomable}`、`{.class}` 等 VitePress 属性。

之后 `parseMarkdown` 调用 `marked.lexer`，再用递归的 `collapse()` 把文本里的
`[[ADMONITION:...]] / [[/ADMONITION]]` 标记**收拢为嵌套的 `admonition` 自定义 token**。

> **设计动机**：把"容器/alert"在文本层先归一成统一标记，避免在 `marked` token 树里
> 处理 VitePress 私有语法；渲染器只需认识一种 `admonition` token。

---

## 5. 渲染引擎要点（`renderer.ts`）

### 5.1 坐标系与单位

- 单位为 **mm**（`new jsPDF({ unit: "mm", format: "a4" })`）。A4 = 210×297mm，页边距见 `MARGIN`。
- **字号是 pt**，坐标是 mm。两者换算 `1pt ≈ 0.3528mm`。涉及"按字号计算垂直偏移"时
  **必须显式换算**（如列表圆点的 `dotCy`），不要把 pt 当 mm 直接相加——这是历史 bug 来源。

### 5.2 三字体与正文/代码分流

构造时加载三套 glyf 型 TrueType 字体：

- `CJK`（思源宋体）→ 中文与 CJK 标点；
- `Sans`（Inter）→ **正文英文/数字**（无衬线比例字体）；
- `Mono`（JetBrains Mono）→ **代码块与行内代码**（等宽）。

分流规则（`isCjk(ch)` 逐字符判定 + 是否代码上下文）：CJK 字符走 `CJK`；代码（fence 代码块、
`codespan` 行内代码）走 `Mono`；其余正文拉丁走 `Sans`。字体子集**不含 emoji**，因此提示框
标题会先经 `cleanAdmonitionTitle` 去除 emoji，否则会出现缺字形并把文字推偏。

> 字体由 `build-fonts.ts`（纯 Bun/JS，`subset-font`/harfbuzz）从 Google Fonts 的 glyf 型
> **可变字体**「子集 + 钉轴（wght=400 等）」生成静态 TTF。**jsPDF 只能内嵌 glyf 型 TrueType**，
> 三个源（Noto Serif SC / Inter / JetBrains Mono）都是 glyf，无需任何 CFF→glyf 转换。
> 换字体务必选 glyf 型来源（CFF/OTF 会被 jsPDF 静默拒绝、渲染空白）。

### 5.3 两遍链接绑定（核心机制）

jsPDF 顺序绘制、无法回溯修改链接。因此采用"**先收集坐标，最后统一绑定**"：

- 渲染时：标题登记到 `anchors`（key = `` `${route}#${slug}` ``），页面登记到 `routeStart`，
  每个站内链接的矩形热区入 `pendingLinks`（含其所在页 `page`）。
- `finalize()`：对每个 `pendingLink` 查 `anchors[route#anchor]` → 退化到 `anchors[route#]`（页首）
  → 再退化到 `routeStart[route]`，命中后 `doc.setPage(link.page)` 并 `doc.link(...)` 绑定跳转。

### 5.4 页号的真实来源：`curPage()`（务必理解）

存在两个"页号"：

- `this.page`：**内部计数器**，`newPage()` 时自增，用于跨页测高的增量判断；
- `doc.getCurrentPageInfo().pageNumber`：jsPDF **文档真实页号**。

两者可能因两遍渲染产生 1 页漂移。**所有"用于记录跳转目标 / 链接热区"的页号必须用
`curPage()`**（real 阶段返回真实页号，dry 阶段返回内部计数）。历史上曾因为用 `this.page`
记录锚点导致**全书站内跳转整体错一页**，已通过 `curPage()` 修复。新增任何"登记 anchor /
routeStart / pendingLink.page"的代码，一律用 `curPage()`，不要用 `this.page`。

### 5.5 两遍渲染（提示框 / 引用块）

提示框（`drawAdmonition`）与引用块（`drawBlockquote`）需要**先知道内容总高**才能画底框，
所以采用"**dry-run 测高 → 回滚 → real 绘制**"：

- `this._dry = true` 时：`newPage()` 不真正 `addPage()`，drawXxx 不绘制、不写 anchor、不入链接；
- 回滚时 `snap` 同时记录 `page`（内部计数，供跨页增量判断）与 `realPage`（`curPage()`，供
  `doc.setPage(snap.realPage)` **精确回滚到真实页**）。回滚用 `realPage` 而非 `page`——
  混用会导致 `setPage` 跳错页、进而链接错页。
- 跨页时：当前页底部补一段左竖条，保持视觉连续。

> **维护规则**：任何新增的"需要先测高再绘制背景框"的块，都应复用该 dry/real 模式，并严格
> 按上面方式记录与回滚 `snap`。

### 5.6 token 分发表（`renderTokens`）

| token.type   | 处理方法           | 说明                                            |
| ------------ | ------------------ | ----------------------------------------------- |
| `heading`    | `drawHeading`      | 登记 anchor；支持标题内含行内链接/代码          |
| `paragraph`  | `drawParagraph`    | 行内混排；返回其中的图片交由 `drawImage`        |
| `code`       | `drawCode`         | Shiki 着色 + 自动换行 + 续行缩进 + 灰底圆角框   |
| `list`       | `drawList`         | 有序/无序/嵌套，矢量圆点或数字编号              |
| `blockquote` | `drawBlockquote`   | 两遍渲染，淡灰底 + 左竖条                        |
| `admonition` | `drawAdmonition`   | 两遍渲染，按类型配色（tip/info/warning/...）    |
| `table`      | `drawTable`        | 单元格内容扁平化后按列宽换行渲染                |
| `hr`         | `hr`               | 分隔线                                          |
| `space`      | —                  | 纵向间距                                        |
| `image`      | `drawImage`        | sharp 栅格化为 PNG（SVG/远程图均支持）          |
| `text`       | `drawInline`       | 兜底行内                                        |

---

## 6. 代码引用解析（`utils.resolveCodeImport`）

语法：`<<<@/code/<path>#<anchor> [meta]`。处理规则：

- **`#anchor` 区间提取**：抓取源文件中 `// #region <anchor>` 与 `// #endregion <anchor>`
  之间的内容；无 `#anchor` 时导入整文件并剥离全部 region 标记。
- **保留行尾式结束标记前的代码**：形如 `} // #endregion two` 会**保留 `}`**（只去掉标记注释）。
- **剥离行级指令**：`stripCodeDirectives` 移除所有 `// [!code focus|highlight|++|--|warning|error|focus:n|word:xxx]`
  变体，无论独占注释还是紧跟在代码/注释之后。
- **`dedent`（与 VitePress 一致）**：去除区间内所有非空行的**公共最小前导缩进**，避免代码整体右移；
  内部相对缩进保留。空行不参与计算。
- **`trimBlankEdges`**：去首尾空行、保留中间空行（维持代码逻辑分组）。

> 历史 bug 提醒：早期缺 `dedent` → 作用域内的代码片段在 PDF 里整体偏右；早期把整行
> region 结束标记当作跳过 → 丢失闭合 `}`。改这块时请用 `bun pdf:sample` 渲染 hello-world /
> error_handle 页核对闭合括号与左对齐。

---

## 7. 与 zig-course 项目的集成

1. **同源 sidebar**：`main.ts` 直接 `import sidebar from "../../course/.vitepress/sidebar.js"`，
   PDF 目录顺序与网页侧边栏**永远一致**，无需维护第二份顺序表。
2. **排除路由**：`main.ts` 的 `EXCLUDE` 当前**仅排除 `/code/`**（纯代码片段目录，由正文以
   `<<<@` 引用导入，本身不是正文页面）。`appendix / update / about / epilogue` 等章节
   **均收入 PDF**。如需调整收录范围，改 `EXCLUDE` 即可。
3. **字体**：读取 `zigcourse-cjk.ttf`（Noto Serif SC=思源宋体同源）、`zigcourse-sans.ttf`（Inter）、
   `zigcourse-mono.ttf`（JetBrains Mono），均为子集化的静态 glyf TrueType，由 `build-fonts.ts`
   生成（见 §5.2）。更换字体需同为可被 jsPDF 解析的 glyf TrueType。
4. **npm 脚本**：`package.json` 已注册 `pdf` / `pdf:sample`（`bun run scripts/pdf/main.ts`）
   与 `pdf:fonts`（重新生成子集字体）。
5. **运行时依赖**：`shiki`、`jspdf`、`marked`、`sharp`（均在 `devDependencies`）；用 Bun 直接跑 TS。
   字体子集脚本 `build-fonts.ts` 另需 `subset-font`（纯 JS，已在 `devDependencies`），仅在重新生成字体时使用。

---

## 8. 后续开发指南

### 8.1 新增一种"提示框/容器"类型

1. `parse.ts`：在 `ALERT_MAP`（GitHub alert）或 `transformContainers` 的 `TYPE_RE` 中登记新类型。
2. `renderer.ts`：在 `drawAdmonition` 的 `styles` / `defaultTitles` 增加配色与默认标题。
3. 用 `bun pdf:sample` 渲染含该容器的页面核对。

### 8.2 支持一种新的行内/块级 Markdown 语法

- 行内（强调、行内代码、链接等）：扩展 `drawInline` / `measureMixed`。
- 块级：在 `renderTokens` 的 `switch` 增加分支，并实现对应 `drawXxx`。若需要背景框，复用 §5.5 的两遍渲染模式。

### 8.3 新增代码语言高亮

在 `highlight.ts` 的 `LANGS` 加入 Shiki 语言 id（必要时在 `LANG_ALIAS` 加别名）。未注册的语言会回退为纯文本（仍保留缩进）。

### 8.4 调整页面收录范围

改 `main.ts` 的 `EXCLUDE`（正则数组，匹配 `route`）。注意分组节点（`isGroup`）不参与排除，
其下若无页面会自动跳过。

### 8.5 改动须遵守的硬性约束

- **页号一律用 `curPage()`** 登记锚点 / 链接（见 §5.4）。
- **pt↔mm 必须显式换算**（见 §5.1）。
- **两遍渲染**的回滚用 `snap.realPage` 精确 `setPage`（见 §5.5）。
- dry-run 期间**不得**绘制、写 anchor 或入 pendingLinks（用 `if (!this._dry)` 守卫）。
- 保持模块依赖无环；新增工具函数优先放 `utils.ts`。
- 改完必须通过 `tsc --noEmit` 与 `prettier --check`，并用 `bun pdf:sample` 做视觉回归。

---

## 9. 验证与回归

每次改动后建议执行：

```bash
# 1) 类型检查
node_modules/.bin/tsc --noEmit -p scripts/pdf/tsconfig.json
# 2) 代码风格
node_modules/.bin/prettier --check "scripts/pdf/*.ts"
# 3) 快速视觉回归（秒级）
bun pdf:sample
# 4) 全量构建
bun pdf
```

**视觉回归关注点**（用 `pdftoppm` 渲染对应页人工核对）：

- 代码块：闭合 `}` 是否完整、是否左对齐（dedent）、续行缩进、语法高亮、空行分组；
- 提示框/引用块：底框与左竖条是否完整覆盖整段、跨页是否补竖条；
- 列表：圆点与 CJK 文字是否垂直居中对齐；
- 站内链接：随机抽取若干 GoTo，确认落点是页面/小节**标题**而非代码行中间（错页自检）；
- 书签层级是否与 sidebar 一致。

**裸标记自检**（产物中以下标记应全部为 0）：`[!code`、`<<<`、`:::`、`#region`、
`#endregion`、`zoomable`、`[[ADMONITION`。

---

## 10. 已知陷阱速查

| 现象                                   | 根因 / 修复                                                        |
| -------------------------------------- | ----------------------------------------------------------------- |
| 站内跳转整体错 1 页                     | 用 `this.page` 而非 `curPage()` 登记锚点；改用 `curPage()`         |
| 代码块整体右移                          | 代码片段缺 `dedent`；在导入返回前 `dedent(trimBlankEdges(...))`    |
| 代码块缺少闭合 `}`                      | 把 `} // #endregion x` 整行当跳过；需保留标记前代码               |
| 提示框只剩半截竖条 / 无底框             | 未用两遍渲染测高，或 dry 期间误绘制                                |
| 列表圆点偏上/偏下                       | pt 当 mm 直接相加；`dotCy` 需 `size * k * 0.3528` 换算            |
| 提示框标题出现缺字形方块                | 标题含 emoji；`cleanAdmonitionTitle` 未生效或字体不含该字形        |
| 中文/英文整页空白、字体不显示           | 字体是 CFF/OTF，jsPDF 静默拒绝；换 glyf 型来源（见 §5.2）          |
| 新加字符渲染为缺字形方块                | 子集未含该字形；改完课程文本后重跑 `bun pdf:fonts`               |
