import type { Metadata } from "next";
import { readDoc } from "@/lib/markdown";

export const metadata: Metadata = { title: "Privacy notice" };

export default function Privacy() {
  return (
    <div className="page">
      <article className="prose" aria-labelledby="privacy-h">
        <h1 id="privacy-h">Privacy notice</h1>
        <div className="prose" dangerouslySetInnerHTML={{ __html: readDoc("PRIVACY.md", { dropTitle: true }) }} />
      </article>
    </div>
  );
}
