import { defineComponent, h } from "vue";

import { useData, useRoute } from "vitepress";
import Giscus from "@giscus/vue";

const is_dev = process.env.NODE_ENV === "development";

export default defineComponent({
  setup() {
    const { isDark, title, frontmatter } = useData();

    return () =>
      is_dev ||
      !(typeof frontmatter.value.comments == "undefined"
        ? true
        : frontmatter.value.comments)
        ? h("div")
        : h(
            "div",
            {
              style: {
                marginTop: "20px",
              },
              key: title.value,
              class: "giscus",
            },
            h(Giscus, {
              repo: "zigcc/zig-course",
              repoId: "R_kgDOKRsb5Q",
              category: "Comments",
              categoryId: "DIC_kwDOKRsb5c4Cbx2i",
              mapping: "pathname",
              strict: "1",
              reactionsEnabled: "1",
              emitMetadata: "0",
              inputPosition: "top",
              theme: isDark.value ? "dark" : "light",
              lang: "zh-CN",
            }),
          );
  },
});
