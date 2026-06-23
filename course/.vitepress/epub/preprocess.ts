// Markdown 预处理：将 VitePress 专有语法转换为标准 markdown-it 可渲染的内容
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

/** 去除 frontmatter */
export function stripFrontmatter(md: string): string {
  return md.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "");
}

const SNIPPET_RE = /^<<<\s*(.+)$/gm;

function dedent(lines: string[]): string[] {
  const indents = lines
    .filter((l) => l.trim().length > 0)
    .map((l) => l.match(/^\s*/)?.[0].length ?? 0);
  const min = indents.length ? Math.min(...indents) : 0;
  return min > 0 ? lines.map((l) => l.slice(min)) : lines;
}

function extractRegion(source: string, region: string): string | null {
  const lines = source.split(/\r?\n/);
  const start = lines.findIndex((l) => l.includes(`#region ${region}`));
  if (start < 0) return null;
  const end = lines.findIndex(
    (l, i) => i > start && l.includes(`#endregion ${region}`),
  );
  if (end < 0) return null;
  return dedent(lines.slice(start + 1, end)).join("\n");
}

function langFromFile(p: string): string {
  const base = path.basename(p);
  if (base === "build.zig.zon") return "zig";
  const ext = path.extname(p).slice(1);
  return ext || "text";
}

/**
 * 展开 VitePress 代码片段导入：`<<<@/code/foo.zig#region{lang} [label]`
 * 语法参考 https://vitepress.dev/zh/guide/markdown#import-code-snippets
 */
function readSnippet(rawSpec: string, courseDir: string): string {
  const [spec, ...labelParts] = rawSpec.split(/\s+/);
  const label = labelParts.join(" ").replace(/^\[(.*)\]$/, "$1");
  const langOverride = spec.match(/\{([\w-]+)\}$/)?.[1];
  const specNoLang = spec.replace(/\{[\w-]+\}$/, "");
  const [rawFile, region] = specNoLang.split("#", 2);
  const filePath = rawFile.startsWith("@/") ? rawFile.slice(2) : rawFile;
  const sourcePath = path.resolve(courseDir, filePath);
  if (!existsSync(sourcePath)) return `<!-- Missing snippet: ${rawSpec} -->`;
  const source = readFileSync(sourcePath, "utf8");
  const code = region ? extractRegion(source, region) : source.trimEnd();
  if (code === null) return `<!-- Missing region: ${rawSpec} -->`;
  const lang = langOverride ?? langFromFile(sourcePath);
  const title = label ? `**${label}**\n\n` : "";
  return `${title}\`\`\`${lang}\n${code.trimEnd()}\n\`\`\``;
}

export function expandSnippets(md: string, courseDir: string): string {
  return md.replace(SNIPPET_RE, (_m, spec) =>
    readSnippet(String(spec).trim(), courseDir),
  );
}

const LABELS: Record<string, string> = {
  info: "提示",
  tip: "技巧",
  warning: "注意",
  danger: "警告",
  details: "详情",
  important: "重要",
  caution: "警示",
};

/** 将 VitePress 容器（::: info / tip / warning / danger / details / code-group）转换为带 class 的 div */
export function transformContainers(md: string): string {
  const lines = md.split(/\r?\n/);
  const out: string[] = [];
  const stack: string[] = [];

  for (const line of lines) {
    const open = line.match(/^:{3,}\s*([\w-]+)\s*(.*)$/);
    // 容许缩进的关闭围栏（课程里存在 `  :::` 这种缩进写法）
    const close = /^\s*:{3,}\s*$/.test(line);

    if (open && open[1]) {
      const type = open[1].toLowerCase();
      const title = open[2].trim();
      if (type === "code-group") {
        stack.push("code-group");
        out.push("");
        continue;
      }
      const known = [
        "info",
        "tip",
        "warning",
        "danger",
        "details",
        "important",
        "caution",
      ];
      const cls = known.includes(type) ? type : "info";
      const heading = title || LABELS[cls] || "提示";
      out.push(`<div class="callout callout-${cls}">`);
      out.push(`<p class="callout-title">${heading}</p>`);
      out.push("");
      stack.push("div");
      continue;
    }

    if (close && stack.length) {
      const top = stack.pop();
      if (top === "div") {
        out.push("");
        out.push("</div>");
      }
      continue;
    }

    out.push(line);
  }
  while (stack.length) {
    if (stack.pop() === "div") out.push("</div>");
  }
  return out.join("\n");
}

