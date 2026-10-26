"use client";

// Check an upload: every line Magana read, with handwritten and unsure lines marked. The
// teacher corrects them and approves; until then the upload stays at "Check" and learners
// don't get it (uploads_api.py; docs/review/handwriting_signoff.md, rule 7).
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState, type FormEvent } from "react";
import { UploadStatus } from "@/components/UploadsView";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type UploadInfo, type UploadLine } from "@/lib/portal";

const NUMBER = new Set(["unreadable_number", "low_confidence_number", "number_mismatch", "handwritten_number"]);

function reasons(l: UploadLine): string[] {
  const out: string[] = [];
  if (l.handwritten) out.push("Handwritten");
  if (l.flags.some((f) => NUMBER.has(f))) out.push("Check the number");
  if (l.flags.some((f) => f === "line_end_unclear" || f === "line_part_unclear")) out.push("Part not read");
  if (l.flags.includes("low_confidence")) out.push("Magana was unsure");
  return out;
}

function Check() {
  const id = useSearchParams().get("id") ?? "";
  const [upload, setUpload] = useState<(UploadInfo & { lines: UploadLine[] }) | null>(null);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    portal.upload(id).then(setUpload).catch((e) => setError((e as PortalError).code));
  }, [id]);

  async function save(e: FormEvent<HTMLFormElement>, approve: boolean) {
    e.preventDefault();
    if (!upload) return;
    const data = new FormData(e.currentTarget);
    const lines = upload.lines.map((_, i) => String(data.get(`line-${i}`) ?? ""));
    try {
      const r = await portal.checkUpload(id, lines, approve);
      setUpload(r.upload);
      setMessage(messageFor(r.code));
    } catch (err) {
      setMessage(messageFor((err as PortalError).code));
    }
  }

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  if (!upload) return <p role="status">Loading…</p>;
  const flagged = upload.lines.filter((l) => reasons(l).length).length;
  const ready = upload.status === "ready" || upload.status === "shared";

  return (
    <>
      <p><Link className="btn" href="/uploads/">Back to uploads</Link></p>
      <div className="page-head"><div><h1>{upload.title}</h1>
        <p><UploadStatus u={upload} /> {upload.lines.length} lines; {flagged} to check.</p></div></div>
      {upload.script !== "printed" && (
        <p className="note">
          {upload.script === "handwritten" ? "This upload looks handwritten." : "Part of this upload looks handwritten."} Magana
          reads handwriting less reliably, so read each marked line against the paper and correct it. Numbers matter most.
        </p>
      )}
      <form className="card form-grid" onSubmit={(e) => save(e, (e.nativeEvent as SubmitEvent).submitter?.id === "approve")}
            aria-labelledby="lines-h">
        <h2 id="lines-h">{ready ? "Approved text" : "Check each line"}</h2>
        <ol className="check-lines">
          {upload.lines.map((l, i) => {
            const why = reasons(l);
            return (
              <li key={i} className={why.length ? "needs-check" : undefined}>
                <label htmlFor={`line-${i}`}>
                  Line {i + 1}{l.page ? ` (page ${l.page})` : ""}
                  {why.map((w) => <span key={w} className="pill pill-check">{w}</span>)}
                  {l.corrected && <span className="pill pill-ready">Corrected</span>}
                </label>
                <textarea id={`line-${i}`} name={`line-${i}`} className="input" rows={Math.max(1, Math.ceil(l.text.length / 70))}
                          defaultValue={l.text} />
              </li>
            );
          })}
        </ol>
        <p className="status-msg" role="status">{message}</p>
        <div className="actions">
          {ready ? <button type="submit" id="approve" className="btn btn-primary">Save changes</button> : <>
            <button type="submit" id="save" className="btn">Save corrections</button>
            <button type="submit" id="approve" className="btn btn-primary">Approve for learners</button></>}
        </div>
        <p className="note">Approving says you checked every marked line against the paper. Learners get the text only after this.</p>
      </form>
    </>
  );
}

export default function CheckUploadPage() {
  return <Suspense fallback={<p role="status">Loading…</p>}><Check /></Suspense>;
}
