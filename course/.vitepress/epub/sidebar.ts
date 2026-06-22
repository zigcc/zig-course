import path from "node:path";
import { existsSync } from "node:fs";
import sidebar from "../sidebar.ts";
import type { EpubConfig } from "./config.ts";

export interface FlatItem {
  level: number;
  text: string;
  link?: string;
}

interface SidebarNode {
  text: string;
  link?: string;
  items?: SidebarNode[];
  collapsed?: boolean;
}

/** 将 sidebar 树扁平化为有序列表，保留层级用于目录缩进 */
export function flattenSidebar(): FlatItem[] {
  const out: FlatItem[] = [];
  const walk = (nodes: SidebarNode[], level: number) => {
    for (const node of nodes) {
      out.push({ level, text: node.text, link: node.link });
      if (node.items) walk(node.items, level + 1);
    }
  };
  walk(sidebar as unknown as SidebarNode[], 0);
  return out;
}

/** 把 VitePress route 规范化为以 / 开头、无扩展名的键 */
export function normalizeRouteKey(link: string): string {
  let r = link.split("#")[0];
  if (r === "") r = "/";
  r = r.replace(/\.(md|html)$/, "");
  if (r !== "/" && !r.startsWith("/")) r = "/" + r;
  return r;
}

/** route -> 相对 courseDir 的 md 文件路径 */
export function routeToMdPath(link: string): string {
  let route = link.split("#")[0];
  if (route === "" || route === "/") return "index.md";
  if (route.startsWith("/")) route = route.slice(1);
  route = route.replace(/\.(md|html)$/, "");
  return route + ".md";
}

export interface Chapter {
  item: FlatItem;
  route: string;
  mdPath: string;
  fileName: string;
}

/** 解析出有序章节列表，并构建 route -> xhtml 文件名 映射 */
export function resolveChapters(config: EpubConfig): {
  chapters: Chapter[];
  routeToFile: Record<string, string>;
} {
  const flat = flattenSidebar();
  const chapters: Chapter[] = [];
  const routeToFile: Record<string, string> = {};
  const seen = new Set<string>();
  let counter = 0;

  for (const item of flat) {
    if (!item.link) continue;
    const route = normalizeRouteKey(item.link);
    if (seen.has(route)) continue;
    const mdPath = path.join(config.courseDir, routeToMdPath(item.link));
    if (!existsSync(mdPath)) {
      console.warn(`[epub] 跳过：找不到 md 文件 ${mdPath}（route ${route}）`);
      continue;
    }
    seen.add(route);
    counter++;
    const fileName = `chapter-${String(counter).padStart(3, "0")}.xhtml`;
    chapters.push({ item, route, mdPath, fileName });
    routeToFile[route] = fileName;
    if (route !== "/") routeToFile[route + "/"] = fileName;
  }

  return { chapters, routeToFile };
}

/** 层级目录节点：保留 sidebar 的父/子结构用于生成嵌套 TOC */
export interface NavNode {
  text: string;
  /** 对应章节的 xhtml 文件名；分组节点（无可解析链接）则为空 */
  href?: string;
  children: NavNode[];
}

/**
 * 按 sidebar 原始树构建层级目录。
 * - 有 link 且能解析到章节的节点 -> 带 href 的可点击项；
 * - 分组节点（仅有 items、无 link）-> 无 href 的标题项，其下嵌套子节点；
 * - 既无法链接又无子节点的空节点跳过。
 */
export function buildNavTree(routeToFile: Record<string, string>): NavNode[] {
  const conv = (nodes: SidebarNode[]): NavNode[] => {
    const out: NavNode[] = [];
    for (const node of nodes) {
      const children = node.items ? conv(node.items) : [];
      let href: string | undefined;
      if (node.link) {
        const route = normalizeRouteKey(node.link);
        href = routeToFile[route] || routeToFile[route + "/"];
      }
      if (!href && children.length === 0) continue;
      out.push({ text: node.text, href, children });
    }
    return out;
  };
  return conv(sidebar as unknown as SidebarNode[]);
}
