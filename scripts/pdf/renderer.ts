// scripts/pdf/renderer.ts
// 基于 jsPDF 的布局渲染引擎。
// 两遍渲染策略：
//   Pass 1：渲染全文，记录每个页面 route + 每个标题 anchor 所在的 PDF 页码 / Y 坐标，
//           同时收集所有需要解析的站内链接 { route, anchor, rect, srcPage }。
//   Pass 2：用第一遍得到的 anchor 位置表，把链接绑定到目标页（doc.link 跳转）。
// 由于 jsPDF 是顺序绘制，无法回溯改链接，所以采用“先收集链接坐标，最后统一 setLink”的方式。
import { jsPDF } from "jspdf";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import sharp, { type Metadata } from "sharp";
import type { Token, Tokens } from "marked";
import {
  slugify,
  normalizeInternalLink,
  resolveImagePath,
  type InternalTarget,
} from "./utils.js";
import { highlightToLines, hexToRgb, type HlLine } from "./highlight.js";
import type { PdfToken, AdmonitionToken } from "./parse.js";

const A4 = { w: 210, h: 297 } as const;
const MARGIN = { top: 20, bottom: 20, left: 18, right: 18 } as const;
const CONTENT_W = A4.w - MARGIN.left - MARGIN.right;

/** 待绑定的站内链接坐标记录。 */
interface PendingLink {
  page: number;
  x: number;
  y: number;
  w: number;
  h: number;
  target: InternalTarget;
}

/** anchor 位置：所在 PDF 页码与 Y 坐标。 */
interface AnchorPos {
  page: number;
  y: number;
}

/** 行内绘制选项。 */
interface InlineOpts {
  size?: number;
  fontName?: string;
  lineH?: number;
  indent?: number;
  currentRoute?: string;
}

/** renderTokens 的上下文（容器内缩进/字号/代码块偏移）。 */
interface RenderCtx {
  indent?: number;
  size?: number;
  codeOffset?: number;
}

/** 任意带 tokens 字段的 inline token 兼容形态。 */
type InlineToken =
  | Token
  | { type: string; text?: string; tokens?: Token[]; href?: string };

/** 构造参数。 */
export interface RendererOptions {
  fontCjk: string; // base64 — 思源宋体（中文正文）
  fontSans: string; // base64 — Inter（正文英文/数字，无衬线比例字体）
  fontMono: string; // base64 — JetBrains Mono（代码/行内代码，等宽）
  courseDir: string;
}

export class PdfRenderer {
  readonly doc: jsPDF;
  readonly courseDir: string;
  y: number;
  page: number;
  /** anchor 位置表：key = `${route}#${anchor}`。 */
  readonly anchors: Map<string, AnchorPos>;
  /** route 起始页：key = route。 */
  readonly routeStart: Map<string, number>;
  /** 待绑定的链接。 */
  readonly pendingLinks: PendingLink[];
  private imgCache: Map<string, Buffer>;
  /** 干跑测高标志（提示框两遍渲染用）。 */
  private _dry = false;
  /** 单元格默认字色（标题渲染时临时覆盖）。 */
  private _cellDefaultColor: [number, number, number] | null = null;

  constructor({ fontCjk, fontSans, fontMono, courseDir }: RendererOptions) {
    this.courseDir = courseDir;
    this.doc = new jsPDF({ unit: "mm", format: "a4" });
    // 三字体（均为 glyf TrueType，jsPDF 可解析）：
    //   CJK  = 思源宋体 Source Han Serif  -> 中文与 CJK 标点
    //   Sans = Inter                      -> 正文英文 / 数字（无衬线比例字体）
    //   Mono = JetBrains Mono             -> 代码块 / 行内代码（等宽）
    this.doc.addFileToVFS("CJK.ttf", fontCjk);
    this.doc.addFont("CJK.ttf", "CJK", "normal");
    this.doc.addFileToVFS("Sans.ttf", fontSans);
    this.doc.addFont("Sans.ttf", "Sans", "normal");
    this.doc.addFileToVFS("Mono.ttf", fontMono);
    this.doc.addFont("Mono.ttf", "Mono", "normal");
    this.doc.setFont("CJK", "normal");

    this.y = MARGIN.top;
    this.page = 1;
    this.anchors = new Map();
    this.routeStart = new Map();
    this.pendingLinks = [];
    this.imgCache = new Map();
  }

  // ---------- 基础排版 ----------
  // 返回用于“记录跳转目标/链接坐标”的真实页号：
  // dry-run 阶段不绘制也不绑定链接，用内部计数即可；real 阶段以 jsPDF 文档的
  // 当前页号为准，避免 this.page 与文档实际页数因两遍渲染产生漂移导致链接整体错页。
  curPage(): number {
    if (this._dry) return this.page;
    return this.doc.getCurrentPageInfo().pageNumber;
  }
  newPage(): void {
    // 干跑测高阶段只推进页计数/重置 y，不真正新建页面，避免产生残留空白页
    if (!this._dry) this.doc.addPage();
    this.page += 1;
    this.y = MARGIN.top;
  }
  ensureSpace(h: number): void {
    if (this.y + h > A4.h - MARGIN.bottom) this.newPage();
  }
  setSize(pt: number): void {
    this.doc.setFontSize(pt);
  }

