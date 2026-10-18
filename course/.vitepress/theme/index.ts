// .vitepress/theme/index.ts
/// <reference types="vite-plugin-pwa/client" />
import type { Theme } from "vitepress";
import DefaultTheme from "vitepress/theme";

import giscus from "./giscus.js";
import version from "./version.js";
import copyToLLM from "./copyToLLM.js";
import "./style/print.css";
import "./style/copyToLLM.css";

import { h } from "vue";

export default {
  extends: DefaultTheme,
  enhanceApp(ctx: any) {
    DefaultTheme.enhanceApp(ctx);
    if (typeof window != "undefined") {
      // 保证在打印时所有的 details 都是展开的
      window.addEventListener("beforeprint", function () {
        document.querySelectorAll("details").forEach(function (details) {
          details.setAttribute("open", "");
        });
      });

      // 打印后重置 details 的展开状态
      window.addEventListener("afterprint", function () {
        document.querySelectorAll("details").forEach(function (details) {
          details.removeAttribute("open");
        });
      });

      // 注册 Service Worker。插件默认注入的 registerSW.js 只负责注册，新版本激活后页面不会刷新，
      // 读者会继续看到预缓存的旧内容；改用 virtual:pwa-register 后，autoUpdate 模式会在新版本激活时自动刷新页面。
      // 引入该模块后，插件也不再注入 registerSW.js。
      import("virtual:pwa-register").then(({ registerSW }) => {
        registerSW({ immediate: true });
      });
    }
  },
  Layout() {
    return h(DefaultTheme.Layout, null, {
      "doc-after": () => h(giscus),
      "doc-before": () => [h(version), h(copyToLLM)],
    });
  },
} satisfies Theme;
