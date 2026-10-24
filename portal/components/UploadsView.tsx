"use client";

import { useRef, useState } from "react";
import { downloadUrl, uploadMaterial } from "@/lib/api";
import { classes, recentUploads, versionLabel, versions, type Upload, type Version } from "@/lib/data";

const ACCEPT = ".pdf,.doc,.docx,image/*";

function StatusPill({ status }: { status: Upload["status"] }) {
  if (status.kind === "ready") return <span className="pill pill-ready">Ready</span>;
  if (status.kind === "check") return <span className="pill pill-check">{status.detail}</span>;
  return <span className="pill pill-processing">Processing</span>;
}

export default function UploadsView() {
  const [classId, setClassId] = useState(classes[0].id);
  const [chosen, setChosen] = useState<Version[]>(versions.filter((v) => v.defaultOn).map((v) => v.id));
  const [uploads, setUploads] = useState<Upload[]>(recentUploads);
  const [over, setOver] = useState(false);
  const [message, setMessage] = useState("");
  const input = useRef<HTMLInputElement>(null);

  const toggle = (v: Version) => setChosen((c) => (c.includes(v) ? c.filter((x) => x !== v) : [...c, v]));

  async function addFiles(list: FileList | null) {
    const files = Array.from(list ?? []);
    if (!files.length) return;
    if (!chosen.length) {
      setMessage("Choose at least one version to make, then add the files again.");
      return;
    }
    const picked = versions.filter((v) => chosen.includes(v.id)).map((v) => v.id);
    const pending: Upload[] = files.map((f, i) => ({
      id: `pending-${uploads.length + i}-${f.name}`,
      name: f.name,
      classId,
      versions: picked,
      status: { kind: "processing" },
    }));
    setUploads((u) => [...pending, ...u]);
    setMessage(`${files.length} ${files.length === 1 ? "file" : "files"} added. Magana is making the versions now.`);
    try {
      await Promise.all(files.map((f) => uploadMaterial(f, classId, picked)));
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Upload failed. Please try again.");
    }
    if (input.current) input.current.value = "";
  }

  const className = (id: string) => classes.find((c) => c.id === id)?.name ?? "";

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Make materials accessible</h1>
          <p>Upload notes, tests or textbook pages. Your learners get audio, Braille and large print the same day.</p>
        </div>
      </div>

      <section className="card" aria-labelledby="new-upload">
        <h2 id="new-upload" className="visually-hidden">New upload</h2>
        <div style={{ display: "grid", gap: 24 }}>
          <div className="field" style={{ maxWidth: 420 }}>
            <label htmlFor="class">Class</label>
            <select id="class" className="select" value={classId} onChange={(e) => setClassId(e.target.value)}>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name} ({c.mode} mode)
                </option>
              ))}
            </select>
          </div>

          <div
            className={`dropzone${over ? " is-over" : ""}`}
            onDragOver={(e) => {
              e.preventDefault();
              setOver(true);
            }}
            onDragLeave={() => setOver(false)}
            onDrop={(e) => {
              e.preventDefault();
              setOver(false);
              addFiles(e.dataTransfer.files);
            }}
          >
            <p className="dropzone-title">Drop files here or choose files</p>
            <p className="note" id="file-types">PDF, Word, or photos of pages</p>
            <input
              ref={input}
              id="files"
              type="file"
              multiple
              accept={ACCEPT}
              className="visually-hidden"
              tabIndex={-1}
              aria-hidden="true"
              onChange={(e) => addFiles(e.target.files)}
            />
            <button type="button" className="btn btn-primary" aria-describedby="file-types" onClick={() => input.current?.click()}>
              Choose files
            </button>
          </div>

          <fieldset className="checks">
            <legend>Make these versions</legend>
            <div className="check-grid">
              {versions.map((v) => (
                <label key={v.id} className="check">
                  <input type="checkbox" checked={chosen.includes(v.id)} onChange={() => toggle(v.id)} />
                  {v.label}
                </label>
              ))}
            </div>
          </fieldset>

          <p className="status-msg" role="status" aria-live="polite">{message}</p>
        </div>
      </section>

      <section className="card" aria-labelledby="recent">
        <div className="card-head">
          <h2 id="recent">Recent uploads</h2>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">Document</th>
                <th scope="col">Versions</th>
                <th scope="col">Status</th>
                <th scope="col">Download</th>
              </tr>
            </thead>
            <tbody>
              {uploads.map((u) => (
                <tr key={u.id}>
                  <th scope="row">
                    {u.name}
                    <span className="sub">{className(u.classId)}</span>
                  </th>
                  <td>{u.versions.map(versionLabel).join(", ")}</td>
                  <td>
                    <StatusPill status={u.status} />
                  </td>
                  <td>
                    {u.status.kind === "processing" ? (
                      <span className="note">Not ready yet</span>
                    ) : (
                      <ul className="download-list">
                        {u.versions.map((v) => (
                          <li key={v}>
                            <a className="link-target" href={downloadUrl(u.id, v)} aria-label={`Download ${versionLabel(v)} of ${u.name}`}>
                              {versionLabel(v)}
                            </a>
                          </li>
                        ))}
                      </ul>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="note" style={{ marginTop: 16 }}>
          Items marked &lsquo;Check&rsquo; have parts Magana was unsure about. Review them before sharing with learners.
        </p>
      </section>
    </>
  );
}