  // 判断是否 CJK 字符（含中文标点 / 全角），用于字体分流
  isCjk(ch: string): boolean {
    const o = ch.codePointAt(0) ?? 0;
    return (
      (o >= 0x4e00 && o <= 0x9fff) ||
      (o >= 0x3400 && o <= 0x4dbf) ||
      (o >= 0xf900 && o <= 0xfaff) ||
      (o >= 0x3000 && o <= 0x303f) ||
      (o >= 0xff00 && o <= 0xffef)
    );
  }

  // 测量一段混排文本宽度（中文走 CJK，其余走指定字体）
  measureMixed(text: string, latinFont: string): number {
    let w = 0;
    for (const ch of text) {
      const fn = this.isCjk(ch) ? "CJK" : latinFont;
      this.doc.setFont(fn, "normal");
      w += this.doc.getTextWidth(ch);
    }
    return w;
  }

  // 计算当前字号下每行可容纳并自动换行（支持中英文混排）
  wrapText(text: string, maxW: number, latinFont = "Sans"): string[] {
    const words: string[] = [];
    let buf = "";
    for (const ch of text) {
      if (this.isCjk(ch)) {
        if (buf) {
          words.push(buf);
          buf = "";
        }
        words.push(ch);
      } else if (ch === " ") {
        if (buf) {
          words.push(buf);
          buf = "";
        }
        words.push(" ");
      } else {
        buf += ch;
      }
    }
    if (buf) words.push(buf);

    const lines: string[] = [];
    let line = "";
    for (const w of words) {
      const test = line + w;
      if (this.measureMixed(test, latinFont) > maxW && line) {
        lines.push(line);
        line = w === " " ? "" : w;
      } else {
        line = test;
      }
    }
    if (line) lines.push(line);
    return lines;
  }

  // 在指定 (x, y) 绘制一整行混排文本（不换行），CJK 走 CJK 字体、拉丁走指定字体。
  drawMixedLine(
    text: string,
    x: number,
    y: number,
    latinFont = "Sans",
  ): number {
    let cx = x;
    let buf = "";
    let bufCjk: boolean | null = null;
    const flush = (): void => {
      if (!buf) return;
      const fn = bufCjk ? "CJK" : latinFont;
      this.doc.setFont(fn, "normal");
      if (!this._dry) this.doc.text(buf, cx, y);
      cx += this.doc.getTextWidth(buf);
      buf = "";
    };
    for (const ch of text) {
      const c = this.isCjk(ch);
      if (bufCjk === null) bufCjk = c;
      if (c !== bufCjk) {
        flush();
        bufCjk = c;
      }
      buf += ch;
    }
    flush();
    return cx;
  }

