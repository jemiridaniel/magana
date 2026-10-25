import type { Metadata } from "next";
import { readDoc } from "@/lib/markdown";

export const metadata: Metadata = { title: "Accessibility statement" };

export default function Accessibility() {
  return (
    <div className="page">
      <article className="prose" aria-labelledby="a11y-h">
        <h1 id="a11y-h">Accessibility statement</h1>
        <div className="prose" dangerouslySetInnerHTML={{ __html: readDoc("ACCESSIBILITY.md", { dropTitle: true }) }} />
      </article>
    </div>
  );
}
