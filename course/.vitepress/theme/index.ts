// .vitepress/theme/index.js
import DefaultTheme from "vitepress/theme";

import giscus from "./giscus";
import version from "./version.vue";

import { h } from "vue";

export default {
  ...DefaultTheme,
  enhanceApp(ctx: any) {
    DefaultTheme.enhanceApp(ctx);
  },
  Layout() {
    return h(DefaultTheme.Layout, null, {
      "doc-after": () => h(giscus),
      "doc-before": () => h(version),
    });
  },
};