  // 绘制一段富文本（含行内链接），返回结束 y。
  drawInline(tokens: InlineToken[], opts: InlineOpts = {}): number {
    const {
      size = 11,
      fontName = "CJK",
      lineH = 6,
      indent = 0,
      currentRoute = "",
    } = opts;
    this.setSize(size);
    const startX = MARGIN.left + indent;
    const maxW = CONTENT_W - indent;

    // 把 inline tokens 拍平为 [{text, link?, code?, bold?}] 片段
    interface Seg {
      text: string;
      code?: boolean;
      link?: string;
      bold?: boolean;
    }
    const segs: Seg[] = [];
    // boldDepth 用计数器跟踪嵌套的加粗/斜体（含 html <strong>/<em> 标签），
    // 兼容 marked 正常解析出的 strong/em，以及预处理转写出的 html 标签。
    const flatten = (
      toks: InlineToken[],
      link?: string,
      boldDepth = 0,
    ): void => {
      for (const t of toks) {
        const tt = t as any;
        if (tt.type === "link") {
          flatten(
            tt.tokens || [{ type: "text", text: tt.text }],
            tt.href,
            boldDepth,
          );
        } else if (tt.type === "strong" || tt.type === "em") {
          flatten(
            tt.tokens || [{ type: "text", text: tt.text }],
            link,
            boldDepth + 1,
          );
        } else if (tt.type === "html") {
          // 处理预处理转写出的 <strong>/<em> 标签（成对出现），标签本身不输出文本
          const raw = (tt.text ?? tt.raw ?? "").trim().toLowerCase();
          if (/^<(strong|b|em|i)>$/.test(raw)) {
            boldDepth++;
          } else if (/^<\/(strong|b|em|i)>$/.test(raw)) {
            boldDepth = Math.max(0, boldDepth - 1);
          }
          // 其他 html 原样忽略（与原行为一致：不输出标签文本）
        } else if (tt.type === "codespan") {
          segs.push({ text: tt.text, code: true, link, bold: boldDepth > 0 });
        } else if (tt.tokens) {
          flatten(tt.tokens, link, boldDepth);
        } else {
          segs.push({
            text: tt.text ?? tt.raw ?? "",
            link,
            bold: boldDepth > 0,
          });
        }
      }
    };
    flatten(tokens);

    let x = startX;
    this.ensureSpace(lineH);
    let curY = this.y;
    const cjkFont = fontName;

    const placeChar = (
      s: string,
      isCode: boolean | undefined,
      link?: string,
      bold?: boolean,
    ): void => {
      const units: string[] = [];
      let buf2 = "";
      for (const ch of s) {
        // 软换行/制表/回车等空白统一视为空格，避免相邻行首尾粘连导致叠字
        const c2 = /\s/.test(ch) ? " " : ch;
        if (this.isCjk(c2)) {
          if (buf2) {
            units.push(buf2);
            buf2 = "";
          }
          units.push(c2);
        } else if (c2 === " ") {
          if (buf2) {
            units.push(buf2);
            buf2 = "";
          }
          units.push(" ");
        } else buf2 += c2;
      }
      if (buf2) units.push(buf2);

      for (const piece of units) {
        // CJK 走 CJK 字体；正文英文走无衬线 Sans；行内代码走等宽 Mono
        const isCjkPiece = this.isCjk(piece[0] || "");
        const fn = isCode ? "Mono" : isCjkPiece ? cjkFont : "Sans";
        this.doc.setFont(fn, "normal");
        const w = this.doc.getTextWidth(piece);
        if (x + w > startX + maxW && piece !== " ") {
          x = startX;
          curY += lineH;
          if (curY > A4.h - MARGIN.bottom) {
            this.newPage();
            curY = this.y;
          }
        }
        if (link && !this._dry) {
          const norm = normalizeInternalLink(link, currentRoute);
          if (norm) {
            this.pendingLinks.push({
              page: this.curPage(),
              x,
              y: curY - size * 0.3528,
              w,
              h: lineH,
              target: norm,
            });
          } else {
            this.doc.link(x, curY - size * 0.3528, w, lineH, { url: link });
          }
          this.doc.setTextColor(20, 90, 200);
        }
        if (!this._dry) {
          if (bold) {
            // 伪粗体：用填充 + 描边模式加粗笔画（无需额外 bold 字体）
            const dc = link ? [20, 90, 200] : [30, 30, 30];
            this.doc.setDrawColor(dc[0], dc[1], dc[2]);
            this.doc.setLineWidth(0.25);
            this.doc.text(piece, x, curY, { renderingMode: "fillThenStroke" });
          } else {
            this.doc.text(piece, x, curY);
          }
        }
        if (link && !this._dry) this.doc.setTextColor(30, 30, 30);
        x += w;
      }
    };

    for (const seg of segs) placeChar(seg.text, seg.code, seg.link, seg.bold);
    this.y = curY + lineH;
    return this.y;
  }

  drawHeading(
    token: Tokens.Heading,
    currentRoute: string,
  ): { anchor: string; page: number } {
    const sizes: Record<number, number> = {
      1: 20,
      2: 16,
      3: 13,
      4: 12,
      5: 11,
      6: 11,
    };
    const size = sizes[token.depth] || 12;
    this.ensureSpace(size * 0.6);
    this.y += token.depth <= 2 ? 4 : 2;
    const anchor = slugify(token.text);
    if (!this._dry)
      this.anchors.set(`${currentRoute}#${anchor}`, {
        page: this.curPage(),
        y: this.y,
      });
    this.setSize(size);
    this.doc.setTextColor(0, 0, 0);
    // 标题可能含行内链接/代码（如 ### [`@atomicLoad`](url)），用 renderCell 解析渲染
    const headTokens: InlineToken[] =
      token.tokens && token.tokens.length
        ? (token.tokens as InlineToken[])
        : [{ type: "text", text: token.text }];
    const lineH = size * 0.55;
    this._cellDefaultColor = [0, 0, 0];
    const nLines = this.renderCell(
      headTokens,
      MARGIN.left,
      this.y,
      CONTENT_W,
      lineH,
      true,
      currentRoute,
    );
    this.ensureSpace(nLines * lineH);
    this.renderCell(
      headTokens,
      MARGIN.left,
      this.y,
      CONTENT_W,
      lineH,
      false,
      currentRoute,
    );
    this._cellDefaultColor = null;
    this.y += nLines * lineH + 2;
    return { anchor, page: this.curPage() };
  }

