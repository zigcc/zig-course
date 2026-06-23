// scripts/pdf/main.ts
// 主入口：读取项目 sidebar -> 逐页解析 markdown -> jsPDF 渲染 -> 绑定链接 -> 写书签 -> 输出。
//
// 运行方式（已在 package.json 注册）：
//   bun pdf            # 全量构建 -> books/zig_course.pdf
//   bun pdf:sample     # 仅渲染几篇代表性页面，快速验证
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { DefaultTheme } from "vitepress";
import { flattenSidebar, type FlatNode } from "./utils.js";
import { parseMarkdown } from "./parse.js";
import { PdfRenderer } from "./renderer.js";
import { initHighlighter } from "./highlight.js";
// 直接复用项目同一份 sidebar 数据源（与网页目录完全一致），不再 eval TS。
import sidebar from "../../course/.vitepress/sidebar.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "../..");
const COURSE = path.join(ROOT, "course");
const OUT_DIR = path.join(ROOT, "books");

// 支持 --sample 只渲染几篇代表性页面用于快速验证
const SAMPLE = process.argv.includes("--sample");
const SAMPLE_ROUTES = [
  "/hello-world", // 含代码导入 <<<@/code/...#anchor
  "/basic/advanced_type/pointer", // 含图片 + 站内跳转
  "/basic/error_handle", // 含代码、容器
  "/advanced/comptime", // code-group
];

// 排除路由：仅排除 /code/（纯代码片段目录，非正文页面，由正文以 <<<@ 引用导入）。
// appendix / update / about / epilogue 等正文章节均收入 PDF。
const EXCLUDE: RegExp[] = [/^\/code\//];

interface Bookmark {
  level: number;
  node: unknown;
}

async function main(): Promise<void> {
  await mkdir(OUT_DIR, { recursive: true });
  await initHighlighter();

  const fontCjk = (
    await readFile(path.join(ROOT, "assets/fonts/zigcourse-cjk.ttf"))
  ).toString("base64");
  const fontSans = (
    await readFile(path.join(ROOT, "assets/fonts/zigcourse-sans.ttf"))
  ).toString("base64");
  const fontMono = (
    await readFile(path.join(ROOT, "assets/fonts/zigcourse-mono.ttf"))
  ).toString("base64");

  let nodes: FlatNode[] = flattenSidebar(sidebar as DefaultTheme.SidebarItem[]);
  // 仅对页面节点应用排除；分组节点保留（其下无页面会被自动跳过）。
  nodes = nodes.filter(
    (n) => n.isGroup || !EXCLUDE.some((re) => re.test(n.route!)),
  );
  if (SAMPLE)
    nodes = nodes.filter((n) => !n.isGroup && SAMPLE_ROUTES.includes(n.route!));

  const pageCount = nodes.filter((n) => !n.isGroup).length;
  console.log(`将渲染 ${pageCount} 个页面${SAMPLE ? "（样例模式）" : ""}`);

  const renderer = new PdfRenderer({
    fontCjk,
    fontSans,
    fontMono,
    courseDir: COURSE,
  });

  const outline = (renderer.doc as any).outline;
  const bookmarkStack: Bookmark[] = [];

  // 分组节点的书签延迟创建：等其下第一个页面渲染完才知道起始页。
  const pendingGroups: FlatNode[] = [];
  const addBookmark = (
    level: number,
    title: string,
    pageNumber: number,
  ): unknown => {
    while (
      bookmarkStack.length &&
      bookmarkStack[bookmarkStack.length - 1].level >= level
    ) {
      bookmarkStack.pop();
    }
    const parent = bookmarkStack.length
      ? bookmarkStack[bookmarkStack.length - 1].node
      : null;
    const node = outline.add(parent, title, { pageNumber });
    bookmarkStack.push({ level, node });
    return node;
  };

  for (const nd of nodes) {
    if (nd.isGroup) {
      pendingGroups.push(nd);
      continue;
    }
    const route = nd.route!;
    const mdPath = path.join(COURSE, route + ".md");
    const altPath = path.join(COURSE, route, "index.md");
    const file = existsSync(mdPath)
      ? mdPath
      : existsSync(altPath)
        ? altPath
        : null;
    if (!file) {
      console.warn(`✗ 找不到：${route}`);
      continue;
    }
    const content = await readFile(file, "utf-8");
    const tokens = await parseMarkdown(content, COURSE);
    await renderer.renderPage(route, nd.title, tokens);
    const startPage = renderer.routeStart.get(route)!;

    // 先创建之前暂存的分组书签（指向本页起始页）
    for (const g of pendingGroups) addBookmark(g.level, g.title, startPage);
    pendingGroups.length = 0;

    // 再创建页面书签
    addBookmark(nd.level, nd.title, startPage);
    console.log(`✓ ${route} -> p.${startPage}`);
  }

  renderer.finalize();

  const outFile = path.join(
    OUT_DIR,
    SAMPLE ? "zig_course_sample.pdf" : "zig_course.pdf",
  );
  const buf = renderer.output();
  await writeFile(outFile, buf);
  console.log(
    `\n已生成：${outFile}  共 ${renderer.page} 页，${(buf.length / 1024 / 1024).toFixed(1)} MB`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
