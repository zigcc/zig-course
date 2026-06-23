// scripts/pdf/parse.ts
// 把一篇 VitePress markdown 解析为 token 列表，供 jsPDF 渲染器消费。
// 处理顺序：
//   step A: 去除 front matter
//   step B: 全局展开代码引用 <<<@/code/...（无论是否在容器内）
//   step B2: 处理 GitHub 风格 alert（> [!TIP] 等）
//   step C: 处理容器 ::: info/tip/...（含 code-group）
//           容器渲染为：标记行 [[ADMONITION:type:title]] + 内部原样内容 + [[/ADMONITION]]
//   step D: 剥离图片/链接后的 {data-zoomable} 等 VitePress 属性指令
import { marked, type Token, type Tokens } from "marked";
import { resolveCodeImport } from "./utils.js";

/** 自定义的提示框 token：收拢容器/alert 内部内容。 */
export interface AdmonitionToken {
  type: "admonition";
  admType: string;
  title: string;
  tokens: PdfToken[];
}

/** 渲染器消费的 token：marked 原生 token 或自定义 admonition token。 */
export type PdfToken = Token | AdmonitionToken;

// step B: 展开代码引用
async function expandCodeImports(
  lines: string[],
  courseDir: string,
): Promise<string[]> {
  const out: string[] = [];
  for (const line of lines) {
    if (/^\s*<<</.test(line)) {
      const res = await resolveCodeImport(line.trim(), courseDir);
      if (res) {
        out.push("```" + res.lang);
        out.push(...res.code.split("\n"));
        out.push("```");
        continue;
      }
    }
    out.push(line);
  }
  return out;
}

// GitHub alert 类型映射到 admonition 类型
const ALERT_MAP: Record<string, string> = {
  NOTE: "tip",
  TIP: "tip",
  IMPORTANT: "info",
  WARNING: "warning",
  CAUTION: "danger",
  DETAILS: "details",
};

// 清洗提示框标题：去掉 emoji/符号等装饰（字体子集不含 emoji，否则会显示为缺字形并把文字推偏），
// 并折叠多余空白、去首尾。
export function cleanAdmonitionTitle(raw: string | undefined): string {
  return (raw || "")
    .replace(
      /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{200D}]/gu,
      "",
    )
    .replace(/\s+/g, " ")
    .trim();
}

// step B2: 处理 GitHub 风格 alert（> [!TIP] 等多行 blockquote）
function transformGithubAlerts(lines: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^>\s*\[!([A-Z]+)\]\s*(.*)$/);
    if (!m || !ALERT_MAP[m[1]]) {
      out.push(lines[i]);
      continue;
    }
    const type = ALERT_MAP[m[1]];
    const title = cleanAdmonitionTitle(m[2]);
    const body: string[] = [];
    let j = i + 1;
    while (j < lines.length && /^>/.test(lines[j])) {
      body.push(lines[j].replace(/^>\s?/, ""));
      j++;
    }
    out.push("");
    out.push(`[[ADMONITION:${type}:${title}]]`);
    out.push("");
    out.push(...body);
    out.push("");
    out.push("[[/ADMONITION]]");
    out.push("");
    i = j - 1;
  }
  return out;
}

// step C: 处理容器
// VitePress 允许用 3 个及以上冒号作为 fence（多个冒号用于嵌套）。
// 采用栈跟踪 fence 层级。code-group 也作为一种容器入栈（仅去标记，不包裹）。
interface FenceFrame {
  kind: "admonition" | "plain";
  len: number;
}

function transformContainers(lines: string[]): string[] {
  const out: string[] = [];
  const stack: FenceFrame[] = [];
  const TYPE_RE = /^\s*(:{3,})\s*(info|tip|warning|danger|details)\s*(.*)$/;
  const GROUP_RE = /^\s*(:{3,})\s*(code-group|raw|v-pre)\b.*$/;
  const CLOSE_RE = /^\s*(:{3,})\s*$/;

  const closeTop = (): void => {
    const top = stack.pop();
    if (top && top.kind === "admonition") {
      out.push("");
      out.push("[[/ADMONITION]]");
      out.push("");
    }
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    const tm = line.match(TYPE_RE);
    const gm = !tm ? line.match(GROUP_RE) : null;
    if (tm || gm) {
      const len = (tm || gm)![1].length;
      // 遇到新容器开启时，先闭合栈中“同级或更内层”（fence 长度 >= 新长度）的未闭合容器。
      while (stack.length && stack[stack.length - 1].len >= len) closeTop();
      if (tm) {
        const type = tm[2];
        const title = tm[3];
        out.push("");
        out.push(`[[ADMONITION:${type}:${cleanAdmonitionTitle(title)}]]`);
        out.push("");
        stack.push({ kind: "admonition", len });
      } else {
        stack.push({ kind: "plain", len });
      }
      continue;
    }

    const cm = line.match(CLOSE_RE);
    if (cm) {
      const len = cm[1].length;
      while (stack.length && stack[stack.length - 1].len > len) closeTop();
      if (stack.length) closeTop();
      continue;
    }

    out.push(line);
  }
  // 容错：未闭合的 admonition 自动补结束标记
  while (stack.length) closeTop();
  return out;
}

