import { defineConfig } from "vitepress";
import { withPwa } from "@vite-pwa/vitepress";
import path from "node:path";
import { fileURLToPath } from "node:url";

import themeConfig from "./themeConfig.js";
import { llmMarkdownPlugin } from "./llmMarkdown.js";

export default withPwa(
  defineConfig({
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
    pwa: {
      registerType: "autoUpdate",
      manifest: {
        name: "Zig 语言圣经",
        short_name: "Zig 圣经",
        description: "简单、快速地学习 Zig，ziglang中文教程，zig中文教程",
        lang: "zh-CN",
        theme_color: "#ffffff",
        background_color: "#ffffff",
        display: "standalone",
        start_url: "/",
        scope: "/",
        icons: [
          {
            src: "/android-chrome-192x192.png",
            sizes: "192x192",
            type: "image/png",
          },
          {
            src: "/android-chrome-512x512.png",
            sizes: "512x512",
            type: "image/png",
          },
          // ponytail: 暂不声明 purpose:"maskable"（现有图标无安全区会被裁切）；
          //           需要更好的安装图标体验再加一张专用 maskable 图（512x512，留安全区）。
        ],
      },
      workbox: {
        // 全站静态资源仅几 MB，单文件均 < 2 MiB，可全量预缓存 → 离线可读全部章节
        globPatterns: ["**/*.{js,css,html,svg,png,ico,woff2}"],
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
  }),
);
