"use client";

import { useRef, useState, type FormEvent } from "react";
import {
  classes as initialClasses, consentLabel, consentRecords, formats, hasAccounts, languages, modeInfo, needsConsent, pupils as initialPupils,
  type ConsentStatus, type Format, type Language, type Mode, type Pupil, type SchoolClass,
} from "@/lib/data";
import { levels, type LevelId } from "@/lib/curriculum";

const NOT_CONNECTED = "It is kept on this page only until the portal is connected to the Magana server.";

const consentOf = (pupilId: string): ConsentStatus | undefined => consentRecords.find((r) => r.pupilId === pupilId)?.status;

function ConsentPill({ status }: { status: ConsentStatus | undefined }) {
  if (status === "received") return <span className="pill pill-ready">{consentLabel.received}</span>;
  if (status === "withdrawn") return <span className="pill pill-withdrawn">{consentLabel.withdrawn}</span>;
  return <span className="pill pill-check">{consentLabel.pending}</span>;
}

export default function ClassesView() {
  const [classes, setClasses] = useState<SchoolClass[]>(initialClasses);
  const [pupils, setPupils] = useState<Pupil[]>(initialPupils);
  // Learners invited on this page: no consent record exists for them yet.
  const [invited, setInvited] = useState<string[]>([]);
  const [classId, setClassId] = useState(initialClasses[0].id);
  const [form, setForm] = useState<"none" | "class" | "learner">("none");
  const [message, setMessage] = useState("");
  const learnersHead = useRef<HTMLHeadingElement>(null);

  const cls = classes.find((c) => c.id === classId)!;
  const roster = pupils.filter((p) => p.classId === classId);
  const statusOf = (p: Pupil): ConsentStatus | undefined => (invited.includes(p.id) ? "pending" : consentOf(p.id));

  function summary(c: SchoolClass) {
    if (!hasAccounts(c.mode)) return "Teacher-led sessions only · no learner accounts";
    const list = pupils.filter((p) => p.classId === c.id);
    if (!needsConsent(c.mode)) return `Learners: ${list.length}`;
    const received = list.filter((p) => !invited.includes(p.id) && consentOf(p.id) === "received").length;
    return `Learners: ${list.length} · Consents: ${received} of ${list.length}`;
  }

  function choose(id: string) {
    setClassId(id);
    setForm((f) => (f === "learner" ? "none" : f));
    setMessage("");
    // Like the board's link to #learners: move to the list that just changed.
    requestAnimationFrame(() => learnersHead.current?.focus());
  }

  function addClass(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const data = new FormData(e.currentTarget);
    const name = String(data.get("name") ?? "").trim();
    const mode = data.get("mode") as Mode | null;
    const level = data.get("level") as LevelId | null;
    if (!name || !mode || !level) {
      setMessage("Give the class a name and choose the learners' age.");
      return;
    }
    const id = `local-class-${classes.length + 1}`;
    setClasses((cs) => [...cs, { id, name, mode, seats: 0, level }]);
    setClassId(id);
    setForm("none");
    setMessage(`${name} added in ${modeInfo[mode].label}. ${NOT_CONNECTED}`);
  }

  function addLearner(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const data = new FormData(e.currentTarget);
    const name = String(data.get("name") ?? "").trim();
    const chosen = formats.filter((f) => data.getAll("formats").includes(f));
    const language = data.get("language") as Language;
    if (!name || !chosen.length) {
      setMessage("Enter the learner's name and choose at least one format.");
      return;
    }
    const id = `local-pupil-${pupils.length + 1}`;
    setPupils((ps) => [...ps, { id, classId, name, formats: chosen, language }]);
    if (needsConsent(cls.mode)) setInvited((ids) => [...ids, id]);
    setForm("none");
    setMessage(
      needsConsent(cls.mode)
        ? `${name} added to ${cls.name}. Their account stays locked until a parent or guardian gives consent. No invitation or consent request has been sent. ${NOT_CONNECTED}`
        : `${name} added to ${cls.name}. No invitation has been sent. ${NOT_CONNECTED}`,
    );
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>My classes</h1>
          <p>Set up classes, invite learners and choose the right mode for their age.</p>
          <p className="status-msg" role="status" aria-live="polite">{message}</p>
        </div>
        <div className="actions">
          <button
            type="button" className="btn btn-primary" aria-expanded={form === "class"} aria-controls="new-class-form"
            onClick={() => { setForm((f) => (f === "class" ? "none" : "class")); setMessage(""); }}
          >
            + New class
          </button>
        </div>
      </div>

      {form === "class" && (
        <section className="card" aria-labelledby="new-class-head" id="new-class-form">
          <h2 id="new-class-head">New class</h2>
          <form className="form-grid" style={{ marginTop: 16 }} onSubmit={addClass} noValidate>
            <div className="field" style={{ maxWidth: 420 }}>
              <label htmlFor="class-name">Class name</label>
              <input id="class-name" name="name" className="input" required autoComplete="off" placeholder="For example: JSS1 Maths" autoFocus />
            </div>
            <div className="field" style={{ maxWidth: 420 }}>
              <label htmlFor="class-level">Class level</label>
              <select id="class-level" name="level" className="select" defaultValue="jss1" aria-describedby="class-level-hint">
                {levels.map((lv) => (
                  <option key={lv.id} value={lv.id}>{lv.name}</option>
                ))}
              </select>
              <span id="class-level-hint" className="hint">Picks the subjects and the sample questions. Primary classes get short questions with two or three options.</span>
            </div>
            <fieldset className="checks">
              <legend>How old are the learners?</legend>
              <div className="radio-list">
                {(["Guided", "Classroom", "Standard"] as Mode[]).map((m) => (
                  <label key={m} className="check">
                    <input type="radio" name="mode" value={m} defaultChecked={m === "Guided"} />
                    <span>
                      {modeInfo[m].ages} · {modeInfo[m].label}
                      <span className="sub">
                        {m === "Guided" && "Curriculum only. Accounts open after a guardian consents."}
                        {m === "Classroom" && "Teacher-led sessions on your device only. No learner accounts; sessions are not saved."}
                        {m === "Standard" && "Adult learners with their own accounts."}
                      </span>
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>
            <div className="actions">
              <button type="submit" className="btn btn-primary">Add class</button>
              <button type="button" className="btn" onClick={() => setForm("none")}>Cancel</button>
            </div>
          </form>
        </section>
      )}

      <section aria-labelledby="classes-head">
        <h2 id="classes-head" className="visually-hidden">Classes</h2>
        <ul className="class-cards">
          {classes.map((c) => (
            <li key={c.id}>
              <button type="button" className="class-card" aria-pressed={c.id === classId} onClick={() => choose(c.id)}>
                <span className="class-card-name">{c.name}</span>
                <span className={`pill ${c.mode === "Classroom" ? "pill-classroom" : "pill-ready"}`}>
                  {modeInfo[c.mode].label} · {modeInfo[c.mode].ages}
                </span>
                <span className="class-card-meta">{summary(c)}</span>
              </button>
            </li>
          ))}
        </ul>
      </section>

      <section className="card" aria-labelledby="learners-head">
        <div className="card-head">
          <h2 id="learners-head" ref={learnersHead} tabIndex={-1}>{cls.name} · Learners</h2>
          {hasAccounts(cls.mode) && (
            <div className="actions no-print">
              <button
                type="button" className="btn"
                onClick={() => setMessage(`Class codes are made by the Magana server, so printing them works once the portal is connected. Nothing was printed.`)}
              >
                Print class codes
              </button>
              <button
                type="button" className="btn btn-primary" aria-expanded={form === "learner"} aria-controls="invite-form"
                onClick={() => { setForm((f) => (f === "learner" ? "none" : "learner")); setMessage(""); }}
              >
                Invite learner
              </button>
            </div>
          )}
        </div>

        {form === "learner" && hasAccounts(cls.mode) && (
          <form id="invite-form" className="form-grid" style={{ marginBottom: 24 }} onSubmit={addLearner} noValidate aria-labelledby="invite-head">
            <h3 id="invite-head">Invite a learner to {cls.name}</h3>
            <div className="form-row">
              <div className="field">
                <label htmlFor="pupil-name">Learner&rsquo;s name</label>
                <input id="pupil-name" name="name" className="input" required autoComplete="off" autoFocus />
              </div>
              <div className="field">
                <label htmlFor="pupil-language">Language</label>
                <select id="pupil-language" name="language" className="select" defaultValue="English">
                  {languages.map((l) => <option key={l}>{l}</option>)}
                </select>
              </div>
            </div>
            <fieldset className="checks">
              <legend>Preferred formats</legend>
              <div className="check-grid">
                {formats.map((f: Format) => (
                  <label key={f} className="check">
                    <input type="checkbox" name="formats" value={f} defaultChecked={f === "Audio"} />
                    {f}
                  </label>
                ))}
              </div>
            </fieldset>
            <p className="note">We only store what is needed: name, class, preferred formats and language.</p>
            <div className="actions">
              <button type="submit" className="btn btn-primary">Add learner</button>
              <button type="button" className="btn" onClick={() => setForm("none")}>Cancel</button>
            </div>
          </form>
        )}

        {!hasAccounts(cls.mode) ? (
          <p className="note">
            {cls.name} is in Classroom mode for learners under 13. They use Magana only in teacher-led sessions on your device,
            during a lesson. They do not get their own accounts, and Classroom sessions are never saved.
          </p>
        ) : roster.length === 0 ? (
          <p className="note">No learners yet. Use &lsquo;Invite learner&rsquo; to add the first one.</p>
        ) : (
          <div className="table-wrap" role="region" aria-label={`${cls.name} learners table`} tabIndex={0}>
            <table>
              <thead>
                <tr>
                  <th scope="col">Learner</th>
                  <th scope="col">Preferred formats</th>
                  <th scope="col">Language</th>
                  {needsConsent(cls.mode) && <th scope="col">Guardian consent</th>}
                  <th scope="col">Account</th>
                </tr>
              </thead>
              <tbody>
                {roster.map((p) => {
                  const status = statusOf(p);
                  const open = !needsConsent(cls.mode) || status === "received";
                  return (
                    <tr key={p.id}>
                      <th scope="row">{p.name}</th>
                      <td>{p.formats.join(" · ")}</td>
                      <td>{p.language}</td>
                      {needsConsent(cls.mode) && <td><ConsentPill status={status} /></td>}
                      <td className={open ? undefined : "note"}>
                        {!open ? "Waiting for consent" : p.id.startsWith("local-") ? "Invited" : "Active"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {needsConsent(cls.mode) && (
          <p className="note" style={{ marginTop: 16 }}>
            Accounts for learners under 18 stay locked until a parent or guardian gives consent. We only store what is needed:
            name, class, preferred formats and language.
          </p>
        )}
      </section>
    </>
  );
}
