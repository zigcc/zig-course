// .vitepress/theme/index.ts
import type { Theme } from "vitepress";
import DefaultTheme from "vitepress/theme";

import giscus from "./giscus.js";
import version from "./version.js";
import copyToLLM from "./copyToLLM.js";
import {
  NolebaseEnhancedReadabilitiesMenu,
  NolebaseEnhancedReadabilitiesScreenMenu,
  InjectionKey as ReadabilitiesInjectionKey,
} from "@nolebase/vitepress-plugin-enhanced-readabilities/client";
import "@nolebase/vitepress-plugin-enhanced-readabilities/client/style.css";
import "./style/print.css";
import "./style/copyToLLM.css";

import { h } from "vue";

export default {
  extends: DefaultTheme,
  enhanceApp(ctx: any) {
    DefaultTheme.enhanceApp(ctx);
    // 仅启用 Layout Switch（关闭 Spotlight）；中文文案由站点 lang: zh-CN 自动匹配
    ctx.app.provide(ReadabilitiesInjectionKey, {
      spotlight: { disabled: true },
    });
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
    }
  },
  Layout() {
    return h(DefaultTheme.Layout, null, {
      "doc-after": () => h(giscus),
      "doc-before": () => [h(version), h(copyToLLM)],
      "nav-bar-content-after": () => h(NolebaseEnhancedReadabilitiesMenu),
      "nav-screen-content-after": () =>
        h(NolebaseEnhancedReadabilitiesScreenMenu),
    });
  },
} satisfies Theme;
