// scripts/pdf/highlight.ts
// 使用 Shiki（VitePress 同款高亮引擎）将代码 token 化为带颜色的片段，
// 供 jsPDF 逐 token 着色绘制。仅取 token 的 {content, color}，不生成 HTML。
import { createHighlighter, type Highlighter } from "shiki";

/** 单个高亮片段：一段连续同色文本。 */
export interface HlPiece {
  content: string;
  color: string;
}
/** 一行高亮结果由若干片段组成；整段代码即行数组。 */
export type HlLine = HlPiece[];

// 课程中实际出现的语言（其余回退到纯文本）
const LANGS = [
  "zig",
  "c",
  "cpp",
  "bash",
  "shellscript",
  "powershell",
  "python",
  "json",
  "diff",
  "asm",
] as const;

// 语言别名归一化
const LANG_ALIAS: Record<string, string> = {
  sh: "bash",
  shell: "bash",
  zsh: "bash",
  txt: "text",
  text: "text",
  "": "text",
};

const THEME = "github-light";

let _hl: Highlighter | null = null;

async function getHighlighter(): Promise<Highlighter> {
  if (_hl) return _hl;
  _hl = await createHighlighter({ themes: [THEME], langs: [...LANGS] });
  return _hl;
}

/** 预初始化（在渲染开始前调用一次）。 */
export async function initHighlighter(): Promise<void> {
  await getHighlighter();
}

/**
 * 将代码高亮为按行的彩色 token 数组，保留原始空格与缩进。
 * 失败或不支持的语言：每行作为单一灰黑 token 返回（仍保留缩进）。
 */
export function highlightToLines(code: string, lang: string): HlLine[] {
  const hl = _hl;
  const normLang = LANG_ALIAS[lang] ?? lang ?? "text";
  if (
    !hl ||
    normLang === "text" ||
    !hl.getLoadedLanguages().includes(normLang)
  ) {
    return code
      .split("\n")
      .map((line) => [{ content: line, color: "#24292E" }]);
  }
  try {
    const { tokens } = hl.codeToTokens(code, {
      lang: normLang as Parameters<typeof hl.codeToTokens>[1]["lang"],
      theme: THEME,
    });
    return tokens.map((line) =>
      line.map((t) => ({ content: t.content, color: t.color || "#24292E" })),
    );
  } catch {
    return code
      .split("\n")
      .map((line) => [{ content: line, color: "#24292E" }]);
  }
}

/** #RRGGBB -> [r,g,b] */
export function hexToRgb(hex: string): [number, number, number] {
  const h = (hex || "#24292E").replace("#", "");
  const n =
    h.length === 3
      ? h
          .split("")
          .map((c) => c + c)
          .join("")
      : h.padEnd(6, "0").slice(0, 6);
  return [
    parseInt(n.slice(0, 2), 16),
    parseInt(n.slice(2, 4), 16),
    parseInt(n.slice(4, 6), 16),
  ];
}