/** GitHub 风格警告块（`> [!NOTE|TIP|IMPORTANT|WARNING|CAUTION]`）转换为带 class 的 callout div */
const GH_ALERT: Record<string, string> = {
  note: "info",
  tip: "tip",
  important: "important",
  warning: "warning",
  caution: "caution",
};

export function transformGithubAlerts(md: string): string {
  const lines = md.split(/\r?\n/);
  const out: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^>\s*\[!(\w+)\]\s*(.*)$/);
    if (!m) {
      out.push(lines[i]);
      continue;
    }
    const cls = GH_ALERT[m[1].toLowerCase()] || "info";
    // 收集紧随的 blockquote 行作为正文，去掉前导 `> `
    const body: string[] = [];
    let j = i + 1;
    for (; j < lines.length && /^>/.test(lines[j]); j++) {
      body.push(lines[j].replace(/^>\s?/, ""));
    }
    const heading = m[2].trim() || LABELS[cls] || "提示";
    out.push(`<div class="callout callout-${cls}">`);
    out.push(`<p class="callout-title">${heading}</p>`);
    out.push("", ...body, "");
    out.push("</div>");
    i = j - 1;
  }
  return out.join("\n");
}

/** code-group 内部 ```lang [tab] 转换为代码块上方粗体标题 */
export function transformCodeGroupTabs(md: string): string {
  return md.replace(/^```([\w-]+)\s+\[([^\]]+)\]\s*$/gm, (_m, lang, tab) => {
    return `**${tab}**\n\n\`\`\`${lang}`;
  });
}

/**
 * 去除紧跟在图片/链接后的 markdown-it-attrs 属性块，如：
 *   ![alt](src){data-zoomable}
 * VitePress 用 markdown-it-attrs 把 `{...}` 解析为 HTML 属性（如点击放大），
 * 但本工具不支持该插件，若不处理会被当作纯文本渲染（显示出 `{data-zoomable}`）。
 * 仅匹配“以 `)` 结尾的图片/链接 + 紧随的 `{...}`”，避免误伤 Zig 代码里的 `T{ ... }`。
 */
export function stripImageAttrs(md: string): string {
  return md.replace(/(!?\[[^\]]*\]\([^)]*\))\{[^}\n]*\}/g, "$1");
}

/**
 * 修复 CJK 相邻的 **加粗** 解析失败。
 * CommonMark 的强调定界符（flanking）规则在 ** 被 CJK 标点/文字包夹时会判定其无效，
 * 导致 markdown-it 原样输出字面 **（例如“。**文本。**”）。
 * 这里在非代码区把 **文本** 改写为 <strong>文本</strong>；markdown-it 开启了 html:true，
 * 会原样保留该标签，阅读器会正常加粗。
 * 为避免误伤代码块（其他语言里的 **），逐行扫描并跳过 ``` / ~~~ 围栏内部；
 * 同时跳过行内代码 `...` 中的内容。
 */
export function fixCjkStrong(md: string): string {
  let inFence = false;
  let fenceChar = "";
  let fenceLen = 0;
  return md
    .split(/\r?\n/)
    .map((ln) => {
      const fence = ln.match(/^\s*(```+|~~~+)/);
      if (fence) {
        const char = fence[1][0];
        const len = fence[1].length;
        // CommonMark：围栏只能被同字符、且不短于开栏的围栏闭合
        if (!inFence) {
          inFence = true;
          fenceChar = char;
          fenceLen = len;
        } else if (char === fenceChar && len >= fenceLen) {
          inFence = false;
          fenceChar = "";
          fenceLen = 0;
        }
        return ln;
      }
      if (inFence) return ln;
      const codeSpans: string[] = [];
      let s = ln.replace(/`[^`]*`/g, (m) => {
        codeSpans.push(m);
        return `\u0000${codeSpans.length - 1}\u0000`;
      });
      // 允许内部出现单个 *（如 Zig 指针 *T / *p），但不吞掉作定界的 **
      s = s.replace(
        /\*\*(?!\s)((?:[^*\n]|\*(?!\*))+?)(?<!\s)\*\*/g,
        "<strong>$1</strong>",
      );
      s = s.replace(/\u0000(\d+)\u0000/g, (_m, i) => codeSpans[Number(i)]);
      return s;
    })
    .join("\n");
}

/** 完整预处理管线 */
export function preprocess(md: string, courseDir: string): string {
  md = stripFrontmatter(md);
  md = expandSnippets(md, courseDir);
  md = transformGithubAlerts(md);
  md = transformCodeGroupTabs(md);
  md = transformContainers(md);
  md = stripImageAttrs(md);
  md = fixCjkStrong(md);
  return md;
}
