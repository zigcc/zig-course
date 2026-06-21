import { defineConfig } from "vitepress";
import path from "node:path";
import { fileURLToPath } from "node:url";

import themeConfig from "./themeConfig.js";
import { llmMarkdownPlugin } from "./llmMarkdown.js";

export default defineConfig({
  lang: "zh-CN",
  title: "Zig 语言圣经",
  description: "简单、快速地学习 Zig，ziglang中文教程，zig中文教程",
  sitemap: {
    hostname: "https://course.ziglang.cc/",
  },
  base: "/",
  lastUpdated: true,
  themeConfig: themeConfig,
  cleanUrls: true,
  vite: {
    plugins: [
      llmMarkdownPlugin({
        srcDir: path.resolve(
          path.dirname(fileURLToPath(import.meta.url)),
          "..",
        ),
        outDir: path.resolve(
          path.dirname(fileURLToPath(import.meta.url)),
          "dist",
        ),
      }),
    ],
  },
  head: [
    ["link", { rel: "icon", href: "./favicon.ico" }],
    [
      "link",
      {
        rel: "apple-touch-icon",
        href: "./apple-touch-icon.png",
        sizes: "180x180",
      },
    ],
    [
      "link",
      {
        rel: "mask-icon",
        href: "./logo-square.svg",
        color: "#FFFFFF",
      },
    ],
    ["meta", { name: "theme-color", content: "#ffffff" }],
  ],
  markdown: {
    image: {
      lazyLoading: true,
    },
  },
});
