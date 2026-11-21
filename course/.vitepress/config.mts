import { defineConfig } from "vitepress";
import path from "node:path";
import { fileURLToPath } from "node:url";

import themeConfig from "./themeConfig.js";
import { llmMarkdownPlugin } from "./llmMarkdown.js";

const title = "Zig 语言圣经";
const description = "简单、快速地学习 Zig，ziglang中文教程，zig中文教程";

export default defineConfig({
  lang: "zh-CN",
  title,
  description,
  sitemap: {
    hostname: "https://course.ziglang.cc/",
  },
  base: "/",
  lastUpdated: true,
  themeConfig: themeConfig,
  cleanUrls: true,
  vue: {
    template: {
      compilerOptions: {
        // <llm-only> 是自定义元素：网页端由 CSS 隐藏，正文只进入 /llms 输出
        isCustomElement: (tag) => tag === "llm-only",
      },
    },
  },
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
        title,
        description,
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