// step E: 仅在非代码围栏区，把成对的 **文本** 改写为 <strong>文本</strong>，
// 绕过 marked 对 CJK 相邻 ** 的 flanking 解析限制。
// 为避免误伤代码块（如其他语言里的 **），逐行扫描并跳过 ``` / ~~~ 围栏内部。
export function fixCjkStrong(lines: string[]): string[] {
  let inFence = false;
  let fenceMark = "";
  return lines.map((ln) => {
    const fence = ln.match(/^\s*(```+|~~~+)/);
    if (fence) {
      if (!inFence) {
        inFence = true;
        fenceMark = fence[1][0];
      } else if (fence[1][0] === fenceMark) {
        inFence = false;
        fenceMark = "";
      }
      return ln;
    }
    if (inFence) return ln;
    // 跳过行内代码 `...`：先用占位符保护，替换后再还原，避免动到代码里的 **
    const codeSpans: string[] = [];
    let protectedLine = ln.replace(/`[^`]*`/g, (m) => {
      codeSpans.push(m);
      return `\u0000${codeSpans.length - 1}\u0000`;
    });
    // 成对、非贪婪、内部不含 ** 的加粗 -> <strong>
    protectedLine = protectedLine.replace(
      /\*\*(?!\s)([^*\n]+?)(?<!\s)\*\*/g,
      "<strong>$1</strong>",
    );
    // 还原行内代码
    protectedLine = protectedLine.replace(
      /\u0000(\d+)\u0000/g,
      (_m, i) => codeSpans[Number(i)],
    );
    return protectedLine;
  });
}

export async function preprocess(
  content: string,
  courseDir: string,
): Promise<string> {
  let lines = content.split("\n");
  // step A: front matter
  if (lines[0]?.trim() === "---") {
    let end = 1;
    while (end < lines.length && lines[end].trim() !== "---") end++;
    lines = lines.slice(end + 1);
  }
  // step B: 代码引用展开
  lines = await expandCodeImports(lines, courseDir);
  // step B2: GitHub alert
  lines = transformGithubAlerts(lines);
  // step C: 容器
  lines = transformContainers(lines);
  // step D: 剔除图片/链接后的 VitePress 属性指令（如 ![](x.png){data-zoomable}）
  lines = lines.map((ln) =>
    ln.replace(/(!?\[[^\]]*\]\([^)]*\))\{[^}]*\}/g, "$1"),
  );
  // step E: 修复 CJK 相邻的 **加粗** 解析失败
  // CommonMark 的强调定界符（flanking）规则在 ** 被 CJK 标点/文字包夹时会判定其无效，
  // 导致 marked 原样输出字面 **。这里在非代码区把 **文本** 改写为 <strong>文本</strong>，
  // marked 会将其拆为 html 标签 token，再由渲染器消费为加粗（见 renderer 的 flatten）。
  lines = fixCjkStrong(lines);
  return lines.join("\n");
}

// token 化：把 [[ADMONITION]] 标记转成自定义 token（支持嵌套）。
export async function parseMarkdown(
  content: string,
  courseDir: string,
): Promise<PdfToken[]> {
  const md = await preprocess(content, courseDir);
  const rawTokens = marked.lexer(md);

  const tokenText = (t: Token): string =>
    t && (t.type === "paragraph" || t.type === "text")
      ? (t as Tokens.Paragraph | Tokens.Text).text || ""
      : "";

  let i = 0;
  function collapse(): PdfToken[] {
    const acc: PdfToken[] = [];
    while (i < rawTokens.length) {
      const t = rawTokens[i];
      const text = tokenText(t);
      const open = text.match(/^\[\[ADMONITION:(\w+):(.*)\]\]$/);
      if (open) {
        const type = open[1];
        const title = open[2];
        i++; // 消费开启标记
        const inner = collapse(); // 递归收拢内层
        acc.push({ type: "admonition", admType: type, title, tokens: inner });
        continue;
      }
      if (/^\[\[\/ADMONITION\]\]$/.test(text)) {
        i++; // 消费结束标记并返回上一层
        return acc;
      }
      acc.push(t);
      i++;
    }
    return acc;
  }
  return collapse();
}