  // 绘制代码块：Shiki 高亮 + 保留原始缩进 + 长行硬换行（保留续行缩进）
  drawCode(hlLines: HlLine[], leftOffset = 0): void {
    const size = 8.5;
    const lineH = 4.3;
    const padX = 3.5;
    const padY = 3.2;
    const blockX = MARGIN.left + leftOffset;
    const blockW = CONTENT_W - leftOffset * 2;
    const textX = blockX + padX;
    const maxTextW = blockW - padX * 2;
    this.setSize(size);

    this.doc.setFont("Mono", "normal");

    interface DrawRow {
      pieces: { content: string; color: string }[];
      x: number;
    }
    const drawRows: DrawRow[] = [];
    for (const tokenLine of hlLines) {
      const firstContent = tokenLine.length ? tokenLine[0].content : "";
      const leadSpaces = firstContent.match(/^ */)?.[0].length || 0;
      let cur: { content: string; color: string }[] = [];
      let curW = 0;
      const spaceW = this.doc.getTextWidth(" ");
      const contIndentW = (leadSpaces + 2) * spaceW;
      let rowX = textX;
      const pushPiece = (content: string, color: string): void => {
        let chunk = "";
        for (const ch of content) {
          const isCjk = this.isCjk(ch);
          this.doc.setFont(isCjk ? "CJK" : "Mono", "normal");
          const w = this.doc.getTextWidth(ch);
          if (rowX + curW + w > textX + maxTextW && (curW > 0 || cur.length)) {
            if (chunk) {
              cur.push({ content: chunk, color });
              chunk = "";
            }
            drawRows.push({ pieces: cur, x: rowX });
            cur = [];
            curW = 0;
            rowX = textX + contIndentW;
          }
          chunk += ch;
          curW += w;
        }
        if (chunk) cur.push({ content: chunk, color });
      };
      for (const t of tokenLine) pushPiece(t.content, t.color);
      drawRows.push({ pieces: cur, x: rowX });
    }

    this.y += 2.5;

    // 孤行/寡行保护所需的常量：
    // - MIN_TAIL_ROWS：避免一个代码块在下一页只留下极少的尾行（如仅 `}`）。
    // - 整块下移阈值：体量不大的代码块（不超过半个内容区高度）若当前页放不下，整体移到下一页，避免拦腰断开。
    const MIN_TAIL_ROWS = 3;
    const contentH = A4.h - MARGIN.top - MARGIN.bottom;
    const totalBlockH = drawRows.length * lineH + padY * 2;
    const availSpace = A4.h - MARGIN.bottom - this.y;
    if (totalBlockH <= contentH * 0.5 && totalBlockH > availSpace) {
      // 小代码块整体下移到下一页，保持完整
      this.newPage();
    }

    let idx = 0;
    while (idx < drawRows.length) {
      this.ensureSpace(lineH + padY * 2);
      const blockStartY = this.y;
      const rowsThisPage: { row: DrawRow; yy: number }[] = [];
      let yy = this.y + padY + size * 0.32;
      while (idx < drawRows.length && yy + lineH <= A4.h - MARGIN.bottom) {
        rowsThisPage.push({ row: drawRows[idx], yy });
        yy += lineH;
        idx++;
      }
      // 孤行保护：若本页放下后，剩余行数过少（如只剩闭合括号），
      // 则从本页回收若干行留给下一页，使断点更自然（仅当本页放得下足够多行时才回收）。
      const remaining = drawRows.length - idx;
      if (
        remaining > 0 &&
        remaining < MIN_TAIL_ROWS &&
        rowsThisPage.length > MIN_TAIL_ROWS
      ) {
        const giveBack = MIN_TAIL_ROWS - remaining;
        for (let k = 0; k < giveBack; k++) {
          rowsThisPage.pop();
          idx--;
        }
      }
      const blockH = rowsThisPage.length * lineH + padY * 2;
      if (!this._dry) {
        this.doc.setFillColor(246, 248, 250);
        this.doc.roundedRect(
          blockX,
          blockStartY,
          blockW,
          blockH,
          1.2,
          1.2,
          "F",
        );
      }
      for (const { row, yy: ry } of rowsThisPage) {
        let cx = row.x;
        for (const piece of row.pieces) {
          const [r, g, b] = hexToRgb(piece.color);
          this.doc.setTextColor(r, g, b);
          cx = this.drawMixedLine(piece.content, cx, ry, "Mono");
        }
      }
      this.y = blockStartY + blockH;
      if (idx < drawRows.length) this.newPage();
    }
    this.y += 3.5;
    this.doc.setTextColor(30, 30, 30);
  }

  async drawImage(token: Tokens.Image, currentRoute: string): Promise<void> {
    const src = token.href;
    const resolved = resolveImagePath(src, currentRoute, this.courseDir);
    let buf: Buffer;
    try {
      if (resolved.localPath && existsSync(resolved.localPath)) {
        buf = await readFile(resolved.localPath);
      } else if (resolved.url) {
        const r = await fetch(resolved.url);
        buf = Buffer.from(await r.arrayBuffer());
      } else return;
    } catch {
      return;
    }

    // SVG / 其他 -> PNG，并取尺寸
    let png: Buffer;
    let meta: Metadata;
    try {
      const img = sharp(buf, { density: 200 }).resize({
        width: 1100,
        withoutEnlargement: true,
      });
      png = await img.png({ compressionLevel: 9, quality: 80 }).toBuffer();
      meta = await sharp(png).metadata();
    } catch {
      return;
    }

    const mh = meta.height ?? 1;
    const mw = meta.width ?? 1;
    const ratio = mh / mw;
    let drawW = Math.min(CONTENT_W, mw * 0.264583); // px->mm @96dpi 近似
    if (drawW > CONTENT_W) drawW = CONTENT_W;
    let drawH = drawW * ratio;
    const maxH = A4.h - MARGIN.top - MARGIN.bottom;
    if (drawH > maxH) {
      drawH = maxH;
      drawW = drawH / ratio;
    }

    // 若当前页剩余空间不足以完整放下图片，强制换页并从顶部起绘，
    // 避免图片顶部/底部被物理裁切（drawH 已被限制不超过单页内容区高度）。
    if (this.y + drawH + 4 > A4.h - MARGIN.bottom) {
      this.newPage();
    } else {
      this.ensureSpace(drawH + 4);
    }
    const x = MARGIN.left + (CONTENT_W - drawW) / 2;
    if (!this._dry) this.doc.addImage(png, "PNG", x, this.y, drawW, drawH);
    this.y += drawH + 4;
  }

