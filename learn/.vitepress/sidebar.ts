import { DefaultTheme } from "vitepress";

export default [
  {
    text: "前言",
    link: "/prologue",
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
        link: "/environment/editor",
      },
      {
        text: "zig 命令",
        link: "/environment/zig-command",
      },
    ],
  },
  {
    text: "Hello World",
    link: "/basic/hello-world",
  },
  {
    text: "基础学习",
    items: [
      {
        text: "变量声明",
        link: "/basic/define-variable",
      },

      {
        text: "基本类型",
        collapsed: true,
        items: [
          {
            text: "数值类型",
            link: "/basic/basic_type/number",
          },
          {
            text: "字符与布尔值",
            link: "/basic/basic_type/char-and-boolean",
          },
          {
            text: "函数",
            link: "/basic/basic_type/function",
          },
        ],
      },
      {
        text: "高级类型",
        collapsed: true,
        items: [
          {
            text: "数组",
            link: "/basic/advanced_type/array",
          },
          {
            text: "指针",
            link: "/basic/advanced_type/pointer",
          },
          {
            text: "切片",
            link: "/basic/advanced_type/silce",
          },
          {
            text: "结构体",
            link: "/basic/advanced_type/struct",
          },
          {
            text: "枚举",
            link: "/basic/advanced_type/enum",
          },
        ],
      },
      {
        text: "流程控制",
        collapsed: true,
        items: [],
      },
      {
        text: "可选类型",
        link: "/basic/optional_type",
      },
      {
        text: "错误处理",
        link: "/basic/error_handle",
      },
    ],
  },
  {
    text: "进阶学习",
    items: [
      {
        text: "类型转换",
        link: "/advanced/type_cast",
      },
      {
        text: "内存管理",
        link: "/advanced/memory_manage",
      },
      {
        text: "异步",
        link: "/advanced/async",
      },
      {
        text: "模块系统",
        link: "/advanced/module-system",
      },
      {
        text: "编译期",
        link: "/advanced/comptime",
      },
      {
        text: "汇编",
        link: "/advanced/assembly",
      },
      {
        text: "与 C 交互",
        link: "/advanced/interact-with-c",
      },
    ],
  },
  {
    text: "工程化",
    items: [
      {
        text: "构建系统",
        link: "/engineering/build-system",
      },
    ],
  },
  {
    text: "附录",
    items: [
      // {
      //   text: "后记",
      //   link: "/epilogue",
      // },
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
