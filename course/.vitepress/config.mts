import { defineConfig } from "vitepress";
// import { withPwa } from "@vite-pwa/vitepress";
import themeConfig from "./themeConfig";

export default defineConfig({
  // pwa: {
  // 	registerType: "autoUpdate",
  // 	includeAssets: [
  // 		"favicon.ico",
  // 		"apple-touch-icon.png",
  // 		"safari-pinned-tab.svg",
  // 	],
  // 	manifest: {
  // 		name: "Zig 语言圣经",
  // 		short_name: "Zig 语言圣经",
  // 		description:
  // 			"简单、快速地学习 Zig，ziglang中文教程，zig中文教程",
  // 		icons: [
  // 			{
  // 				src: "android-chrome-192x192.png",
  // 				sizes: "192x192",
  // 				type: "image/png",
  // 			},
  // 			{
  // 				src: "android-chrome-512x512.png",
  // 				sizes: "512x512",
  // 				type: "image/png",
  // 			},
  // 		],
  // 		theme_color: "#ffffff",
  // 		background_color: "#ffffff",
  // 		display: "standalone",
  // 	},
  // 	strategies: "generateSW", // <== if omitted, defaults to `generateSW`
  // 	workbox: {
  // 		globPatterns: ["**/*.{css,js,html,svg,png,ico,txt,woff2}"],
  // 	},
  // },
  lang: "zh-CN",
  title: "Zig 语言圣经",
  description: "简单、快速地学习 Zig，ziglang中文教程，zig中文教程",
  sitemap: {
    hostname: "https://course.ziglang.cc/",
  },
  base: "/",
  lastUpdated: true,
  themeConfig: themeConfig,
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
});
