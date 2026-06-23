import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import subsetFont from "subset-font";
import type { EpubConfig, FontSpec } from "./config.ts";

/** 下载文件到 Buffer（带磁盘缓存） */
async function download(url: string, cachePath: string): Promise<Buffer> {
  if (existsSync(cachePath)) return readFileSync(cachePath);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`下载字体失败 ${url}: ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  writeFileSync(cachePath, buf);
  return buf;
}

export interface SubsetFonts {
  /** 子集化后的中文正文字体（woff2） */
  cjk: Uint8Array;
  /** 子集化后的中文粗体（woff2） */
  cjkBold: Uint8Array;
  /** 子集化后的英文正文字体（woff2） */
  sans: Uint8Array;
  /** 子集化后的英文粗体（woff2） */
  sansBold: Uint8Array;
  /** 子集化后的代码等宽字体（woff2） */
  mono: Uint8Array;
}

/** 下载一个可变字体并「子集 + 钉轴」为静态 woff2（与 PDF 同方案） */
async function buildOne(
  spec: FontSpec,
  text: string,
  cacheDir: string,
): Promise<Uint8Array> {
  const raw = await download(spec.url, path.join(cacheDir, spec.fileName));
  const sub = await subsetFont(raw, text, {
    targetFormat: "woff2",
    variationAxes: spec.axes,
  });
  return new Uint8Array(sub);
}

/**
 * 下载并子集化三套字体。
 * @param usedText 全书用到的所有字符（用于裁剪字体）
 */
export async function prepareFonts(
  config: EpubConfig,
  usedText: string,
): Promise<SubsetFonts> {
  mkdirSync(config.cacheDir, { recursive: true });

  // 等宽字体补齐 ASCII（代码里几乎必然用到）；中文/英文正文用全书字符集即可
  const asciiText =
    " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`" +
    "abcdefghijklmnopqrstuvwxyz{|}~";

  // 先并行预热下载唯一的原始字体文件（按 fileName 去重），填充磁盘缓存；
  // 否则随后并行子集化时，共享同一 fileName 的 normal/bold 会并发写缓存产生竞态。
  const specs = [
    config.fonts.cjk,
    config.fonts.cjkBold,
    config.fonts.sans,
    config.fonts.sansBold,
    config.fonts.mono,
  ];
  const uniqueByFile = new Map(specs.map((s) => [s.fileName, s]));
  await Promise.all(
    [...uniqueByFile.values()].map((s) =>
      download(s.url, path.join(config.cacheDir, s.fileName)),
    ),
  );

  // 缓存已就绪，buildOne 内的 download 均命中缓存（只读），可安全并行子集化
  const [cjk, cjkBold, sans, sansBold, mono] = await Promise.all([
    buildOne(config.fonts.cjk, usedText, config.cacheDir),
    buildOne(config.fonts.cjkBold, usedText, config.cacheDir),
    buildOne(config.fonts.sans, usedText, config.cacheDir),
    buildOne(config.fonts.sansBold, usedText, config.cacheDir),
    buildOne(config.fonts.mono, asciiText + usedText, config.cacheDir),
  ]);

  return { cjk, cjkBold, sans, sansBold, mono };
}
