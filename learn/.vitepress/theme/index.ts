// .vitepress/theme/index.js
import DefaultTheme from "vitepress/theme";

import giscusTalk from "vitepress-plugin-comment-with-giscus";

import codeblocksFold from "vitepress-plugin-codeblocks-fold";
import "vitepress-plugin-codeblocks-fold/style/index.scss";

import "viewerjs/dist/viewer.min.css";
import imageViewer from "./ImgViewer";

import { useData, useRoute } from "vitepress";

export default {
  ...DefaultTheme,
  enhanceApp(ctx) {
    DefaultTheme.enhanceApp(ctx);
  },
  setup() {
    // Get frontmatter and route
    const { frontmatter } = useData();
    const route = useRoute();

    // code fold support
    codeblocksFold({ route, frontmatter }, true, 400);

    // imageView
    imageViewer(route);

    // Obtain configuration from: https://giscus.app/
    giscusTalk(
      {
        repo: "learnzig/learnzig",
        repoId: "R_kgDOKRsb5Q",
        category: "Comments", // default: `General`
        categoryId: "DIC_kwDOKRsb5c4Cbx2i",
        mapping: "pathname", // default: `pathname`
        inputPosition: "top", // default: `top`
        lang: "zh-CN", // default: `zh-CN`
        strict: "1",
        reactionsEnabled: "1",
        // theme:"dark",
        lightTheme: "light",
        darkTheme: "dark",
      },
      {
        frontmatter,
        route,
      },
      true,
    );
  },
};
