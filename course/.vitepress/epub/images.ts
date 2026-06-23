import { existsSync, readFileSync } from "node:fs";
import sharp from "sharp";
import { Resvg } from "@resvg/resvg-js";

/**
 * 图片收集器：在渲染阶段登记所有图片引用，最终统一归一化为 PNG。
 *
 * 为什么统一转 PNG：
 * - 部分阅读器不支持 SVG / WebP；
 * - 远程图片可能 URL 后缀为 .png 但实际是 WebP，会导致 EPUBCheck 报 OPF-029/PKG-021；
 * - 内嵌 SVG 含 <font> 等元素时不符合 EPUB 的 XHTML 校验。
 */
export class ImageCollector {
  /** 原始 spec(REMOTE::url 或 CANDIDATES::a|b) -> 占位 epubPath（../images/img-xxx.png） */
  private specToEpub = new Map<string, string>();
  private counter = 0;

  /** 登记一张图片，返回它在 XHTML 中应使用的相对路径（统一 .png） */
  collect(spec: string): string {
    if (this.specToEpub.has(spec)) return this.specToEpub.get(spec)!;
    this.counter++;
    const epubPath = `../images/img-${String(this.counter).padStart(3, "0")}.png`;
    this.specToEpub.set(spec, epubPath);
    return epubPath;
  }

  /**
   * 下载/读取并归一化所有已登记图片。
   * 返回 Map<epubPath(去掉 ../), pngBytes>。
   */
  async finalize(): Promise<Map<string, Uint8Array>> {
    const result = new Map<string, Uint8Array>();
    for (const [spec, epubPath] of this.specToEpub) {
      try {
        const raw = await this.loadRaw(spec);
        if (!raw) continue;
        const png = await toPng(raw);
        result.set(epubPath.replace("../", ""), png);
      } catch (e) {
        console.warn(`[epub] 图片处理失败 ${spec}:`, (e as Error).message);
      }
    }
    return result;
  }

  private async loadRaw(spec: string): Promise<Buffer | null> {
    if (spec.startsWith("REMOTE::")) {
      const url = spec.slice("REMOTE::".length);
      const res = await fetch(url);
      if (!res.ok) {
        console.warn(`[epub] 远程图片下载失败 ${url}: ${res.status}`);
        return null;
      }
      return Buffer.from(await res.arrayBuffer());
    }
    if (spec.startsWith("CANDIDATES::")) {
      const cands = spec.slice("CANDIDATES::".length).split("|");
      const found = cands.find((c) => existsSync(c));
      if (!found) {
        console.warn(`[epub] 本地图片缺失: ${cands[0]}`);
        return null;
      }
      return readFileSync(found);
    }
    return existsSync(spec) ? readFileSync(spec) : null;
  }
}

/** 将任意图片字节（SVG / WebP / PNG / JPG / GIF）转换为 PNG 字节 */
export async function toPng(raw: Buffer): Promise<Uint8Array> {
  const head = raw.subarray(0, 64).toString("utf8");
  const isSvg = head.includes("<svg") || head.trimStart().startsWith("<?xml");
  if (isSvg) {
    const resvg = new Resvg(raw, { fitTo: { mode: "width", value: 1000 } });
    return resvg.render().asPng();
  }
  return new Uint8Array(
    await sharp(raw).png({ compressionLevel: 9, effort: 10 }).toBuffer(),
  );
}
