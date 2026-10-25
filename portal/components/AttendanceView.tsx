"use client";

// Attendance: a register per class and day, saved to the Magana server. Keyboard: P, L or A on
// a learner's row marks them present, late or absent. Learners under 60% show on Home.
import { useEffect, useState, type KeyboardEvent } from "react";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ClassInfo, type Learner } from "@/lib/portal";

type Mark = "present" | "late" | "absent";
const MARKS: { id: Mark; label: string; key: string }[] = [
  { id: "present", label: "Present", key: "p" }, { id: "late", label: "Late", key: "l" }, { id: "absent", label: "Absent", key: "a" },
];
const today = () => new Date().toISOString().slice(0, 10);

export default function AttendanceView() {
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [classId, setClassId] = useState("");
  const [day, setDay] = useState(today());
  const [learners, setLearners] = useState<Learner[]>([]);
  const [marks, setMarks] = useState<Record<string, Mark>>({});
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    portal.classes().then((cs) => {
      const usable = cs.filter((c) => c.mode !== "classroom");
      setClasses(usable);
      setClassId((id) => id || usable[0]?.id || "");
    }).catch((e) => setError((e as PortalError).code));
  }, []);

  useEffect(() => {
    if (!classId) return;
    Promise.all([portal.learners(classId), portal.attendance(classId, day)]).then(([ls, reg]) => {
      setLearners(ls.filter((l) => l.status === "active"));
      setMarks(reg.marks as Record<string, Mark>);
    }).catch(() => null);
  }, [classId, day]);

  function setMark(l: Learner, m: Mark) {
    setMarks((ms) => ({ ...ms, [l.id]: m }));
  }

  function onRowKey(e: KeyboardEvent<HTMLTableRowElement>, l: Learner) {
    if (e.altKey || e.ctrlKey || e.metaKey) return;
    const m = MARKS.find((x) => x.key === e.key.toLowerCase());
    if (!m) return;
    e.preventDefault();
    setMark(l, m.id);
    setMessage(`${l.name}: ${m.label}`);
    e.currentTarget.querySelector<HTMLInputElement>(`input[value="${m.id}"]`)?.focus();
  }

  async function save() {
    const missing = learners.filter((l) => !marks[l.id]);
    if (missing.length) { setMessage(`Mark everyone first: ${missing.map((l) => l.name).join(", ")}.`); return; }
    setSaving(true);
    try {
      await portal.saveAttendance(classId, day, learners.map((l) => ({ learner_id: l.id, mark: marks[l.id] })));
      setMessage(messageFor("register_saved"));
    } catch (e) {
      setMessage(messageFor((e as PortalError).code));
    } finally {
      setSaving(false);
    }
  }

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  const present = learners.filter((l) => marks[l.id] === "present" || marks[l.id] === "late").length;

  return (
    <>
      <div className="page-head"><div><h1>Attendance</h1>
        <p>Take the register for a class session. Learners who miss many sessions show on Home.</p></div></div>
      {classes.length === 0 ? <p className="empty">No classes with learner accounts yet. Add one in My classes.</p> : (
        <section className="card form-grid" aria-labelledby="reg-h">
          <h2 id="reg-h">Register</h2>
          <div className="place-grid">
            <div className="field"><label htmlFor="a-class">Class</label>
              <select id="a-class" className="select" value={classId} onChange={(e) => { setClassId(e.target.value); setMessage(""); }}>
                {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select></div>
            <div className="field"><label htmlFor="a-day">Date</label>
              <input id="a-day" type="date" className="input" value={day} max={today()} onChange={(e) => setDay(e.target.value)} /></div>
          </div>
          {learners.length === 0 ? <p className="empty">No learners in this class yet.</p> : (
            <>
              <div className="actions">
                <button type="button" className="btn" onClick={() => {
                  setMarks(Object.fromEntries(learners.map((l) => [l.id, "present" as Mark])));
                  setMessage("Everyone marked present. Change anyone who is late or absent.");
                }}>Mark all present</button>
                <p>{present} of {learners.length} here</p>
              </div>
              <p className="hint">Tip: on a learner’s row, press P, L or A.</p>
              <div className="table-wrap" role="region" aria-label="Register" tabIndex={0}>
                <table>
                  <thead><tr><th scope="col">Learner</th><th scope="col">Mark</th></tr></thead>
                  <tbody>
                    {learners.map((l) => (
                      <tr key={l.id} onKeyDown={(e) => onRowKey(e, l)}>
                        <th scope="row">{l.name}</th>
                        <td>
                          <fieldset className="marks"><legend className="visually-hidden">{l.name}</legend>
                            {MARKS.map((m) => (
                              <label key={m.id} className="check"><input type="radio" name={`mark-${l.id}`} value={m.id}
                                checked={marks[l.id] === m.id} onChange={() => setMark(l, m.id)} /> <span>{m.label}</span></label>
                            ))}
                          </fieldset>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <button type="button" className="btn btn-primary" onClick={save} disabled={saving}>{saving ? "Saving…" : "Save register"}</button>
            </>
          )}
          <p role="status" className="status-msg">{message}</p>
        </section>
      )}
    </>
  );
}
