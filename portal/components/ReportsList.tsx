"use client";

// Reports (board 9 "Report a problem"): what learners and teachers reported from the app, newest
// first. Every team role, Support included. A voice note plays only when asked (and the play is
// logged); page text is there only when the person chose to include it. Kept 180 days.
import { useEffect, useState } from "react";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ProblemReport } from "@/lib/portal";

const LANGUAGES: Record<string, string> = { en: "English", ha: "Hausa", yo: "Yorùbá", ig: "Igbo" };

function VoiceNote({ r }: { r: ProblemReport }) {
  const [url, setUrl] = useState<string | null>(null);
  const [error, setError] = useState("");
  useEffect(() => () => { if (url) URL.revokeObjectURL(url); }, [url]);
  if (!r.voice_seconds) return <span>None</span>;
  if (url) return <audio controls autoPlay src={url} aria-label={`Voice note, ${r.voice_seconds} seconds`} />;
  return (
    <>
      <button type="button" className="btn" onClick={async () => {
        try { setUrl(URL.createObjectURL(await portal.reportVoice(r.id))); } catch (e) { setError(messageFor((e as PortalError).code)); }
      }}>Play voice note ({r.voice_seconds} s)<span className="visually-hidden">, {r.kind_label}, {r.when}</span></button>
      {error && <p role="alert">{error}</p>}
    </>
  );
}

export default function ReportsList() {
  const [rows, setRows] = useState<ProblemReport[] | null>(null);
  const [error, setError] = useState("");
  useEffect(() => { portal.reports().then(setRows).catch((e) => setError((e as PortalError).code)); }, []);
  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  return (
    <>
      <div className="page-head"><div><h1>Reports</h1>
        <p>Problems reported from the app, newest first. Kept 180 days. Each new report is also emailed to support.</p></div></div>
      {rows && (rows.length === 0 ? <p className="empty">No reports yet.</p> : (
        <div className="table-wrap table-box" role="region" aria-label="Reports" tabIndex={0}>
          <table>
            <thead><tr><th scope="col">When</th><th scope="col">What went wrong</th><th scope="col">Where</th>
              <th scope="col">Phone and app</th><th scope="col">Voice note</th><th scope="col">Page text</th></tr></thead>
            <tbody>{rows.map((r) => (
              <tr key={r.id}>
                <td>{r.when}</td>
                <th scope="row">{r.kind_label}<span className="sub">{r.age_group}</span></th>
                <td>{r.screen.replace(/_/g, " ")}<span className="sub">{LANGUAGES[r.language] ?? r.language}</span></td>
                <td>{r.phone_model}<span className="sub">Version {r.app_version}</span></td>
                <td><VoiceNote r={r} /></td>
                <td>{r.page_text
                  ? <details><summary>Show page text<span className="visually-hidden">, {r.kind_label}, {r.when}</span></summary>
                      <p className="box report-text">{r.page_text}</p></details>
                  : "Not included"}</td>
              </tr>))}</tbody>
          </table>
        </div>
      ))}
    </>
  );
}
