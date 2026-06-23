import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** EPub 生成配置 */
export interface EpubConfig {
  /** 书名 */
  title: string;
  /** 作者 */
  author: string;
  /** 出版方 */
  publisher: string;
  /** 语言代码 */
  language: string;
  /** VitePress 源目录（course 目录）的绝对路径 */
  courseDir: string;
  /** 输出 epub 文件的绝对路径 */
  outFile: string;
  /** 封面图相对 courseDir 的路径 */
  coverImage: string;
  /** Shiki 主题 */
  shikiTheme: string;
  /** 需要预加载的 Shiki 语言（确保代码块都能高亮） */
  shikiLangs: string[];
  /** 构建时下载的字体（与 PDF 同方案：Google Fonts 的 glyf 可变字体，子集 + 钉轴） */
  fonts: {
    /** 中文正文字体 */
    cjk: FontSpec;
    /** 中文粗体（wght:700，用于标题/加粗，避免依赖阅读器伪粗体） */
    cjkBold: FontSpec;
    /** 正文英文/数字字体（无衡线） */
    sans: FontSpec;
    /** 英文粗体（wght:700） */
    sansBold: FontSpec;
    /** 代码等宽字体 */
    mono: FontSpec;
  };
  /** 字体与中间产物的缓存目录 */
  cacheDir: string;
}

/** 单个字体来源：family 用于 CSS，url 指向可变字体，axes 为要钉死的轴 */
export interface FontSpec {
  family: string;
  url: string;
  fileName: string;
  axes: Record<string, number>;
}

/** course 目录：epub 模块位于 course/.vitepress/epub，向上两级即 course */
const COURSE_DIR = path.resolve(__dirname, "..", "..");

export const config: EpubConfig = {
  title: "Zig 语言圣经",
  author: "Zig 中文社区 (ZigCC)",
  publisher: "ZigCC",
  language: "zh-CN",
  courseDir: COURSE_DIR,
  outFile: path.resolve(COURSE_DIR, "..", "books", "zig-course.epub"),
  coverImage: ".vitepress/epub/cover.png",
  shikiTheme: "github-light",
  shikiLangs: [
    "zig",
    "sh",
    "shell",
    "bash",
    "powershell",
    "diff",
    "c",
    "cpp",
    "python",
    "json",
    "asm",
    "ts",
    "js",
    "toml",
    "yaml",
  ],
  // 与 PDF（scripts/pdf/build-fonts.ts）同源：Google Fonts 的 glyf 可变字体，子集 + 钉轴
  fonts: {
    cjk: {
      family: "Noto Serif SC",
      url: "https://github.com/google/fonts/raw/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf",
      fileName: "NotoSerifSC.ttf",
      axes: { wght: 400 },
    },
    cjkBold: {
      family: "Noto Serif SC",
      url: "https://github.com/google/fonts/raw/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf",
      fileName: "NotoSerifSC.ttf",
      axes: { wght: 700 },
    },
    sans: {
      family: "Inter",
      url: "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf",
      fileName: "Inter.ttf",
      axes: { wght: 400, opsz: 14 },
    },
    sansBold: {
      family: "Inter",
      url: "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf",
      fileName: "Inter.ttf",
      axes: { wght: 700, opsz: 14 },
    },
    mono: {
      family: "JetBrains Mono",
      url: "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf",
      fileName: "JetBrainsMono.ttf",
      axes: { wght: 400 },
    },
  },
  cacheDir: path.resolve(__dirname, ".cache"),
};
