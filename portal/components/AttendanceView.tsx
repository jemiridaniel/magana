"use client";

import { useMemo, useState, type KeyboardEvent } from "react";
import { saveRegister } from "@/lib/api";
import { classes, FOLLOW_UP_BELOW, marks, register, sessions, type Learner, type Mark } from "@/lib/data";

type SessionType = "in-class" | "remote";

const pct = (n: number) => `${Math.round(n * 100)}%`;

function Ring({ value }: { value: number }) {
  const r = 44;
  const c = 2 * Math.PI * r;
  return (
    <svg width="112" height="112" viewBox="0 0 112 112" aria-hidden="true">
      <circle cx="56" cy="56" r={r} fill="none" stroke="var(--processing-bg)" strokeWidth="14" />
      <circle
        cx="56" cy="56" r={r} fill="none" stroke="var(--green)" strokeWidth="14"
        strokeDasharray={`${c * value} ${c}`} strokeLinecap="round" transform="rotate(-90 56 56)"
      />
      <text x="56" y="63" textAnchor="middle" fontSize="22" fontWeight="700" fill="var(--ink)">{pct(value)}</text>
    </svg>
  );
}

export default function AttendanceView() {
  const [classId, setClassId] = useState(classes[0].id);
  const [sessionId, setSessionId] = useState(sessions[0].id);
  const [type, setType] = useState<SessionType>("in-class");
  const [learners, setLearners] = useState<Learner[]>(register);
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);

  const cls = classes.find((c) => c.id === classId)!;
  const classSessions = sessions.filter((s) => s.classId === classId);

  const counts = useMemo(() => {
    const out: Record<Mark, number> = { present: 0, late: 0, absent: 0, excused: 0 };
    learners.forEach((l) => out[l.mark]++);
    return out;
  }, [learners]);
  const attended = counts.present + counts.late;
  const rate = learners.length ? attended / learners.length : 0;
  const termAverage = learners.length
    ? learners.reduce((s, l) => s + l.termAttended / l.termSessions, 0) / learners.length
    : 0;

  const setMark = (id: string, mark: Mark) => setLearners((ls) => ls.map((l) => (l.id === id ? { ...l, mark } : l)));

  function onRowKey(e: KeyboardEvent, l: Learner) {
    if (e.altKey || e.ctrlKey || e.metaKey) return;
    const m = marks.find((x) => x.key === e.key.toLowerCase());
    if (!m) return;
    e.preventDefault();
    setMark(l.id, m.id);
    setMessage(`${l.name}: ${m.label}`);
  }

  function markAllPresent() {
    setLearners((ls) => ls.map((l) => ({ ...l, mark: "present" })));
    setMessage("Everyone marked present. Check anyone who is late, absent or excused.");
  }

  async function save() {
    setSaving(true);
    try {
      await saveRegister(sessionId, learners);
      setMessage("Register saved.");
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Could not save. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  function exportCsv() {
    const rows = [
      ["Learner", "This session", "Used Magana", "Term attended", "Term sessions", "Attendance"],
      ...learners.map((l) => [
        l.name,
        marks.find((m) => m.id === l.mark)!.label,
        type === "remote" ? (l.usedMagana ? "Yes" : "No") : "",
        String(l.termAttended),
        String(l.termSessions),
        pct(l.termAttended / l.termSessions),
      ]),
    ];
    const csv = rows.map((r) => r.map((v) => `"${v.replace(/"/g, '""')}"`).join(",")).join("\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = `${cls.name} term report.csv`;
    a.click();
    URL.revokeObjectURL(url);
    setMessage("Term report downloaded.");
  }

  const comingSoon = (what: string) => setMessage(`${what} is not available yet in this preview.`);

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Attendance</h1>
          <p>Take the register for each session and see attendance build up over the term.</p>
        </div>
        <div className="actions no-print">
          <button type="button" className="btn" onClick={() => comingSoon("Taking the register by voice")}>Take register by voice</button>
          <button type="button" className="btn btn-primary" onClick={() => comingSoon("Adding a new session")}>+ New session</button>
        </div>
      </div>

      <section className="card session-bar" aria-label="Session">
        <div className="field">
          <label htmlFor="att-class">Class</label>
          <select id="att-class" className="select" value={classId} onChange={(e) => setClassId(e.target.value)}>
            {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <div className="field">
          <label htmlFor="att-session">Session</label>
          <select id="att-session" className="select" value={sessionId} onChange={(e) => setSessionId(e.target.value)}>
            {(classSessions.length ? classSessions : sessions).map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}
          </select>
        </div>
        <div className="field">
          <label htmlFor="att-type">Type</label>
          <select id="att-type" className="select" value={type} onChange={(e) => setType(e.target.value as SessionType)}>
            <option value="in-class">In class</option>
            <option value="remote">Remote (in app)</option>
          </select>
        </div>
        <p className="seats">Seats used {attended} of {cls.seats}</p>
      </section>

      <section className="card summary" aria-labelledby="summary-head">
        <h2 id="summary-head" className="visually-hidden">This session</h2>
        <div className="ring-block">
          <Ring value={rate} />
          <p className="ring-text">
            <strong>{attended} of {learners.length} learners attended</strong>
            {pct(rate)} this session. Term average: {pct(termAverage)}
          </p>
        </div>
        <ul className="tiles" style={{ listStyle: "none", margin: 0, padding: 0 }}>
          {marks.map((m) => (
            <li key={m.id} className="tile">
              <span className="tile-num">{counts[m.id]}</span>
              <span className="tile-label">{m.label}</span>
            </li>
          ))}
        </ul>
      </section>

      <section className="card" aria-labelledby="register-head">
        <div className="card-head">
          <h2 id="register-head">Register</h2>
          <button type="button" className="btn no-print" onClick={markAllPresent}>Mark all present</button>
        </div>
        <div className="table-wrap">
          <table aria-describedby="register-help">
            <thead>
              <tr>
                <th scope="col">Learner</th>
                <th scope="col">This session</th>
                <th scope="col">Used Magana</th>
                <th scope="col">Term total</th>
                <th scope="col">Attendance</th>
              </tr>
            </thead>
            <tbody>
              {learners.map((l) => {
                const termRate = l.termAttended / l.termSessions;
                return (
                  <tr key={l.id}>
                    <th scope="row">{l.name}</th>
                    <td>
                      <fieldset className="marks" onKeyDown={(e) => onRowKey(e, l)}>
                        <legend className="visually-hidden">This session for {l.name}</legend>
                        {marks.map((m) => (
                          <label key={m.id} className={`mark mark-${m.id}`}>
                            <input
                              type="radio"
                              name={`mark-${l.id}`}
                              value={m.id}
                              checked={l.mark === m.id}
                              onChange={() => setMark(l.id, m.id)}
                            />
                            {m.label}
                          </label>
                        ))}
                      </fieldset>
                    </td>
                    <td>
                      {type === "remote" ? (l.usedMagana ? "Yes" : "No") : (
                        <>
                          <span aria-hidden="true">—</span>
                          <span className="visually-hidden">Not tracked in class</span>
                        </>
                      )}
                    </td>
                    <td>{l.termAttended} of {l.termSessions}</td>
                    <td className={termRate < FOLLOW_UP_BELOW ? "follow-up" : undefined}>
                      {pct(termRate)}{termRate < FOLLOW_UP_BELOW ? " · follow up" : ""}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p id="register-help" className="note" style={{ marginTop: 16 }}>
          &lsquo;Used Magana&rsquo; fills in automatically for remote sessions. You always confirm the register.
          Keyboard: P present, L late, A absent, E excused.
        </p>
      </section>

      <p className="status-msg" role="status" aria-live="polite">{message}</p>

      <div className="footer-actions no-print">
        <button type="button" className="btn" onClick={exportCsv}>Export term report (CSV)</button>
        <button type="button" className="btn" onClick={() => window.print()}>Print register</button>
        <button type="button" className="btn btn-primary" onClick={save} disabled={saving}>
          {saving ? "Saving…" : "Save register"}
        </button>
      </div>
    </>
  );
}
