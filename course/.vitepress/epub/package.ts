import JSZip from "jszip";
import type { EpubConfig } from "./config.ts";
import type { Chapter } from "./sidebar.ts";
import { escapeXml, wrapXhtml } from "./render.ts";

export interface RenderedChapter {
  fileName: string;
  title: string;
  xhtml: string;
}

export interface PackageInput {
  config: EpubConfig;
  chapters: Chapter[];
  renderedChapters: RenderedChapter[];
  /** epubPath(去掉 ../) -> bytes，统一 PNG */
  images: Map<string, Uint8Array>;
  /** 子集化后的字体 */
  fonts: { cjk: Uint8Array; sans: Uint8Array; mono: Uint8Array };
  /** 样式表内容 */
  css: string;
  /** 封面 PNG 字节（可选） */
  cover?: Uint8Array | null;
}

function mimeOf(p: string): string {
  if (p.endsWith(".png")) return "image/png";
  if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return "image/jpeg";
  if (p.endsWith(".gif")) return "image/gif";
  if (p.endsWith(".svg")) return "image/svg+xml";
  return "application/octet-stream";
}

/** 组装并生成 EPUB3 二进制 */
export async function packageEpub(input: PackageInput): Promise<Uint8Array> {
  const { config, chapters, renderedChapters, images, fonts, css, cover } =
    input;
  const lang = config.language;
  const bookId = "urn:uuid:" + crypto.randomUUID();

  const zip = new JSZip();
  // mimetype 必须第一项且不压缩
  zip.file("mimetype", "application/epub+zip", { compression: "STORE" });

  zip.file(
    "META-INF/container.xml",
    `<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>`,
  );

  const oebps = zip.folder("OEBPS")!;
  oebps.file("styles/style.css", css);
  oebps.file("fonts/cjk.woff2", fonts.cjk);
  oebps.file("fonts/sans.woff2", fonts.sans);
  oebps.file("fonts/mono.woff2", fonts.mono);

  // 封面页 + 目录页
  const coverXhtml = wrapXhtml(
    "封面",
    `<div class="cover"><img src="../images/cover.png" alt="封面"/></div>`,
    lang,
  );
  const tocItems = chapters
    .map(
      (ch) =>
        `<li class="toc-l${Math.min(ch.item.level, 2)}"><a href="${ch.fileName}">${escapeXml(ch.item.text)}</a></li>`,
    )
    .join("\n");
  const tocXhtml = wrapXhtml(
    "目录",
    `<div class="toc-page"><h1>目录</h1><ul class="toc-list">\n${tocItems}\n</ul></div>`,
    lang,
  );

  if (cover) oebps.file("text/cover.xhtml", coverXhtml);
  oebps.file("text/toc.xhtml", tocXhtml);
  for (const rc of renderedChapters)
    oebps.file(`text/${rc.fileName}`, rc.xhtml);

  const allImages = new Map(images);
  if (cover) allImages.set("images/cover.png", cover);
  for (const [p, buf] of allImages) oebps.file(p, buf);

  // ---- manifest + spine ----
  const manifestItems: string[] = [
    `<item id="css" href="styles/style.css" media-type="text/css"/>`,
    `<item id="font-cjk" href="fonts/cjk.woff2" media-type="font/woff2"/>`,
    `<item id="font-sans" href="fonts/sans.woff2" media-type="font/woff2"/>`,
    `<item id="font-mono" href="fonts/mono.woff2" media-type="font/woff2"/>`,
    `<item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/>`,
  ];
  const spineItems: string[] = [];

  if (cover) {
    manifestItems.push(
      `<item id="cover-image" href="images/cover.png" media-type="image/png" properties="cover-image"/>`,
      `<item id="cover" href="text/cover.xhtml" media-type="application/xhtml+xml"/>`,
    );
    spineItems.push(`<itemref idref="cover" linear="yes"/>`);
  }
  manifestItems.push(
    `<item id="toc-page" href="text/toc.xhtml" media-type="application/xhtml+xml"/>`,
  );
  spineItems.push(`<itemref idref="toc-page" linear="yes"/>`);

  renderedChapters.forEach((rc, i) => {
    manifestItems.push(
      `<item id="chap${i + 1}" href="text/${rc.fileName}" media-type="application/xhtml+xml"/>`,
    );
    spineItems.push(`<itemref idref="chap${i + 1}" linear="yes"/>`);
  });

  let imgIdx = 0;
  for (const [p] of allImages) {
    if (p === "images/cover.png") continue;
    manifestItems.push(
      `<item id="img${++imgIdx}" href="${p}" media-type="${mimeOf(p)}"/>`,
    );
  }

  const opf = `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="${lang}">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">${bookId}</dc:identifier>
    <dc:title>${escapeXml(config.title)}</dc:title>
    <dc:creator>${escapeXml(config.author)}</dc:creator>
    <dc:language>${lang}</dc:language>
    <dc:publisher>${escapeXml(config.publisher)}</dc:publisher>
    <meta property="dcterms:modified">${new Date().toISOString().replace(/\.\d+Z$/, "Z")}</meta>
    ${cover ? '<meta name="cover" content="cover-image"/>' : ""}
  </metadata>
  <manifest>
    ${manifestItems.join("\n    ")}
  </manifest>
  <spine>
    ${spineItems.join("\n    ")}
  </spine>
</package>`;
  oebps.file("content.opf", opf);

  // ---- nav.xhtml ----
  const navList = chapters
    .map(
      (ch) =>
        `<li><a href="text/${ch.fileName}">${escapeXml(ch.item.text)}</a></li>`,
    )
    .join("\n      ");
  oebps.file(
    "nav.xhtml",
    `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="${lang}" lang="${lang}">
<head><meta charset="UTF-8"/><title>目录</title></head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>目录</h1>
    <ol>
      ${navList}
    </ol>
  </nav>
</body>
</html>`,
  );

  return zip.generateAsync({
    type: "uint8array",
    mimeType: "application/epub+zip",
    compression: "DEFLATE",
    compressionOptions: { level: 9 },
  });
}
