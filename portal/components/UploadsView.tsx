"use client";

// Uploads: a photo or PDF of notes, a worksheet or a test. Magana reads it on the server and
// keeps only the text. Anything handwritten, or anything Magana was unsure of, stays at
// "Check" until the teacher corrects and approves it (uploads_api.py); learners only ever get
// approved text.
import Link from "next/link";
import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ClassInfo, type UploadInfo } from "@/lib/portal";

const ACCEPT = ".pdf,image/*";
const date = (iso: string) => new Date(iso).toLocaleDateString("en-NG", { day: "numeric", month: "short" });

export function UploadStatus({ u }: { u: UploadInfo }) {
  if (u.status === "ready" || u.status === "shared") return <span className="pill pill-ready">Ready</span>;
  if (u.status === "check")
    return <span className="pill pill-check">Check: {u.note === "handwriting" ? "handwriting" : "unsure parts"}</span>;
  return <span className="pill pill-processing">Processing</span>;
}

export default function UploadsView() {
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [uploads, setUploads] = useState<UploadInfo[]>([]);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const file = useRef<HTMLInputElement>(null);

  const load = useCallback(() => {
    portal.uploads().then(setUploads).catch((e) => setError((e as PortalError).code));
    portal.classes().then(setClasses).catch(() => null);
  }, []);
  useEffect(load, [load]);

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const f = new FormData(form);
    const chosen = file.current?.files?.[0];
    if (!chosen) { setMessage("Choose a photo or PDF first."); return; }
    setBusy(true);
    setMessage("Reading the file. A long PDF takes a minute.");
    try {
      const r = await portal.sendUpload(chosen, String(f.get("class") ?? ""), String(f.get("title") ?? ""));
      form.reset();
      setMessage(r.upload.status === "check"
        ? `${r.upload.title}: Magana read it. Please check it before learners use it.`
        : `${r.upload.title}: ${messageFor(r.code)}`);
      load();
    } catch (err) {
      setMessage(messageFor((err as PortalError).code));
    } finally {
      setBusy(false);
    }
  }

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  const className = (id: string | null) => classes.find((c) => c.id === id)?.name ?? "—";

  return (
    <>
      <div className="page-head"><div><h1>Uploads</h1>
        <p>Upload notes, worksheets or tests as a photo or PDF. Magana reads them and keeps only the text, never the file.</p></div></div>

      <form className="card form-grid" onSubmit={submit} aria-labelledby="new-upload">
        <h2 id="new-upload">New upload</h2>
        <div className="field"><label htmlFor="u-title">Title</label>
          <input id="u-title" name="title" className="input" aria-describedby="u-title-hint" />
          <span id="u-title-hint" className="hint">For example: SS2 Biology, photosynthesis notes</span></div>
        <div className="field"><label htmlFor="u-class">Class</label>
          <select id="u-class" name="class" className="select" defaultValue="">
            <option value="">No class yet</option>
            {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select></div>
        <div className="field"><label htmlFor="u-file">Photo or PDF</label>
          <input id="u-file" ref={file} name="file" type="file" accept={ACCEPT} className="input" aria-describedby="u-file-hint" />
          <span id="u-file-hint" className="hint">Up to 15 MB. Handwritten pages work too: you check them before learners get them.</span></div>
        <button type="submit" className="btn btn-primary" disabled={busy}>{busy ? "Reading…" : "Upload"}</button>
        <p className="status-msg" role="status">{message}</p>
      </form>

      <section className="card" aria-labelledby="recent">
        <h2 id="recent">Your uploads</h2>
        {uploads.length === 0 ? <p className="empty">No uploads yet.</p> : (
          <div className="table-wrap" role="region" aria-label="Uploads table" tabIndex={0}>
            <table>
              <thead><tr><th scope="col">Document</th><th scope="col">Class</th><th scope="col">Added</th>
                <th scope="col">Status</th><th scope="col">Actions</th></tr></thead>
              <tbody>
                {uploads.map((u) => (
                  <tr key={u.id}>
                    <th scope="row">{u.title}</th>
                    <td>{className(u.class_id)}</td>
                    <td>{date(u.created_at)}</td>
                    <td><UploadStatus u={u} /></td>
                    <td className="row-actions">
                      <Link className={u.status === "check" ? "btn btn-primary" : "btn"} href={`/uploads/check/?id=${u.id}`}>
                        {u.status === "check" ? "Check and approve" : "View text"}<span className="visually-hidden">: {u.title}</span>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <p className="note">Audio, Braille and large-print versions are made from the approved text. They come next;
          for now each upload gives learners its checked text.</p>
      </section>
    </>
  );
}
