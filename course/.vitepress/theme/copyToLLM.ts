import { computed, defineComponent, h, ref } from "vue";
import { useData, withBase } from "vitepress";

const actionRowStyle = {
  display: "flex",
  alignItems: "center",
  gap: "18px",
  margin: "12px 0 24px",
} as const;

const triggerStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: "8px",
  padding: "0",
  border: "0",
  background: "transparent",
  color: "var(--vp-c-text-2)",
  fontSize: "14px",
  fontWeight: "500",
  lineHeight: "24px",
  cursor: "pointer",
} as const;

const menuStyle = {
  position: "absolute",
  left: "0",
  top: "calc(100% + 8px)",
  zIndex: "10",
  minWidth: "210px",
  padding: "6px",
  border: "1px solid var(--vp-c-divider)",
  borderRadius: "8px",
  background: "var(--vp-c-bg-elv)",
  boxShadow: "var(--vp-shadow-3)",
} as const;

const itemStyle = {
  display: "block",
  width: "100%",
  padding: "8px 10px",
  border: "0",
  borderRadius: "6px",
  background: "transparent",
  color: "var(--vp-c-text-1)",
  textAlign: "left",
  cursor: "pointer",
  fontSize: "13px",
  lineHeight: "18px",
} as const;

export default defineComponent({
  setup() {
    const { frontmatter, page } = useData();
    const open = ref(false);
    const copied = ref<"link" | "markdown" | "error" | null>(null);
    const llmPath = computed(() => withBase(`/llms/${page.value.filePath}`));
    const llmUrl = computed(() =>
      typeof window === "undefined"
        ? ""
        : new URL(llmPath.value, window.location.origin).href,
    );

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

      return h("div", { class: "copy_llm", style: actionRowStyle }, [
        h("div", { style: { position: "relative", display: "inline-block" } }, [
          h(
            "button",
            {
              type: "button",
              style: triggerStyle,
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
            ? h("div", { style: menuStyle }, [
                h(
                  "button",
                  {
                    type: "button",
                    style: itemStyle,
                    onClick: () => copy("link"),
                  },
                  "复制 Markdown 链接",
                ),
                h(
                  "button",
                  {
                    type: "button",
                    style: itemStyle,
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
