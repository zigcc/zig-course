// .vitepress/vitepress-pdf.config.ts
import type { DefaultTheme } from "vitepress";
import { defineUserConfig } from "vitepress-export-pdf";

import sidebar from "./sidebar";

let links: string[] = [];

function ExtractLinks(item: DefaultTheme.SidebarItem) {
  if (item.link) {
    if (item.link === "/") {
      // 此处额外打了一个补丁，因为首页的链接是 /index
      links.push("/index");
    } else {
      links.push(item.link);
    }
  }

  if (item.items)
    for (const key in item.items) {
      ExtractLinks(item.items[key]);
    }
}

for (const key in sidebar) {
  ExtractLinks(sidebar[key]);
}

export default defineUserConfig({
  urlOrigin: "https://course.ziglang.cc/",
  outFile: "zig_course.pdf",
  outDir: "PDF",
  pdfOptions: {
    format: "A4",
    printBackground: true,
    displayHeaderFooter: false,
    margin: {
      bottom: 60,
      left: 25,
      right: 25,
      top: 60,
    },
  },
  routePatterns: [
    "/**",
    "!/",
    "!/404.html",
    "!/epilogue",
    "!/about",
    "!/code/**",
    "!/update/**",
    "!/appendix/**",
  ],
  sorter: (pageA, pageB) => {
    // console.log("比较", pageA, pageB);
    const aIndex = links.findIndex((route) => route === pageA.path);
    const bIndex = links.findIndex((route) => route === pageB.path);
    return aIndex - bIndex;
  },
});
