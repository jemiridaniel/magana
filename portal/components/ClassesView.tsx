"use client";

// My classes (design canvas: "Teacher portal · My classes", updated): each class with its
// 6-digit code, the learners who joined with it, and "Remove from class" per learner. A teacher
// sees their own classes; a school admin sees every class in the school.
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import RemoveLearner from "@/components/RemoveLearner";
import { useStaff } from "@/components/SessionGate";
import { levelLabel, levels } from "@/lib/curriculum";
import { messageFor } from "@/lib/messages";
import { modeLabel, portal, PortalError, spaced, type ClassInfo, type Learner, type Mode, type StaffMember } from "@/lib/portal";

const formatLabel: Record<string, string> = { audio: "Audio", braille: "Braille", large_print: "Large print" };
const languageLabel: Record<string, string> = { en: "English", ha: "Hausa", yo: "Yorùbá", ig: "Igbo" };

function Consent({ l }: { l: Learner }) {
  if (l.consent === "not_needed") return <span>Not needed (18+)</span>;
  return l.consent === "received" ? <span className="pill pill-ready">Received</span> : <span className="pill pill-check">Pending</span>;
}

function account(l: Learner) {
  if (l.status === "removed") return "Removed";
  return l.consent === "pending" ? "Waiting for consent" : "Active";
}

function TeacherCode() {
  const [code, setCode] = useState<string | null>(null);
  const [msg, setMsg] = useState("");
  return (
    <section className="card form-grid" aria-labelledby="tc-h">
      <h2 id="tc-h">Your teacher code</h2>
      <p>Under-18 learners can’t change class on their own: you enter this code on their phone (Settings, My class).
        Keep it to yourself, like a key.</p>
      <div className="actions">
        {code ? <p className="code" aria-label={`Teacher code ${code.split("").join(" ")}`}>{spaced(code)}</p> : null}
        <button type="button" className="btn" onClick={async () => setCode(code ? null : (await portal.teacherCode()).teacher_code)}>
          {code ? "Hide code" : "Show my teacher code"}
        </button>
        <button type="button" className="btn" onClick={async () => {
          const r = await portal.rotateTeacherCode();
          setCode(r.teacher_code);
          setMsg(messageFor("teacher_code_rotated"));
        }}>Make a new code</button>
      </div>
      <p role="status" className="status-msg">{msg}</p>
    </section>
  );
}

