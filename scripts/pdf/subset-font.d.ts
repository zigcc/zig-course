// subset-font 无官方类型，仅声明本项目用到的最小签名。
declare module "subset-font" {
  interface SubsetOptions {
    targetFormat?: "sfnt" | "woff" | "woff2" | "truetype";
    variationAxes?: Record<string, number>;
  }
  export default function subsetFont(
    font: Buffer | Uint8Array,
    text: string,
    options?: SubsetOptions,
  ): Promise<Buffer>;
}
