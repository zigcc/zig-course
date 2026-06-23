// scripts/pdf/build-fonts.ts
// 生成内嵌 PDF 用的子集字体：assets/fonts/zigcourse-{cjk,sans,mono}.ttf
//
// 纯 Bun/JS：用 subset-font(harfbuzz) 从 Google Fonts 的 glyf 型「可变字体」
// 做「子集 + 钉轴」，输出只含课程用到字形的静态 glyf TrueType。
//   - jsPDF 只能内嵌 glyf 型 TrueType；三个源都是 glyf 可变字体，无需任何 CFF->glyf 转换。
//   - 课程文本 / 侧边栏标题变化后重跑本脚本并提交产物即可。CI 只消费已提交的 TTF。
//
// 字体：
//   cjk  = Noto Serif SC（即思源宋体 Source Han Serif 同源设计）→ 中文正文
//   sans = Inter                                              → 正文英文/数字（无衬线）
//   mono = JetBrains Mono                                     → 代码/行内代码（等宽）
//
// 运行：bun run scripts/pdf/build-fonts.ts（或 bun pdf:fonts）
import subsetFont from "subset-font";
import {
  readFileSync,
  readdirSync,
  writeFileSync,
  mkdirSync,
  existsSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "../..");
const OUT = path.join(ROOT, "assets/fonts");
const CACHE = path.join(HERE, ".font-src"); // gitignored 源字体缓存
mkdirSync(OUT, { recursive: true });
mkdirSync(CACHE, { recursive: true });

const GF = "https://github.com/google/fonts/raw/main/ofl";
const FONTS = [
  {
    name: "cjk",
    file: "NotoSerifSC.ttf",
    url: `${GF}/notoserifsc/NotoSerifSC%5Bwght%5D.ttf`,
    axes: { wght: 400 },
  },
  {
    name: "sans",
    file: "Inter.ttf",
    url: `${GF}/inter/Inter%5Bopsz,wght%5D.ttf`,
    axes: { wght: 400, opsz: 14 },
  },
  {
    name: "mono",
    file: "JetBrainsMono.ttf",
    url: `${GF}/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf`,
    axes: { wght: 400 },
  },
] as const;

// 收集课程会渲染到的所有字符：正文 md + 侧边栏标题 + 渲染器内置中文标题 + 代码片段
function walk(dir: string, out: string[]): void {
  for (const ent of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, out);
    else if (/\.(md|zig)$/.test(ent.name)) out.push(p);
  }
}
function range(a: number, b: number): string {
  let s = "";
  for (let c = a; c <= b; c++) s += String.fromCodePoint(c);
  return s;
}
function collectChars(): string {
  const files: string[] = [];
  walk(path.join(ROOT, "course"), files);
  files.push(
    path.join(ROOT, "course/.vitepress/sidebar.ts"),
    path.join(HERE, "renderer.ts"),
  );
  const set = new Set<string>();
  for (const f of files) {
    if (!existsSync(f)) continue;
    for (const ch of readFileSync(f, "utf-8")) set.add(ch);
  }
  // 保底字形：ASCII、拉丁补充、通用标点、CJK 标点、全角符号
  const safety =
    range(0x20, 0x7e) +
    range(0xa0, 0xff) +
    range(0x2000, 0x206f) +
    range(0x3000, 0x303f) +
    range(0xff00, 0xffef);
  return safety + [...set].join("");
}

async function fetchFont(url: string, dest: string): Promise<Buffer> {
  if (!existsSync(dest)) {
    console.log(`下载 ${path.basename(dest)} ...`);
    const r = await fetch(url);
    if (!r.ok) throw new Error(`下载失败 ${url}: ${r.status}`);
    writeFileSync(dest, Buffer.from(await r.arrayBuffer()));
  }
  return readFileSync(dest);
}

const text = collectChars();
console.log(`收集到 ${text.length} 个待保留字符`);
for (const f of FONTS) {
  const src = await fetchFont(f.url, path.join(CACHE, f.file));
  // 子集 + 钉轴（把可变字体的轴固定到指定值，输出静态 glyf TTF）
  const sub = await subsetFont(src, text, {
    targetFormat: "truetype",
    variationAxes: f.axes,
  });
  const out = path.join(OUT, `zigcourse-${f.name}.ttf`);
  writeFileSync(out, sub);
  console.log(
    `✓ ${f.name} -> ${out}  ${(sub.byteLength / 1024).toFixed(0)} KB`,
  );
}
console.log("完成。");
