// scripts/pdf/utils.ts
// 各类解析/归一化工具：sidebar、站内链接、代码引用、图片路径。
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import type { DefaultTheme } from "vitepress";

/** 扁平化后的有序节点：对应一个页面或一个纯分组标题。 */
export interface FlatNode {
  /** 页面路由（形如 "/basic/xxx"）；纯分组标题为 null。 */
  route: string | null;
  /** 显示标题（用于书签）。 */
  title: string;
  /** 层级深度（0 为顶层）。 */
  level: number;
  /** true 表示无对应 md 页面的纯分组标题，仅用于书签层级。 */
  isGroup: boolean;
}

/** 归一化后的站内链接目标。 */
export interface InternalTarget {
  route: string;
  anchor: string;
}

/** 代码引用解析结果。 */
export interface CodeImport {
  lang: string;
  code: string;
}

/** 图片路径解析结果：本地文件或远程 URL。 */
export interface ResolvedImage {
  localPath?: string;
  url?: string;
}

// ---------- sidebar -> 有序页面列表 ----------
// 返回有序节点列表。isGroup=true 表示纯分组标题（无对应 md 页面，仅用于书签层级）。
// 与 VitePress 侧边栏目录完全一致，同时保留带 link 的页面与不带 link 的分组。
export function flattenSidebar(sidebar: DefaultTheme.SidebarItem[]): FlatNode[] {
  const nodes: FlatNode[] = [];
  function walk(items: DefaultTheme.SidebarItem[], level: number): void {
    for (const item of items) {
      const hasLink = !!item.link;
      if (hasLink) {
        const route =
          item.link === "/" ? "/index" : item.link!.replace(/\.md$/, "");
        nodes.push({ route, title: item.text ?? route, level, isGroup: false });
      } else if (item.text) {
        nodes.push({ route: null, title: item.text, level, isGroup: true });
      }
      if (item.items) walk(item.items as DefaultTheme.SidebarItem[], level + 1);
    }
  }
  walk(sidebar, 0);
  return nodes;
}

// ---------- 站内链接归一化 ----------
// 把各种相对/绝对链接转成 { route, anchor }，route 形如 "/basic/xxx"。
// 返回 null 表示这是外链（http/https/mailto）或无法解析。
export function normalizeInternalLink(
  href: string | undefined,
  currentRoute: string,
): InternalTarget | null {
  if (!href) return null;
  if (/^https?:\/\//.test(href) || href.startsWith("mailto:")) return null;

  // 纯页内锚点 #xxx
  if (href.startsWith("#")) {
    return { route: currentRoute, anchor: decodeURIComponent(href.slice(1)) };
  }

  const parts = href.split("#");
  let pathPart = parts[0];
  const anchor = parts[1] ? decodeURIComponent(parts[1]) : "";
  pathPart = pathPart.replace(/\.md$/, "").replace(/\.html$/, "");

  let route: string;
  if (pathPart.startsWith("/")) {
    route = pathPart;
  } else {
    const baseDir = path.posix.dirname(currentRoute);
    route = path.posix.normalize(path.posix.join(baseDir, pathPart));
  }
  if (route !== "/" && route.endsWith("/")) route = route.slice(0, -1);
  return { route, anchor };
}

// ---------- 标题 -> 锚点 id（与 VitePress 一致：转小写、空格转-、去标点）----------
export function slugify(text: string): string {
  return String(text)
    .trim()
    .toLowerCase()
    .replace(/[\s]+/g, "-")
    .replace(/[^\w\u4e00-\u9fa5-]/g, ""); // 保留中文、字母数字、连字符
}

// ---------- 图片路径解析 ----------
// 返回本地绝对文件路径；网络图返回 { url } 由调用方下载/缓存。
export function resolveImagePath(
  src: string,
  currentRoute: string,
  courseDir: string,
): ResolvedImage {
  if (/^https?:\/\//.test(src)) {
    // 尝试把官方站点图映射回本地资源
    const m = src.match(/course\.ziglang\.cc\/(.*)$/);
    if (m) {
      const local = path.join(courseDir, "public", m[1]);
      if (existsSync(local)) return { localPath: local };
      const local2 = path.join(courseDir, m[1]);
      if (existsSync(local2)) return { localPath: local2 };
    }
    return { url: src };
  }
  let p: string;
  if (src.startsWith("/")) {
    // public 资源：/picture/xxx -> course/public/picture/xxx 或 course/picture/xxx
    p = path.join(courseDir, "public", src);
    if (!existsSync(p)) p = path.join(courseDir, src.slice(1));
  } else {
    const baseDir = path.join(courseDir, path.posix.dirname(currentRoute));
    p = path.join(baseDir, src);
  }
  return { localPath: p };
}

// ---------- 剥离 VitePress 代码块行级指令 ----------
// 处理 // [!code focus] / [!code highlight] / [!code ++] / [!code --] /
// [!code warning] / [!code error] / [!code focus:n] / [!code word:xxx] 等。
// 这些指令可能独占一行注释，也可能紧跟在代码或另一段注释之后（如
// `// 获取writer句柄// [!code focus]`），需统一移除指令本身并清理多余空白。
function stripCodeDirectives(line: string): string {
  let out = line.replace(/\s*\/\/\s*\[!code[^\]]*\]/g, "");
  out = out.replace(/[ \t]+$/g, "");
  return out;
}

