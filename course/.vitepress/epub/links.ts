import path from "node:path";

/**
 * 将标题文本转为锚点 slug。
 * 与 VitePress 默认使用的 @mdit-vue slugify 行为对齐：转小写、空白转连字符、保留中文。
 */
export function slugify(text: string): string {
  return text
    .normalize("NFKD")
    .trim()
    .toLowerCase()
    .replace(/[\s]+/g, "-")
    .replace(/[^\w\u4e00-\u9fa5\-]/g, "")
    .replace(/\-+/g, "-")
    .replace(/^\-|\-$/g, "");
}

export type RouteMap = Record<string, string>;

/** 把相对/绝对链接规范化为以 / 开头、无扩展名的 route */
export function normalizeRoute(href: string, currentRoute: string): string {
  let route = href;
  if (!route.startsWith("/")) {
    const dir = path.posix.dirname(currentRoute);
    route = path.posix.normalize(path.posix.join(dir, route));
    if (!route.startsWith("/")) route = "/" + route;
  }
  route = route.replace(/\.(md|html)$/, "");
  route = route.replace(/\/index$/, "/");
  return route;
}

/**
 * 重写章节 HTML 中的链接与图片：
 * - 外部链接：补 target=_blank
 * - 页内锚点：保留（slug 已在标题渲染时生成）
 * - 站内 md 链接：替换为对应 xhtml 文件名 + 锚点
 * - 图片：交给 collectImage 收集（返回 epub 内相对路径）
 */
export function rewriteLinksAndImages(
  html: string,
  currentRoute: string,
  routeToFile: RouteMap,
  collectImage: (spec: string) => string,
  courseDir: string,
): string {
  // 链接
  html = html.replace(
    /<a\b([^>]*?)href="([^"]+)"([^>]*)>/g,
    (_m, pre, href, post) => {
      if (/^(https?:|mailto:|tel:)/i.test(href)) {
        return `<a${pre}href="${href}"${post} target="_blank">`;
      }
      if (href.startsWith("#")) {
        const anchor = decodeURIComponent(href.slice(1));
        return `<a${pre}href="#${anchor}"${post}>`;
      }
      const [rawPath, rawHash] = href.split("#");
      const route = normalizeRoute(rawPath, currentRoute);
      const file = routeToFile[route] || routeToFile[route + "/"];
      if (!file) return `<a${pre}href="#"${post}>`;
      const hash = rawHash ? `#${decodeURIComponent(rawHash)}` : "";
      return `<a${pre}href="${file}${hash}"${post}>`;
    },
  );

  // 图片
  html = html.replace(
    /<img\b([^>]*?)src="([^"]+)"([^>]*)>/g,
    (_m, pre, src, post) => {
      if (/^https?:/i.test(src)) {
        return `<img${pre}src="${collectImage("REMOTE::" + src)}"${post}>`;
      }
      const candidates: string[] = [];
      if (src.startsWith("/")) {
        candidates.push(path.join(courseDir, src)); // course 根，如 /picture/...
        candidates.push(path.join(courseDir, "public", src)); // public 根
      } else {
        const dir = path.posix.dirname(currentRoute);
        const routePath = path.posix.normalize(path.posix.join(dir, src));
        candidates.push(path.join(courseDir, routePath));
      }
      return `<img${pre}src="${collectImage("CANDIDATES::" + candidates.join("|"))}"${post}>`;
    },
  );

  return html;
}