  // 列表渲染：无序（矢量实心圆点）/ 有序（数字编号）/ 嵌套（递归逐层缩进）。
  async drawList(
    token: Tokens.List,
    currentRoute: string,
    opts: { level?: number; baseIndent?: number } = {},
  ): Promise<void> {
    const level = opts.level || 0;
    const baseIndent = opts.baseIndent || 0;
    const size = 10.5;
    const lineH = 6.6;
    const itemGap = 1.4;
    const markerGap = 5.5;
    const markerX = MARGIN.left + baseIndent + level * 7 + 2;
    const textIndent = markerX - MARGIN.left + markerGap;
    let n =
      token.start && Number.isFinite(token.start) ? Number(token.start) : 1;

    for (const item of token.items) {
      this.setSize(size);
      this.ensureSpace(lineH);
      const markerY = this.y;
      const subLists: Tokens.List[] = [];
      const inlineToks: InlineToken[] = [];
      for (const t of item.tokens || []) {
        const tt = t as any;
        if (tt.type === "list") {
          subLists.push(tt as Tokens.List);
          continue;
        }
        if (tt.type === "text") {
          inlineToks.push(...(tt.tokens || [{ type: "text", text: tt.text }]));
        } else if (tt.type === "paragraph") {
          inlineToks.push(...(tt.tokens || []));
        } else inlineToks.push(tt);
      }
      if (!this._dry) {
        // 圆点垂直中心：对齐 CJK 文字视觉中线。markerY 为文字基线，
        // CJK 字身大致占基线上方 0~0.72em，视觉中线约在基线上方 0.30em；
        // 圆点半径 0.75mm 也占垂直空间，故中心取基线上方约 0.30em。
        const dotCy = markerY - size * 0.3 * 0.3528;
        if (token.ordered) {
          this.doc.setFont("Sans", "normal");
          this.doc.setTextColor(70, 70, 70);
          this.doc.text(`${n}.`, markerX, markerY);
        } else if (level === 0) {
          this.doc.setFillColor(64, 64, 64);
          this.doc.circle(markerX + 0.7, dotCy, 0.75, "F");
        } else {
          this.doc.setDrawColor(90, 90, 90);
          this.doc.setLineWidth(0.3);
          this.doc.circle(markerX + 0.7, dotCy, 0.75, "S");
        }
        this.doc.setTextColor(45, 45, 45);
      }
      if (inlineToks.length) {
        this.drawInline(inlineToks, {
          indent: textIndent,
          currentRoute,
          lineH,
          size,
        });
      } else {
        this.y += lineH;
      }
      for (const sub of subLists) {
        await this.drawList(sub, currentRoute, {
          level: level + 1,
          baseIndent,
        });
      }
      this.y += itemGap;
      n++;
    }
    this.y -= itemGap;
    this.y += 2;
  }

