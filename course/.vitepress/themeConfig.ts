import { DefaultTheme } from "vitepress";
import sidebar from "./sidebar";
import nav from "./nav";
import socialLinks from "./socialLinks";

const config: DefaultTheme.Config = {
  editLink: {
    pattern: "https://github.com/zigcc/zig-course/tree/main/course/:path",
  },
  search: {
    provider: "local",
    options: {
      locales: {
        root: {
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
  nav: nav,
  sidebar: sidebar,
  socialLinks: socialLinks,
};

export default config;
