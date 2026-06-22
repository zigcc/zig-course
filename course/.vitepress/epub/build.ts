#!/usr/bin/env bun
/**
 * 将 zig-course（VitePress）转换为 EPUB3 电子书。
 *
 * 用法：
 *   bun run course/.vitepress/epub/build.ts
 * 或经由 package.json 脚本：
 *   bun run export-epub
 *
 * 纯 TypeScript 实现，零 Python 依赖。字体在构建时下载并即时子集化。
 */
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { config } from "./config.ts";
import { resolveChapters, buildNavTree } from "./sidebar.ts";
import { preprocess } from "./preprocess.ts";
import { rewriteLinksAndImages } from "./links.ts";
import { ImageCollector, toPng } from "./images.ts";
import { prepareFonts } from "./fonts.ts";
import { createRenderer, htmlToXhtml, wrapXhtml } from "./render.ts";
import { packageEpub, type RenderedChapter } from "./package.ts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  console.log(`[epub] 开始构建《${config.title}》`);

  // 1. 解析章节 + 构建层级目录树
  const { chapters, routeToFile } = resolveChapters(config);
  const navTree = buildNavTree(routeToFile);
  console.log(`[epub] 共 ${chapters.length} 个章节`);

  // 2. 准备渲染器与图片收集器
  const md = await createRenderer(config);
  const images = new ImageCollector();

  // 3. 逐章渲染
  const rendered: RenderedChapter[] = [];
  for (const ch of chapters) {
    const raw = readFileSync(ch.mdPath, "utf8");
    const processed = preprocess(raw, config.courseDir);
    let html = md.render(processed, { slugCounts: {} });
    html = rewriteLinksAndImages(
      html,
      ch.route,
      routeToFile,
      (spec) => images.collect(spec),
      config.courseDir,
    );
    html = htmlToXhtml(html);
    rendered.push({
      fileName: ch.fileName,
      title: ch.item.text,
      xhtml: wrapXhtml(ch.item.text, html, config.language),
    });
  }

  // 4. 校验站内/页内锚点 + 修复非法外链 URL
  fixCrossReferences(rendered);

  // 5. 处理图片（下载远程 / 读取本地 / 统一转 PNG）
  const imageMap = await images.finalize();
  console.log(`[epub] 图片处理完成：${imageMap.size} 张`);

  // 6. 准备字体（下载 + 子集化）——收集全书字符集
  const usedText = collectUsedText(rendered);
  const fonts = await prepareFonts(config, usedText);
  console.log(
    `[epub] 字体子集化完成：中文 ${(fonts.cjk.length / 1024) | 0}KB，英文 ${(fonts.sans.length / 1024) | 0}KB，等宽 ${(fonts.mono.length / 1024) | 0}KB`,
  );

  // 7. 封面
  const coverPath = path.join(config.courseDir, config.coverImage);
  let cover: Uint8Array | null = null;
  try {
    cover = await toPng(readFileSync(coverPath));
  } catch {
    console.warn(`[epub] 未找到或无法处理封面：${coverPath}`);
  }

  // 8. 打包
  const css = readFileSync(path.join(__dirname, "style.css"), "utf8");
  const epub = await packageEpub({
    config,
    chapters,
    navTree,
    renderedChapters: rendered,
    images: imageMap,
    fonts,
    css,
    cover,
  });

  writeFileSync(config.outFile, epub);
  console.log(
    `[epub] ✅ 生成完成：${config.outFile}（${(epub.length / 1024 / 1024).toFixed(2)} MB）`,
  );
}

/** 收集全书所有渲染后文本中的字符，用于字体子集化 */
function collectUsedText(rendered: RenderedChapter[]): string {
  const set = new Set<string>();
  for (const rc of rendered) {
    for (const ch of rc.xhtml) set.add(ch);
  }
  // 加上常用中文标点，避免裁切后缺字
  for (const ch of "，。、；：？！…—“”‘’（）《》【】·") set.add(ch);
  return Array.from(set).join("");
}

/**
 * 后处理：
 * - 校验站内锚点（chapter-xxx.xhtml#anchor）与页内锚点（#anchor），不存在则降级为指向页首，避免 EPUBCheck RSC-012；
 * - 修复非法外链 URL（如连续点 host），仅把 href 改为 #，保持标签闭合合法。
 */
function fixCrossReferences(rendered: RenderedChapter[]): void {
  const fileAnchors = new Map<string, Set<string>>();
  for (const rc of rendered) {
    const ids = new Set<string>();
    for (const m of rc.xhtml.matchAll(/\bid="([^"]+)"/g)) ids.add(m[1]);
    fileAnchors.set(rc.fileName, ids);
  }

  for (const rc of rendered) {
    let x = rc.xhtml;
    // 非法外链
    x = x.replace(
      /(<a\b[^>]*?href=")(https?:\/\/[^"]+)("[^>]*>)/g,
      (m, pre, href, post) => {
        try {
          const u = new URL(href);
          if (!u.hostname || u.hostname.includes(".."))
            throw new Error("bad host");
          return m;
        } catch {
          return `${pre}#${post}`;
        }
      },
    );
    // 站内锚点
    x = x.replace(
      /href="(chapter-\d{3}\.xhtml)#([^"]+)"/g,
      (m, file, anchor) => {
        const ids = fileAnchors.get(file);
        return ids && ids.has(anchor) ? m : `href="${file}"`;
      },
    );
    // 页内锚点
    const ids = fileAnchors.get(rc.fileName)!;
    x = x.replace(/href="#([^"]+)"/g, (m, anchor) =>
      ids.has(anchor) ? m : `href="#"`,
    );
    rc.xhtml = x;
  }
}

main().catch((e) => {
  console.error("[epub] 构建失败：", e);
  process.exit(1);
});