  // 普通引用块 `> ...`：淡灰底圆角 + 左竖条，两遍渲染（先干跑测高再画底/内容），
  // 与提示框观感统一。竖条与背景精确覆盖整段内容，避免出现“半截竖条/内容偏上”。
  drawBlockquote(token: Tokens.Blockquote, currentRoute: string): void {
    const size = 10.5;
    const lineH = 5.8;
    const padX = 4; // 框内左右内边距（含竖条侧）
    const padY = 2.8; // 框内上下内边距
    const barW = 1; // 左竖条宽度
    const contentIndent = padX + 1; // 内容相对 boxX 的左缩进（让出竖条 + 留白）
    const barColor: [number, number, number] = [200, 160, 40];
    const bgColor: [number, number, number] = [250, 247, 235];

    this.ensureSpace(12);
    this.y += 2;
    const startY = this.y;
    const startPage = this.page;
    const boxX = MARGIN.left;

    const renderBody = (): void => {
      // 首行需为基线上方的字身预留一个 ascent，否则内容会顶出框外、整体上偏。
      this.y += padY + size * 0.5;
      for (const t of token.tokens) {
        const tt = t as any;
        if (tt.type === "paragraph")
          this.drawInline(tt.tokens, {
            indent: contentIndent,
            currentRoute,
            size,
            lineH,
          });
        else if (tt.type === "text")
          this.drawInline(tt.tokens || [{ type: "text", text: tt.text }], {
            indent: contentIndent,
            currentRoute,
            size,
            lineH,
          });
      }
      this.y += padY * 0.6;
    };

    // 第一遍：干跑测高（snap.realPage 供 setPage 精确回滚，避免页号漂移）
    const snap = {
      y: this.y,
      page: this.page,
      realPage: this.curPage(),
      links: this.pendingLinks.length,
    };
    this._dry = true;
    renderBody();
    const measuredEndY = this.y;
    const measuredEndPage = this.page;
    // 回滚
    this._dry = false;
    this.y = snap.y;
    this.page = snap.page;
    this.doc.setPage(snap.realPage);
    this.pendingLinks.length = snap.links;

    if (measuredEndPage === startPage) {
      const boxH = measuredEndY - startY;
      this.doc.setFillColor(bgColor[0], bgColor[1], bgColor[2]);
      this.doc.roundedRect(boxX, startY, CONTENT_W, boxH, 1.5, 1.5, "F");
      this.doc.setFillColor(barColor[0], barColor[1], barColor[2]);
      this.doc.rect(boxX, startY, barW, boxH, "F");
    } else {
      // 跨页：首页底部补画竖条
      this.doc.setFillColor(barColor[0], barColor[1], barColor[2]);
      this.doc.rect(boxX, startY, barW, A4.h - MARGIN.bottom - startY, "F");
    }

    renderBody();
    this.y += 3;
  }

  drawParagraph(
    token: Tokens.Paragraph,
    currentRoute: string,
    indent = 0,
  ): Tokens.Image[] {
    const imgs = (token.tokens || []).filter(
      (t) => (t as any).type === "image",
    ) as Tokens.Image[];
    if (imgs.length && token.tokens.length === imgs.length) {
      return imgs; // 交给上层异步处理
    }
    this.drawInline(token.tokens as InlineToken[], { currentRoute, indent });
    this.y += 1.5;
    return [];
  }

  // 将单元格的 inline tokens 拍平为 [{text, link?, code?}] 片段
  flattenCellTokens(
    tokens: InlineToken[],
  ): { text: string; code?: boolean; link?: string }[] {
    const segs: { text: string; code?: boolean; link?: string }[] = [];
    const walk = (toks: InlineToken[] | undefined, link?: string): void => {
      for (const t of toks || []) {
        const tt = t as any;
        if (tt.type === "link") {
          walk(tt.tokens || [{ type: "text", text: tt.text }], tt.href);
        } else if (tt.type === "codespan") {
          segs.push({ text: tt.text, code: true, link });
        } else if (tt.tokens) {
          walk(tt.tokens, link);
        } else {
          segs.push({ text: tt.text ?? tt.raw ?? "", link });
        }
      }
    };
    walk(tokens);
    return segs;
  }

  // 在指定区域内排版单元格内容，支持链接/代码/换行/超长串强制断行。返回行数。
  renderCell(
    tokens: InlineToken[],
    x: number,
    baseY: number,
    maxW: number,
    lineH: number,
    measureOnly: boolean,
    currentRoute: string,
  ): number {
    const segs = this.flattenCellTokens(tokens);
    interface Unit {
      text: string;
      code?: boolean;
      link?: string;
    }
    const units: Unit[] = [];
    for (const seg of segs) {
      let buf = "";
      const pushBuf = (): void => {
        if (buf) {
          units.push({ text: buf, code: seg.code, link: seg.link });
          buf = "";
        }
      };
      for (const ch of seg.text) {
        const c = /\s/.test(ch) ? " " : ch;
        if (this.isCjk(c)) {
          pushBuf();
          units.push({ text: c, code: seg.code, link: seg.link });
        } else if (c === " ") {
          pushBuf();
          units.push({ text: " ", code: seg.code, link: seg.link });
        } else buf += c;
      }
      pushBuf();
    }
    let x0 = x;
    let y = baseY;
    let lines = 1;
    const fontFor = (u: Unit): string =>
      u.code ? "Mono" : this.isCjk(u.text[0] || "") ? "CJK" : "Sans";
    for (const u of units) {
      this.doc.setFont(fontFor(u), "normal");
      const w = this.doc.getTextWidth(u.text);
      // 超长不可断串（如 URL）：按字符强制断行
      if (w > maxW && u.text.length > 1) {
        let part = "";
        for (const ch of u.text) {
          const tw = this.doc.getTextWidth(part + ch);
          if (x0 - x + tw > maxW && part) {
            if (!measureOnly)
              this.drawCellPiece(part, x0, y, u, measureOnly, currentRoute);
            x0 = x;
            y += lineH;
            lines++;
            part = ch;
          } else part += ch;
        }
        if (part) {
          const pw = this.doc.getTextWidth(part);
          if (x0 - x + pw > maxW && x0 > x) {
            x0 = x;
            y += lineH;
            lines++;
          }
          if (!measureOnly)
            this.drawCellPiece(part, x0, y, u, measureOnly, currentRoute);
          x0 += pw;
        }
        continue;
      }
      if (x0 - x + w > maxW && u.text !== " " && x0 > x) {
        x0 = x;
        y += lineH;
        lines++;
      }
      if (!measureOnly)
        this.drawCellPiece(u.text, x0, y, u, measureOnly, currentRoute);
      x0 += w;
    }
    return lines;
  }

