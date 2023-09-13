import { DefaultTheme } from "vitepress";

export default [
  {
    text: "前言",
    link: "/preface",
  },
  {
    text: "什么是 Zig ？",
    link: "/what-is-zig",
  },

  {
    text: "环境配置",
    items: [
      {
        text: "安装 Zig 环境",
        link: "/environment/install-environment",
      },
      {
        text: "编辑器选择",
        link: "/environment/editor.md",
      },
      {
        text: "zig 命令",
        link: "/environment/zig-command",
      },
    ],
  },
  {
    text: "基础学习",
    items: [
      {
        text: "Hello World",
        link: "/basic/hello-world",
      },
    ],
  },
  {
    text: "进阶学习",
    items: [
      // {
      // 	text: "安装 Zig 环境",
      // 	link: "/basic/install-environment",
      // },
    ],
  },
  {
    text: "附录",
    items: [
      {
        text: "社区",
        link: "/appendix/community",
      },
      {
        text: "第三方库",
        link: "/appendix/well-known-lib",
      },
    ],
  },
] as DefaultTheme.Sidebar;
