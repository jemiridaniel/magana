import type { Metadata } from "next";
import Download from "@/components/Download";
import { readDoc } from "@/lib/markdown";

export const metadata: Metadata = { title: "Get the Android app" };

export default function Android() {
  return (
    <div className="page">
      <article className="prose" aria-labelledby="android-h">
        <h1 id="android-h">Get the Android app</h1>
        <Download />
        {/* docs/TESTER_INSTALL.md, up to the team-only part. */}
        <div className="prose" dangerouslySetInnerHTML={{ __html: readDoc("TESTER_INSTALL.md", { until: "## For the team", dropTitle: true }) }} />
      </article>
    </div>
  );
}
