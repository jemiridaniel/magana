"use client";

// "Download for Android": the button always goes to /download/android, which redirects to the
// newest GitHub release's magana.apk (public/_redirects, scripts/publish-apk.sh). Its version,
// size and date come from /downloads/latest.json, which CI copies from that release. The install
// steps are real text and never depend on that file.
import { useEffect, useState } from "react";
import { APK_URL } from "@/lib/site";

type Latest = { version: string; bytes: number; date?: string; sha256: string };

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const day = (iso: string) => {
  const [y, m, d] = iso.split("-").map(Number);
  return `${d} ${MONTHS[m - 1]} ${y}`;
};

export default function Download() {
  const [latest, setLatest] = useState<Latest | null>(null);
  useEffect(() => {
    fetch("/downloads/latest.json", { cache: "no-cache" })
      .then((r) => (r.ok ? r.json() : null))
      .then(setLatest)
      .catch(() => setLatest(null));
  }, []);
  return (
    <div className="download-card">
      <a href={APK_URL} className="btn btn-amber">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
          <path d="M12 3v12M6.5 10.5L12 16l5.5-5.5M4 20h16" />
        </svg>
        Download for Android
      </a>
      <ul className="download-facts">
        <li>{latest ? `Version ${latest.version}` : "The newest test version"}</li>
        {latest && <li>{Math.round(latest.bytes / 1048576)} MB</li>}
        {latest?.date && <li>Released {day(latest.date)}</li>}
        <li>Android 7 or newer</li>
      </ul>
      <h2 className="download-steps-h">Install it in 3 steps</h2>
      <ol className="download-steps">
        <li><strong>Allow installs from your browser.</strong> When your phone asks, tap Settings and turn on “Allow from this source”.</li>
        <li><strong>Open the file</strong> you downloaded, called magana.apk, from the notification or your Downloads.</li>
        <li><strong>Tap Install.</strong> If Play Protect warns you, tap More details, then Install anyway.</li>
      </ol>
      {latest && <p className="meta">To check the file: SHA-256 {latest.sha256}</p>}
    </div>
  );
}
