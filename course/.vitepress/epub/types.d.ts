// 为缺少官方类型声明的依赖补充最小类型定义
declare module "subset-font" {
  interface SubsetOptions {
    targetFormat?: "sfnt" | "woff" | "woff2" | "truetype";
    preserveNameIds?: number[];
    variationAxes?: Record<string, number>;
  }
  /** 将字体裁剪为仅包含 text 中出现的字形 */
  export default function subsetFont(
    font: Buffer | Uint8Array,
    text: string,
    options?: SubsetOptions,
  ): Promise<Buffer>;
}
