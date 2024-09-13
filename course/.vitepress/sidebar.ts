import { DefaultTheme } from "vitepress";

export default [
  {
    text: "前言",
    link: "/prologue",
  },
  {
    text: "什么是 Zig ？",
    link: "/",
  },

  {
    text: "环境配置",
    items: [
      {
        text: "环境部署",
        link: "/environment/install-environment",
      },
      {
        text: "编辑器",
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
    link: "/hello-world",
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
            text: "向量",
            link: "/basic/advanced_type/vector",
          },
          {
            text: "指针",
            link: "/basic/advanced_type/pointer",
          },
          {
            text: "切片",
            link: "/basic/advanced_type/slice",
          },
          {
            text: "字符串",
            link: "/basic/advanced_type/string",
          },
          {
            text: "结构体",
            link: "/basic/advanced_type/struct",
          },
          {
            text: "枚举",
            link: "/basic/advanced_type/enum",
          },
          {
            text: "opaque",
            link: "/basic/advanced_type/opaque",
          },
        ],
      },
      {
        text: "联合类型",
        link: "/basic/union",
      },
      {
        text: "流程控制",
        collapsed: true,
        items: [
          {
            text: "条件",
            link: "/basic/process_control/decision",
          },
          {
            text: "循环",
            link: "/basic/process_control/loop",
          },
          {
            text: "switch匹配",
            link: "/basic/process_control/switch",
          },
          {
            text: "defer",
            link: "/basic/process_control/defer",
          },
          {
            text: "unreachable",
            link: "/basic/process_control/unreachable",
          },
        ],
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
        text: "编译期",
        link: "/advanced/comptime",
      },
      {
        text: "包管理",
        link: "/advanced/package_management",
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
      {
        text: "单元测试",
        link: "/engineering/unit-test",
      },
    ],
  },
  {
    text: "更多",
    items: [
      {
        text: "反射",
        link: "/more/reflection",
      },
      {
        text: "零位类型",
        link: "/more/zero-type",
      },
      {
        text: "原子操作",
        link: "/more/atomic",
      },
      {
        text: "未定义行为",
        link: "/more/undefined_behavior",
      },
      {
        text: "风格指南",
        link: "/more/style_guide",
      },
      {
        text: "杂项",
        link: "/more/miscellaneous",
      },
    ],
  },
  {
    text: "示例",
    items: [
      {
        text: "echo server",
        link: "/examples/echo_tcp_server",
      },
    ],
  },
  {
    text: "版本说明",
    collapsed: true,
    items: [
      {
        text: "0.12.0 升级指南",
        link: "/update/upgrade-0.12.0",
      },
      {
        text: "0.12.0 版本说明",
        link: "/update/0.12.0-description",
      },
      {
        text: "0.13.0 升级指南",
        link: "/update/upgrade-0.13.0",
      },
      {
        text: "0.13.0 版本说明",
        link: "/update/0.13.0-description",
      },
    ],
  },
  {
    text: "附录",
    items: [
      {
        text: "贡献者公约",
        link: "/appendix/contributor-covenant",
      },
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