function Classes() {
  const me = useStaff()!;
  const params = useSearchParams();
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [classId, setClassId] = useState<string | null>(params.get("class"));
  const [learners, setLearners] = useState<Learner[]>([]);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [adding, setAdding] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const learnersHead = useRef<HTMLHeadingElement>(null);

  const load = useCallback(() => portal.classes().then((cs) => {
    setClasses(cs);
    setClassId((id) => id ?? cs[0]?.id ?? null);
  }).catch((e) => setError((e as PortalError).code)), []);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { if (me.role === "admin") portal.staff().then(setStaff).catch(() => null); }, [me.role]);
  useEffect(() => {
    if (classId) portal.learners(classId).then(setLearners).catch(() => setLearners([]));
  }, [classId]);

  const cls = classes.find((c) => c.id === classId);

  function choose(id: string) {
    setClassId(id);
    setMessage("");
    requestAnimationFrame(() => learnersHead.current?.focus());
  }

  async function addClass(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const name = String(f.get("name") ?? "").trim();
    const level = String(f.get("level") ?? "");
    const mode = f.get("mode") as Mode | null;
    if (!name || !level || !mode) { setMessage("Give the class a name, a level and the learners’ age."); return; }
    try {
      const teacher = String(f.get("teacher") ?? "");
      const c = await portal.createClass({ name, level, mode, ...(teacher ? { teacher_id: teacher } : {}) });
      setAdding(false);
      await load();
      setClassId(c.id);
      setMessage(`${c.name} added. Its class code is ${spaced(c.code)}.`);
    } catch (err) {
      setMessage(messageFor((err as PortalError).code));
    }
  }

  async function rotate() {
    if (!cls) return;
    const r = await portal.rotateClassCode(cls.id);
    await load();
    setMessage(`New class code: ${spaced(r.class_code)}. The old code no longer works.`);
  }

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;

  return (
    <>
      <div className="page-head">
        <div><h1>My classes</h1><p>Set up classes, share each class’s code, and choose the right mode for the learners’ age.</p></div>
        <button type="button" className="btn btn-primary" aria-expanded={adding} onClick={() => setAdding((a) => !a)}>+ New class</button>
      </div>
      <p role="status" className="status-msg">{message}</p>

      {adding && (
        <form onSubmit={addClass} className="card form-grid" aria-labelledby="new-class-h">
          <h2 id="new-class-h">New class</h2>
          <div className="field"><label htmlFor="c-name">Class name</label><input id="c-name" name="name" className="input" /></div>
          <div className="field"><label htmlFor="c-level">Level</label>
            <select id="c-level" name="level" className="select" defaultValue="">
              <option value="" disabled>Choose a level</option>
              {levels.map((l) => <option key={l.id} value={l.id}>{levelLabel(l)}</option>)}
            </select></div>
          <fieldset className="field"><legend className="field-label">Learners’ age</legend>
            {(Object.keys(modeLabel) as Mode[]).map((m) => (
              <label key={m} className="check"><input type="radio" name="mode" value={m} /> <span>{modeLabel[m]}</span></label>
            ))}</fieldset>
          {me.role === "admin" && staff.length > 0 && (
            <div className="field"><label htmlFor="c-teacher">Teacher</label>
              <select id="c-teacher" name="teacher" className="select" defaultValue={me.id}>
                {staff.filter((s) => s.status === "active" || s.status === "invited").map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select></div>
          )}
          <div className="actions"><button type="submit" className="btn btn-primary">Add class</button>
            <button type="button" className="btn" onClick={() => setAdding(false)}>Cancel</button></div>
        </form>
      )}

      {classes.length === 0 ? (
        <p className="empty">No classes yet. Add one to get its 6-digit class code.</p>
      ) : (
        <ul className="class-cards" aria-label="Classes">
          {classes.map((c) => (
            <li key={c.id}>
              <button type="button" className="class-card" aria-pressed={c.id === classId} onClick={() => choose(c.id)}>
                <strong>{c.name}</strong>
                <span>{modeLabel[c.mode]}{me.role === "admin" && c.teacher ? ` · ${c.teacher}` : ""}</span>
                <span>{c.mode === "classroom" ? "Teacher-led sessions only · no learner accounts"
                  : `Learners: ${c.learners}${c.consents_needed ? ` · Consents: ${c.consents_received} of ${c.consents_needed}` : ""}`}</span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {cls && (
        <section className="card form-grid" aria-labelledby="learners-h">
          <h2 id="learners-h" ref={learnersHead} tabIndex={-1}>{cls.name} · Learners</h2>
          {cls.mode === "classroom" ? (
            <p>Primary pupils under 13 don’t join with a code: you start each session on the class phone.</p>
          ) : (
            <>
              <div className="actions code-row">
                <p>Class code: <strong className="code" aria-label={`Class code ${cls.code.split("").join(" ")}`}>{spaced(cls.code)}</strong></p>
                <button type="button" className="btn" onClick={() => window.print()}>Print class code</button>
                <button type="button" className="btn" onClick={rotate}>Make a new code</button>
              </div>
              {learners.length === 0 ? (
                <p className="empty">No learners yet. They join on their phone: Magana → I’m in school → type the class code.</p>
              ) : (
                <div className="table-wrap" role="region" aria-label={`${cls.name} learners`} tabIndex={0}>
                  <table>
                    <thead><tr><th scope="col">Learner</th><th scope="col">Preferred formats</th><th scope="col">Language</th>
                      <th scope="col">Guardian consent</th><th scope="col">Account</th><th scope="col">Phone</th></tr></thead>
                    <tbody>
                      {learners.map((l) => (
                        <tr key={l.id}>
                          <th scope="row"><Link href={`/learner/?id=${l.id}`}>{l.name}</Link></th>
                          <td>{l.formats.map((f) => formatLabel[f] ?? f).join(" · ") || "—"}</td>
                          <td>{languageLabel[l.language] ?? l.language}</td>
                          <td><Consent l={l} /></td>
                          <td>{account(l)}</td>
                          <td>{l.status === "active" ? (
                            <RemoveLearner learner={l} className={cls.name} onDone={(m) => {
                              setMessage(m);
                              portal.learners(cls.id).then(setLearners);
                              load();
                            }} />
                          ) : "Unlinked"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}
          <p className="note">Learners join on their phone with the class code. Removing a phone from the class unlinks it at once.
            Learners under 18 stay “waiting for consent” until you record a parent’s or guardian’s agreement. We only store
            what is needed: the name you give, class, preferred formats and language.</p>
        </section>
      )}

      <TeacherCode />
    </>
  );
}

export default function ClassesView() {
  return <Suspense><Classes /></Suspense>;
}