  drawCellPiece(
    text: string,
    x: number,
    y: number,
    u: { code?: boolean; link?: string },
    measureOnly: boolean,
    currentRoute: string,
  ): void {
    if (measureOnly || this._dry) return;
    const fn = u.code ? "Mono" : this.isCjk(text[0] || "") ? "CJK" : "Sans";
    this.doc.setFont(fn, "normal");
    const w = this.doc.getTextWidth(text);
    if (u.link) {
      const norm = normalizeInternalLink(u.link, currentRoute);
      if (norm)
        this.pendingLinks.push({
          page: this.curPage(),
          x,
          y: y - 3,
          w,
          h: 4.5,
          target: norm,
        });
      else this.doc.link(x, y - 3, w, 4.5, { url: u.link });
      this.doc.setTextColor(20, 90, 200);
    } else {
      const dc = this._cellDefaultColor || [40, 40, 40];
      this.doc.setTextColor(dc[0], dc[1], dc[2]);
    }
    this.doc.text(text, x, y);
    this.doc.setTextColor(40, 40, 40);
  }

  drawTable(token: Tokens.Table, currentRoute: string): void {
    const cols = token.header.length;
    const colW = CONTENT_W / cols;
    const pad = 1.8;
    const cellLineH = 4.5;
    const drawRow = (
      cells: { tokens?: Token[]; text: string }[],
      bold: boolean,
    ): void => {
      this.setSize(9.5);
      const lineCounts = cells.map((c, i) =>
        this.renderCell(
          (c.tokens as InlineToken[]) || [{ type: "text", text: c.text }],
          MARGIN.left + i * colW + pad,
          this.y,
          colW - pad * 2,
          cellLineH,
          true,
          currentRoute,
        ),
      );
      const maxLines = Math.max(1, ...lineCounts);
      const rowH = maxLines * cellLineH + 3;
      this.ensureSpace(rowH);
      if (bold) {
        this.doc.setFillColor(240, 240, 240);
        this.doc.rect(MARGIN.left, this.y - 4, CONTENT_W, rowH, "F");
      }
      cells.forEach((c, i) => {
        const cx = MARGIN.left + i * colW + pad;
        this.renderCell(
          (c.tokens as InlineToken[]) || [{ type: "text", text: c.text }],
          cx,
          this.y,
          colW - pad * 2,
          cellLineH,
          false,
          currentRoute,
        );
      });
      this.doc.setDrawColor(210);
      this.doc.rect(MARGIN.left, this.y - 4, CONTENT_W, rowH);
      this.y += rowH;
    };
    drawRow(token.header, true);
    for (const row of token.rows) drawRow(row, false);
    this.y += 3;
  }

  hr(): void {
    this.ensureSpace(4);
    this.doc.setDrawColor(220);
    this.doc.line(MARGIN.left, this.y, A4.w - MARGIN.right, this.y);
    this.y += 5;
  }