// 判断某行是否是 region / endregion 标记行（可带前导代码，如 `} // #endregion two`）；
// 返回标记前的代码部分（去掉标记注释），无标记返回 null。
function splitRegionMarker(
  line: string,
  kind: "region" | "endregion",
): string | null {
  const re = new RegExp(`(.*?)\\s*\\/\\/\\s*#${kind}\\b.*$`);
  const m = line.match(re);
  if (!m) return null;
  return m[1];
}

// 去掉数组首尾的空白行，但保留中间空行。
function trimBlankEdges(arr: string[]): string[] {
  let s = 0;
  let e = arr.length;
  while (s < e && arr[s].trim() === "") s++;
  while (e > s && arr[e - 1].trim() === "") e--;
  return arr.slice(s, e);
}

// 去掉所有行的公共最小前导缩进（与 VitePress 代码片段导入的 dedent 行为一致）。
// 仅统计非空行的前导空白长度，空行不参与计算且按比例裁剪，避免出现负切片。
function dedent(arr: string[]): string[] {
  let min = Infinity;
  for (const l of arr) {
    if (l.trim() === "") continue; // 空行不参与公共缩进计算
    const lead = l.match(/^[ \t]*/)?.[0].length ?? 0;
    if (lead < min) min = lead;
  }
  if (!isFinite(min) || min === 0) return arr;
  return arr.map((l) => (l.trim() === "" ? l : l.slice(min)));
}

// ---------- 代码引用解析 <<<@/code/release/file.zig#anchor ----------
export async function resolveCodeImport(
  line: string,
  courseDir: string,
): Promise<CodeImport | null> {
  const m = line.match(/^<<<\s*(\S+?)(?:#([\w-]+))?(?:\s*\[([^\]]*)\])?\s*$/);
  if (!m) return null;
  const ref = m[1];
  const anchor = m[2];
  const rel = ref.replace(/^@\//, "");
  const absFile = path.join(courseDir, rel);
  const ext = path.extname(absFile).slice(1) || "text";
  const lang = ext === "zig" ? "zig" : ext;
  if (!existsSync(absFile)) return { lang, code: `// 文件不存在: ${rel}` };
  const src = await readFile(absFile, "utf-8");
  const lines = src.split("\n");

  // 无 anchor：导入整个文件，剥离 region 标记行与行级指令，保留代码与空行
  if (!anchor) {
    const out: string[] = [];
    for (const l of lines) {
      if (/\/\/\s*#(region|endregion)\b/.test(l)) {
        const before =
          splitRegionMarker(l, "region") ?? splitRegionMarker(l, "endregion");
        if (before && before.trim()) out.push(stripCodeDirectives(before));
        continue;
      }
      out.push(stripCodeDirectives(l));
    }
    return { lang, code: dedent(trimBlankEdges(out)).join("\n") };
  }

  // 指定 anchor：提取 #region <anchor> ... #endregion <anchor> 之间的内容
  const out: string[] = [];
  let depth = 0;
  const startRe = new RegExp(`\\/\\/\\s*#region\\s+${anchor}\\b`);
  const endRe = new RegExp(`\\/\\/\\s*#endregion\\s+${anchor}\\b`);
  for (const l of lines) {
    // 起始标记：直接开启收集
    if (startRe.test(l)) {
      depth = 1;
      continue;
    }
    // 结束标记：关键修复——可能形如 `} // #endregion two`，需保留标记前的代码
    if (endRe.test(l)) {
      if (depth > 0) {
        const before = splitRegionMarker(l, "endregion");
        if (before && before.trim()) out.push(stripCodeDirectives(before));
      }
      depth = 0;
      continue;
    }
    if (depth > 0) {
      // 跳过内部嵌套的其它 region/endregion 标记行，但保留其携带的代码
      if (/\/\/\s*#(region|endregion)\b/.test(l)) {
        const before =
          splitRegionMarker(l, "region") ?? splitRegionMarker(l, "endregion");
        if (before && before.trim()) out.push(stripCodeDirectives(before));
        continue;
      }
      out.push(stripCodeDirectives(l));
    }
  }
  return { lang, code: dedent(trimBlankEdges(out)).join("\n") };
}
