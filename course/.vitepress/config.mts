import { defineConfig } from "vitepress";
import themeConfig from "./themeConfig";

export default defineConfig({
  lang: "zh-CN",
  title: "Zig 语言圣经",
  description: "简单、快速地学习 Zig，ziglang中文教程，zig中文教程，",
  sitemap: {
    hostname: "https://zigcc.github.io/zig-course/",
  },
  base: "/zig-course/",
  lastUpdated: true,
  themeConfig: themeConfig,
});
