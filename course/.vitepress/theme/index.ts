// .vitepress/theme/index.js
import DefaultTheme from "vitepress/theme";

import "viewerjs/dist/viewer.min.css";
import imageViewer from "./ImgViewer";

import giscus from "./giscus";

import { useRoute } from "vitepress";
import { h } from "vue";

export default {
  ...DefaultTheme,
  enhanceApp(ctx: any) {
    DefaultTheme.enhanceApp(ctx);
  },
  Layout() {
    return h(DefaultTheme.Layout, null, {
      "doc-after": () => h(giscus),
    });
  },
  setup() {
    const route = useRoute();

    // imageView
    imageViewer(route);
  },
};
