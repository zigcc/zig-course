import { defineConfig } from "vitepress";

export default defineConfig({
  lang: "zh-CN",
  title: "Learn Zig",
  description: "简单、快速地学习 Zig",
  themeConfig: {
    search: {
      provider: "local",
      options: {
        detailedView: true,
        locales: {
          zh: {
            translations: {
              button: {
                buttonText: "搜索文档",
                buttonAriaLabel: "搜索文档",
              },
              modal: {
                noResultsText: "无法找到相关结果",
                resetButtonTitle: "清除查询条件",
                footer: {
                  selectText: "选择",
                  navigateText: "切换",
                },
              },
            },
          },
        },
      },
    },
    nav: [
      { text: "主页", link: "/" },
      { text: "关于", link: "/about/" },
    ],

    sidebar: [
      {
        text: "什么是 Zig ？",
        link: "/what-is-zig",
      },
      {
        text: "环境配置",
        items: [
          {
            text: "安装 Zig 环境",
            link: "/basic/install-environment",
          },
          { text: "编辑器选择", link: "/basic/editor.md" },
        ],
      },
      {
        text: "基础学习",
        items: [
          {
            text: "安装 Zig 环境",
            link: "/basic/install-environment",
          },
        ],
      },
    ],

    socialLinks: [
      { icon: "github", link: "https://github.com/jinzhongjia/learnzig" },
    ],
  },
});