  // 提示框（VitePress 容器）：淡色圆角背景 + 左竖条 + 标题，两遍渲染。
  async drawAdmonition(
    token: AdmonitionToken,
    currentRoute: string,
  ): Promise<void> {
    const styles: Record<
      string,
      {
        bar: [number, number, number];
        bg: [number, number, number];
        title: [number, number, number];
      }
    > = {
      tip: { bar: [66, 184, 131], bg: [240, 249, 244], title: [33, 131, 88] },
      info: {
        bar: [100, 150, 220],
        bg: [240, 244, 251],
        title: [60, 100, 180],
      },
      warning: {
        bar: [234, 179, 8],
        bg: [252, 248, 227],
        title: [157, 117, 10],
      },
      danger: { bar: [220, 80, 80], bg: [253, 241, 241], title: [180, 50, 50] },
      details: {
        bar: [150, 150, 150],
        bg: [245, 245, 245],
        title: [90, 90, 90],
      },
    };
    const defaultTitles: Record<string, string> = {
      tip: "提示",
      info: "信息",
      warning: "警告",
      danger: "危险",
      details: "详细信息",
    };
    const st = styles[token.admType] || styles.info;
    const heading =
      token.title && token.title.trim()
        ? token.title.trim()
        : defaultTitles[token.admType] || "信息";

    const padX = 4;
    const padTop = 3;
    const barW = 1;
    const contentIndent = padX + 1;
    const titleSize = 9.5;
    const titleH = 6.2;

    this.ensureSpace(18);
    this.y += 2;
    const startY = this.y;
    const startPage = this.page;
    const boxX = MARGIN.left;

    const renderBody = async (): Promise<void> => {
      this.y += padTop + titleSize * 0.55;
      if (!this._dry)
        this.doc.setTextColor(st.title[0], st.title[1], st.title[2]);
      this.drawInline([{ type: "text", text: heading }], {
        indent: contentIndent,
        size: titleSize,
        lineH: titleH,
        currentRoute,
      });
      if (!this._dry) this.doc.setTextColor(45, 45, 45);
      this.y += 1.2;
      await this.renderTokens(token.tokens, currentRoute, {
        indent: contentIndent,
        size: 9.5,
        codeOffset: contentIndent,
      });
      this.y += padTop * 0.5;
    };

    // 第一遍：干跑测高。snap 同时记录内部计数页 (this.page，供跨页增量判断)
    // 与 jsPDF 真实页号 (realPage，供 setPage 精确回滚)。
    const snap = {
      y: this.y,
      page: this.page,
      realPage: this.curPage(),
      links: this.pendingLinks.length,
    };
    this._dry = true;
    await renderBody();
    const measuredEndY = this.y;
    const measuredEndPage = this.page;
    // 回滚
    this._dry = false;
    this.y = snap.y;
    this.page = snap.page;
    this.doc.setPage(snap.realPage);
    this.pendingLinks.length = snap.links;

    const samePage = measuredEndPage === startPage;
    if (samePage) {
      const boxH = measuredEndY - startY;
      this.doc.setFillColor(st.bg[0], st.bg[1], st.bg[2]);
      this.doc.roundedRect(boxX, startY, CONTENT_W, boxH, 1.5, 1.5, "F");
      this.doc.setFillColor(st.bar[0], st.bar[1], st.bar[2]);
      this.doc.rect(boxX, startY, barW, boxH, "F");
    } else {
      this.doc.setFillColor(st.bar[0], st.bar[1], st.bar[2]);
      this.doc.rect(boxX, startY, barW, A4.h - MARGIN.bottom - startY, "F");
    }

    await renderBody();
    this.y += 5;
  }

  // 渲染一组 token（可复用于页面与容器内部）
  async renderTokens(
    tokens: PdfToken[],
    route: string,
    ctx: RenderCtx = {},
  ): Promise<void> {
    const indent = ctx.indent || 0;
    const codeOffset = ctx.codeOffset || 0;
    for (const token of tokens) {
      const t = token as any;
      switch (t.type) {
        case "heading":
          this.drawHeading(t as Tokens.Heading, route);
          break;
        case "paragraph": {
          const imgs = this.drawParagraph(t as Tokens.Paragraph, route, indent);
          for (const im of imgs) await this.drawImage(im, route);
          break;
        }
        case "code":
          this.drawCode(highlightToLines(t.text, t.lang || ""), codeOffset);
          break;
        case "list":
          await this.drawList(t as Tokens.List, route, { baseIndent: indent });
          break;
        case "blockquote":
          this.drawBlockquote(t as Tokens.Blockquote, route);
          break;
        case "admonition":
          await this.drawAdmonition(t as AdmonitionToken, route);
          break;
        case "table":
          this.drawTable(t as Tokens.Table, route);
          break;
        case "hr":
          this.hr();
          break;
        case "space":
          this.y += 2;
          break;
        case "image":
          await this.drawImage(t as Tokens.Image, route);
          break;
        case "text":
          if (t.tokens)
            this.drawInline(t.tokens, { currentRoute: route, indent });
          else if (t.text)
            this.drawInline([{ type: "text", text: t.text }], {
              currentRoute: route,
              indent,
            });
          break;
        default:
          if (t.tokens)
            this.drawInline(t.tokens, { currentRoute: route, indent });
      }
    }
  }

  // ---------- 渲染一页（一篇 markdown）----------
  async renderPage(
    route: string,
    _title: string,
    tokens: PdfToken[],
  ): Promise<void> {
    if (this.page !== 1 || this.y > MARGIN.top) {
      if (!(this.page === 1 && this.y === MARGIN.top)) this.newPage();
    }
    this.routeStart.set(route, this.curPage());
    // 页面 route 顶部也注册一个空锚点，便于无 #anchor 的链接跳到页首
    this.anchors.set(`${route}#`, { page: this.curPage(), y: this.y });

    await this.renderTokens(tokens, route);
  }

  // ---------- 收尾：绑定站内链接到目标页 ----------
  finalize(): void {
    for (const link of this.pendingLinks) {
      const key = `${link.target.route}#${link.target.anchor}`;
      let dest = this.anchors.get(key);
      if (!dest) dest = this.anchors.get(`${link.target.route}#`); // 退化到页首
      if (!dest && this.routeStart.has(link.target.route)) {
        dest = { page: this.routeStart.get(link.target.route)!, y: MARGIN.top };
      }
      if (dest) {
        this.doc.setPage(link.page);
        this.doc.link(link.x, link.y, link.w, link.h, {
          pageNumber: dest.page,
          top: dest.y,
        });
      }
    }
  }

  output(): Buffer {
    return Buffer.from(this.doc.output("arraybuffer"));
  }
}

export { MARGIN, A4 };
