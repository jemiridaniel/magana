"use client";

// The APK's version, size and checksum, from /downloads/latest.json (scripts/publish-apk.sh).
import { useEffect, useState } from "react";
import { APK_URL } from "@/lib/site";

type Latest = { version: string; bytes: number; sha256: string };

export default function Download() {
  const [latest, setLatest] = useState<Latest | null>(null);
  useEffect(() => {
    fetch("/downloads/latest.json", { cache: "no-cache" })
      .then((r) => (r.ok ? r.json() : null))
      .then(setLatest)
      .catch(() => setLatest(null));
  }, []);
  const mb = latest ? Math.round(latest.bytes / 1048576) : 21;
  return (
    <div className="download-card">
      <p><strong>Magana for Android{latest ? `, version ${latest.version}` : ""}.</strong> Free. About {mb} MB.</p>
      <a href={APK_URL} className="btn btn-amber" download>
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
          <path d="M12 3v12M6.5 10.5L12 16l5.5-5.5M4 20h16" />
        </svg>
        Download the app
      </a>
      {latest && <p className="meta">To check the file: SHA-256 {latest.sha256}</p>}
    </div>
  );
}
