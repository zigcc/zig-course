import fs from "node:fs/promises";
import path from "node:path";
import type { Plugin, ViteDevServer } from "vite";

const ORIGIN = "https://course.ziglang.cc";
const SNIPPET_RE = /^<<<\s*(.+)$/gm;

interface Options {
  srcDir: string;
  outDir?: string;
}

export function llmMarkdownPlugin(options: Options): Plugin {
  let outDir = options.outDir;

  return {
    name: "zig-course-llm-markdown",
    configResolved(config) {
      outDir ??= config.build.outDir;
    },
    configureServer(server: ViteDevServer) {
      server.middlewares.use(async (req, res, next) => {
        if (!req.url?.startsWith("/llms/")) return next();

        try {
          const pathname = decodeURIComponent(
            new URL(req.url, "http://local").pathname,
          );
          const relativePath = pathname.slice("/llms/".length);
          const source = resolveInside(options.srcDir, relativePath);
          const origin = `${req.headers["x-forwarded-proto"] ?? "http"}://${req.headers.host}`;
          const markdown = await renderLlmMarkdown(
            source,
            options.srcDir,
            origin,
          );
          res.statusCode = 200;
          res.setHeader("Content-Type", "text/markdown; charset=utf-8");
          res.end(markdown);
        } catch (error) {
          res.statusCode = 404;
          res.end(error instanceof Error ? error.message : "Not found");
        }
      });
    },
    async closeBundle() {
      if (!outDir) return;
      await generateLlmMarkdown(options.srcDir, path.join(outDir, "llms"));
    },
  };
}

export async function generateLlmMarkdown(
  srcDir: string,
  outDir: string,
): Promise<void> {
  const files = await collectMarkdownFiles(srcDir);
  await fs.rm(outDir, { recursive: true, force: true });

  await Promise.all(
    files.map(async (file) => {
      const relativePath = normalizePath(path.relative(srcDir, file));
      const output = path.join(outDir, relativePath);
      await fs.mkdir(path.dirname(output), { recursive: true });
      await fs.writeFile(output, await renderLlmMarkdown(file, srcDir), "utf8");
    }),
  );
}

export async function renderLlmMarkdown(
  file: string,
  srcDir: string,
  origin = ORIGIN,
): Promise<string> {
  const relativePath = normalizePath(path.relative(srcDir, file));
  let markdown = await fs.readFile(file, "utf8");

  markdown = stripFrontmatter(markdown);
  markdown = await expandSnippets(markdown, srcDir);
  markdown = flattenVitePressContainers(markdown);
  markdown = absolutizeLinks(markdown, relativePath, origin);

  return markdown.trim() + "\n";
}

async function collectMarkdownFiles(dir: string): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files: string[] = [];

  for (const entry of entries) {
    if (entry.name === ".vitepress" || entry.name === "public") continue;

    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectMarkdownFiles(fullPath)));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(fullPath);
    }
  }

  return files;
}

async function expandSnippets(
  markdown: string,
  srcDir: string,
): Promise<string> {
  const replacements = await Promise.all(
    Array.from(markdown.matchAll(SNIPPET_RE), async (match) => {
      const snippet = await readSnippet(match[1].trim(), srcDir);
      return { from: match[0], to: snippet };
    }),
  );

  for (const { from, to } of replacements) {
    markdown = markdown.replace(from, to);
  }

  return markdown;
}

async function readSnippet(rawSpec: string, srcDir: string): Promise<string> {
  const [spec, ...labelParts] = rawSpec.split(/\s+/);
  const label = labelParts.join(" ").replace(/^\[(.*)\]$/, "$1");
  const languageOverride = spec.match(/\{([\w-]+)\}$/)?.[1];
  const specWithoutLanguage = spec.replace(/\{[\w-]+\}$/, "");
  const [rawFilePath, region] = specWithoutLanguage.split("#", 2);
  const filePath = rawFilePath.startsWith("@/")
    ? rawFilePath.slice(2)
    : rawFilePath;
  const sourcePath = resolveInside(srcDir, filePath);
  const source = await fs.readFile(sourcePath, "utf8");
  const code = region ? extractRegion(source, region) : source.trimEnd();
  if (code === null) {
    return `<!-- Missing snippet: ${rawSpec} -->`;
  }
  const language = languageOverride ?? languageFromFile(sourcePath);
  const title = label ? `**${label}**\n\n` : "";

  return `${title}\`\`\`${language}\n${code.trimEnd()}\n\`\`\``;
}

