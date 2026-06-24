import { computed, defineComponent, h, onMounted, onUnmounted, ref } from "vue";
import { useData, withBase } from "vitepress";

export default defineComponent({
  setup() {
    const { frontmatter, page } = useData();
    const open = ref(false);
    const copied = ref<"link" | "markdown" | "error" | null>(null);
    const rootRef = ref<HTMLElement | null>(null);
    const llmPath = computed(() => withBase(`/llms/${page.value.filePath}`));
    const llmUrl = computed(() =>
      typeof window === "undefined"
        ? ""
        : new URL(llmPath.value, window.location.origin).href,
    );

    function onDocumentClick(event: MouseEvent): void {
      if (open.value && !rootRef.value?.contains(event.target as Node)) {
        open.value = false;
      }
    }

    function onKeydown(event: KeyboardEvent): void {
      if (open.value && event.key === "Escape") open.value = false;
    }

    onMounted(() => {
      document.addEventListener("click", onDocumentClick);
      document.addEventListener("keydown", onKeydown);
    });

    onUnmounted(() => {
      document.removeEventListener("click", onDocumentClick);
      document.removeEventListener("keydown", onKeydown);
    });

    async function copyText(text: string): Promise<void> {
      if (navigator.clipboard) {
        await navigator.clipboard.writeText(text);
        return;
      }

      const textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      textarea.remove();
    }

    async function copy(kind: "link" | "markdown"): Promise<void> {
      try {
        // 链接：直接复制裸 URL（不是 [标题](URL) 这种 Markdown 超链接格式）
        const text =
          kind === "link"
            ? llmUrl.value
            : await fetch(llmPath.value)
                .then((response) => {
                  if (!response.ok) throw new Error(`HTTP ${response.status}`);
                  return response.text();
                })
                .then(localizeMarkdownOrigin);

        await copyText(text);
        copied.value = kind;
      } catch {
        copied.value = "error";
      } finally {
        open.value = false;
        window.setTimeout(() => {
          copied.value = null;
        }, 1500);
      }
    }

    function localizeMarkdownOrigin(markdown: string): string {
      if (
        typeof window === "undefined" ||
        !["localhost", "127.0.0.1"].includes(window.location.hostname)
      ) {
        return markdown;
      }

      return markdown.replaceAll(
        "https://course.ziglang.cc",
        window.location.origin,
      );
    }

    return () => {
      if (frontmatter.value.copyToLLM === false || page.value.isNotFound) {
        return null;
      }

      return h("div", { class: "copy_llm", ref: rootRef }, [
        h("div", { class: "copy_llm-wrapper" }, [
          h(
            "button",
            {
              type: "button",
              class: "copy_llm-trigger",
              "aria-haspopup": "menu",
              "aria-expanded": open.value ? "true" : "false",
              onClick: () => {
                open.value = !open.value;
              },
            },
            [
              h(
                "svg",
                {
                  width: "18",
                  height: "18",
                  viewBox: "0 0 24 24",
                  fill: "none",
                  stroke: "currentColor",
                  "stroke-width": "2",
                  "stroke-linecap": "round",
                  "stroke-linejoin": "round",
                  "aria-hidden": "true",
                },
                [
                  h("rect", {
                    x: "9",
                    y: "9",
                    width: "13",
                    height: "13",
                    rx: "2",
                    ry: "2",
                  }),
                  h("path", {
                    d: "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1",
                  }),
                ],
              ),
              copied.value === "error"
                ? "复制失败"
                : copied.value
                  ? "已复制"
                  : "复制给 LLM",
              h(
                "svg",
                {
                  width: "14",
                  height: "14",
                  viewBox: "0 0 24 24",
                  fill: "none",
                  stroke: "currentColor",
                  "stroke-width": "2",
                  "stroke-linecap": "round",
                  "stroke-linejoin": "round",
                  "aria-hidden": "true",
                },
                [h("path", { d: "m6 9 6 6 6-6" })],
              ),
            ],
          ),
          open.value
            ? h("div", { class: "copy_llm-menu", role: "menu" }, [
                h(
                  "button",
                  {
                    type: "button",
                    class: "copy_llm-item",
                    role: "menuitem",
                    onClick: () => copy("link"),
                  },
                  "复制 Markdown 链接",
                ),
                h(
                  "button",
                  {
                    type: "button",
                    class: "copy_llm-item",
                    role: "menuitem",
                    onClick: () => copy("markdown"),
                  },
                  "复制 Markdown 正文",
                ),
              ])
            : null,
        ]),
      ]);
    };
  },
});
