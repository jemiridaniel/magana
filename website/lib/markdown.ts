// The text pages come from the repo's own docs at build time, so the website never drifts from
// them: docs/PRIVACY.md, docs/ACCESSIBILITY.md and docs/TESTER_INSTALL.md.
import { readFileSync } from "node:fs";
import path from "node:path";
import { Marked } from "marked";
import { REPO_URL } from "@/lib/site";

const DOCS = path.join(process.cwd(), "..", "docs");

export function readDoc(name: string, opts: { until?: string; dropTitle?: boolean } = {}): string {
  let md = readFileSync(path.join(DOCS, name), "utf8");
  if (opts.until) {
    const cut = md.indexOf(opts.until);
    if (cut < 0) throw new Error(`${name}: "${opts.until}" not found`);
    md = md.slice(0, cut).replace(/\n-{3,}\s*$/, "\n");
  }
  // The page has its own h1, so the doc's title goes and its ## sections stay h2.
  if (opts.dropTitle) md = md.replace(/^# .*\n/, "");
  // Mentions of repo files (`docs/MODELS.md`, docs/MODELS.md) link to them on GitHub.
  md = md.replace(/`?((?:docs|backend|app|portal|content)\/[\w./-]+\.\w+)`?/g, (_m, p: string) => `[${p}](${REPO_URL}/blob/main/${p})`);
  return toHtml(md);
}

function toHtml(md: string): string {
  const marked = new Marked({ gfm: true });
  let html = marked.parse(md, { async: false }) as string;
  // Wide tables scroll inside their own box (focusable, so keyboards can scroll it too).
  html = html.replace(/<table>/g, '<div class="table-wrap" tabindex="0" role="region" aria-label="Table (scrolls sideways)"><table>')
    .replace(/<\/table>/g, "</table></div>");
  return html;
}
