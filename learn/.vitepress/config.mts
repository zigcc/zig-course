import { defineConfig } from "vitepress";
import sidebar from "./sidebar";
import nav from "./nav";
import socialLinks from "./socialLinks";

export default defineConfig({
  lang: "zh-CN",
  title: "Learn Zig",
  description: "简单、快速地学习 Zig",
  themeConfig: {
    search: {
      provider: "local",
      // options: {
      // 	detailedView: true,
      // 	locales: {
      // 		zh: {
      // 			translations: {
      // 				button: {
      // 					buttonText: "搜索文档",
      // 					buttonAriaLabel: "搜索文档",
      // 				},
      // 				modal: {
      // 					noResultsText: "无法找到相关结果",
      // 					resetButtonTitle: "清除查询条件",
      // 					footer: {
      // 						selectText: "选择",
      // 						navigateText: "切换",
      // 					},
      // 				},
      // 			},
      // 		},
      // 	},
      // },
    },
    nav: nav,
    sidebar: sidebar,
    socialLinks: socialLinks,
  },
});
