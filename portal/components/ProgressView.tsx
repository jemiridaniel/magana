"use client";

// Learner progress: each learner's term figures (attendance from your registers; pages read,
// work done without help and quiz scores once learners share them from the app). Summaries
// only: never the pages learners photograph or the questions they ask.
import Link from "next/link";
import { useEffect, useState } from "react";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ClassInfo, type Learner } from "@/lib/portal";

const pc = (v: number | null | undefined) => (v == null ? "—" : `${v}%`);

export default function ProgressView() {
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [classId, setClassId] = useState("");
  const [rows, setRows] = useState<Learner[]>([]);
  const [error, setError] = useState("");

  useEffect(() => {
    portal.classes().then((cs) => {
      const tracked = cs.filter((c) => c.mode !== "classroom");
      setClasses(tracked);
      setClassId(tracked[0]?.id ?? "");
    }).catch((e) => setError((e as PortalError).code));
  }, []);

  useEffect(() => {
    if (!classId) return;
    portal.learners(classId)
      .then((ls) => Promise.all(ls.filter((l) => l.status === "active").map((l) => portal.learner(l.id))))
      .then(setRows).catch(() => setRows([]));
  }, [classId]);

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  const shared = rows.some((r) => r.term?.pages);

  return (
    <>
      <div className="page-head"><div><h1>Learner progress</h1>
        <p>Summaries only: Magana never shows you the pages learners photograph or the questions they ask.</p></div></div>
      {classes.length === 0 ? <p className="empty">No classes with learner accounts yet. Primary classes under 13 keep no progress.</p> : (
        <section className="card form-grid" aria-labelledby="prog-h">
          <h2 id="prog-h">This term</h2>
          <div className="field"><label htmlFor="p-class">Class</label>
            <select id="p-class" className="select" value={classId} onChange={(e) => setClassId(e.target.value)}>
              {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select></div>
          {rows.length === 0 ? <p className="empty">No learners in this class yet.</p> : (
            <div className="table-wrap" role="region" aria-label="Learner progress" tabIndex={0}>
              <table>
                <thead><tr><th scope="col">Learner</th><th scope="col">Attendance</th><th scope="col">Pages read</th>
                  <th scope="col">Done without sighted help</th><th scope="col">Quiz average</th></tr></thead>
                <tbody>
                  {rows.map((l) => (
                    <tr key={l.id}>
                      <th scope="row"><Link className="cell-link" href={`/learner/?id=${l.id}`}>{l.name}</Link></th>
                      <td>{l.term?.sessions ? `${pc(l.term.attendance)} (${l.term.sessions_attended} of ${l.term.sessions})` : "—"}</td>
                      <td>{l.term?.pages ?? "—"}</td>
                      <td>{l.term?.unaided == null ? "No answers yet" : pc(l.term.unaided)}</td>
                      <td>{pc(l.term?.quiz_average)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {!shared && rows.length > 0 && <p className="note">Pages read, help and quiz figures appear when learners choose “Share my score with my teacher” in the app.</p>}
        </section>
      )}
    </>
  );
}