function extractRegion(source: string, region: string): string | null {
  const lines = source.split(/\r?\n/);
  const start = lines.findIndex((line) => line.includes(`#region ${region}`));
  if (start < 0) return null;

  const end = lines.findIndex(
    (line, index) => index > start && line.includes(`#endregion ${region}`),
  );
  if (end < 0) return null;

  return dedent(lines.slice(start + 1, end)).join("\n");
}

function dedent(lines: string[]): string[] {
  const indents = lines
    .filter((line) => line.trim().length > 0)
    .map((line) => line.match(/^\s*/)?.[0].length ?? 0);
  const minIndent = indents.length === 0 ? 0 : Math.min(...indents);

  return minIndent > 0 ? lines.map((line) => line.slice(minIndent)) : lines;
}

function flattenVitePressContainers(markdown: string): string {
  return markdown
    .split(/\r?\n/)
    .map((line) => {
      const open = line.match(/^:{3,}\s*([\w-]+)?\s*(.*)$/);
      if (open) {
        const type = open[1]?.toLowerCase();
        const title = open[2]?.trim();
        if (!type) return "";
        if (type === "code-group") return "";
        return `> [!${containerType(type)}]${title ? ` ${title}` : ""}`;
      }

      return /^:{3,}\s*$/.test(line) ? "" : line;
    })
    .join("\n");
}

function containerType(type: string): string {
  switch (type) {
    case "info":
      return "NOTE";
    case "tip":
      return "TIP";
    case "warning":
      return "WARNING";
    case "danger":
      return "CAUTION";
    case "details":
      return "DETAILS";
    default:
      return type.toUpperCase();
  }
}

function absolutizeLinks(
  markdown: string,
  currentFile: string,
  origin: string,
): string {
  return markdown.replace(
    /(!?\[[^\]]*\]\()([^\s)]+)((?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?)(\))/g,
    (_match, start, href, title, end) => {
      if (/^(https?:|mailto:|tel:|#)/.test(href))
        return `${start}${href}${title}${end}`;
      return `${start}${absoluteUrl(href, currentFile, origin)}${title}${end}`;
    },
  );
}

function absoluteUrl(
  href: string,
  currentFile: string,
  origin: string,
): string {
  const [rawPath, hash = ""] = href.split("#", 2);
  const suffix = hash ? `#${hash}` : "";
  const resolved = rawPath.startsWith("/")
    ? rawPath
    : `/${normalizePath(path.posix.normalize(path.posix.join(path.posix.dirname(currentFile), rawPath)))}`;

  return `${origin}${cleanRoute(resolved)}${suffix}`;
}

function cleanRoute(route: string): string {
  if (!route.endsWith(".md") && !route.endsWith(".html")) return route;
  return route
    .replace(/\/index\.md$/, "/")
    .replace(/\/index\.html$/, "/")
    .replace(/\.md$/, "")
    .replace(/\.html$/, "");
}

function stripFrontmatter(markdown: string): string {
  return markdown.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "");
}

function languageFromFile(filePath: string): string {
  const basename = path.basename(filePath);
  if (basename === "build.zig.zon") return "zig";
  const ext = path.extname(filePath).slice(1);
  return ext || "text";
}

function resolveInside(root: string, relativePath: string): string {
  const resolved = path.resolve(root, relativePath);
  const normalizedRoot = path.resolve(root);
  if (
    resolved !== normalizedRoot &&
    !resolved.startsWith(normalizedRoot + path.sep)
  ) {
    throw new Error(`Path escapes source root: ${relativePath}`);
  }
  return resolved;
}

function normalizePath(filePath: string): string {
  return filePath.split(path.sep).join("/");
}
