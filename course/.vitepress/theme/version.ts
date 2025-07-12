import { defineComponent, h, ref, computed } from "vue";
import type { Ref, ComputedRef } from "vue";

import { useData } from "vitepress";
import { version } from "./config.js";

export default defineComponent({
  setup() {
    const { isDark, frontmatter } = useData();

    const currentVersion: Ref<string> = ref(version);

    const fontColor: ComputedRef<string> = computed(() =>
      isDark.value ? "#fff" : "#000",
    );

    const backgroundColor: ComputedRef<string> = computed(() =>
      isDark.value ? "#14120F" : "#ebedf0",
    );

    return () =>
      (
        typeof frontmatter.value.showVersion == "undefined"
          ? true
          : frontmatter.value.showVersion
      )
        ? h(
            "div",
            {
              class: "version_tag",
              style: {
                color: fontColor.value,
                borderRadius: "15px",
                backgroundColor: backgroundColor.value,
                padding: "5px 10px",
                marginBottom: "10px",
                display: "inline-block",
              },
            },
            `zig 版本：${currentVersion.value}`,
          )
        : h("div");
  },
});
