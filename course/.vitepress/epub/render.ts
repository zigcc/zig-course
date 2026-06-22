import MarkdownIt from "markdown-it";
import type { Options as MarkdownItOptions } from "markdown-it";
import type Renderer from "markdown-it/lib/renderer.mjs";
import type Token from "markdown-it/lib/token.mjs";
import { createHighlighter, type Highlighter } from "shiki";
import type { EpubConfig } from "./config.ts";
import { slugify } from "./links.ts";

/** 转义 XML 文本 */
export function escapeXml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/** 将 markdown-it 输出的 HTML 修正为合法 XHTML（自闭合 void 元素、转义裸 &） */
export function htmlToXhtml(html: string): string {
  html = html.replace(
    /<(br|hr|img|meta|link|input|area|base|col|embed|source|track|wbr)\b([^>]*?)\s*(?<!\/)>/gi,
    (_m, tag, attrs) => `<${tag}${attrs} />`,
  );
  html = html.replace(/&(?!#?[a-zA-Z0-9]+;)/g, "&amp;");
  return html;
}

/** 包装为完整的 XHTML 文档 */
export function wrapXhtml(
  title: string,
  bodyInner: string,
  lang: string,
): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="${lang}" lang="${lang}">
<head>
  <meta charset="UTF-8"/>
  <title>${escapeXml(title)}</title>
  <link rel="stylesheet" type="text/css" href="../styles/style.css"/>
</head>
<body>
${bodyInner}
</body>
</html>`;
}

/** 创建已配置好 Shiki 高亮与中文锚点的 markdown-it 实例 */
export async function createRenderer(config: EpubConfig): Promise<MarkdownIt> {
  const highlighter: Highlighter = await createHighlighter({
    themes: [config.shikiTheme],
    langs: config.shikiLangs,
  });

  const md: MarkdownIt = new MarkdownIt({
    html: true,
    linkify: true,
    breaks: false,
    highlight(code, lang) {
      const loaded = highlighter.getLoadedLanguages();
      const useLang = loaded.includes(lang as any) ? lang : "text";
      try {
        return highlighter.codeToHtml(code, {
          lang: useLang,
          theme: config.shikiTheme,
        });
      } catch {
        return `<pre class="shiki"><code>${md.utils.escapeHtml(code)}</code></pre>`;
      }
    },
  });

  // 标题加 id（中文 slug），并做每文档去重，避免同页重复 ID（与 VitePress 行为一致）
  md.renderer.rules.heading_open = function (
    tokens: Token[],
    idx: number,
    options: MarkdownItOptions,
    env: { slugCounts?: Record<string, number> },
    self: Renderer,
  ) {
    const token = tokens[idx]!;
    const inline = tokens[idx + 1];
    const text = inline && inline.type === "inline" ? inline.content : "";
    let id = slugify(text);
    if (id) {
      const counts: Record<string, number> = (env.slugCounts ??= {});
      if (counts[id] === undefined) counts[id] = 0;
      else id = `${id}-${++counts[id]}`;
      token.attrSet("id", id);
    }
    return self.renderToken(tokens, idx, options);
  };

  return md;
}
