"use client";

// A learner (design canvas: "Learner, remove from class"): details, consent, the linked phone
// and this term's figures; move to another class (same school) or remove from class.
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useState, type FormEvent } from "react";
import ConsentReminder from "@/components/ConsentReminder";
import Dialog from "@/components/Dialog";
import RemoveLearner from "@/components/RemoveLearner";
import { messageFor } from "@/lib/messages";
import { modeLabel, portal, PortalError, reasonLabel, type ClassInfo, type Learner } from "@/lib/portal";

const formatLabel: Record<string, string> = { audio: "Audio", braille: "Braille", large_print: "Large print" };
const languageLabel: Record<string, string> = { en: "English", ha: "Hausa", yo: "Yorùbá", ig: "Igbo" };
const date = (iso: string) => new Date(iso).toLocaleDateString("en-NG", { day: "numeric", month: "short" });

function MoveLearner({ learner, onDone }: { learner: Learner; onDone: (m: string) => void }) {
  const [open, setOpen] = useState(false);
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [error, setError] = useState("");

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const to = String(new FormData(e.currentTarget).get("class") ?? "");
    if (!to) { setError("Choose a class."); return; }
    try {
      await portal.moveLearner(learner.id, to);
      setOpen(false);
      onDone(`${learner.name} moved to ${classes.find((c) => c.id === to)?.name}.`);
    } catch (err) {
      setError(messageFor((err as PortalError).code));
    }
  }

  return (
    <>
      <button type="button" className="btn" onClick={async () => {
        setError("");
        setClasses((await portal.classes()).filter((c) => c.id !== learner.class_id && c.mode !== "classroom"));
        setOpen(true);
      }}>Move to another class</button>
      <Dialog open={open} title={`Move ${learner.name} to another class`} onClose={() => setOpen(false)}>
        <form onSubmit={submit} className="form-grid">
          {classes.length ? (
            <div className="field"><label htmlFor="move-to">New class (in this school)</label>
              <select id="move-to" name="class" className="select" defaultValue="">
                <option value="" disabled>Choose a class</option>
                {classes.map((c) => <option key={c.id} value={c.id}>{c.name} · {modeLabel[c.mode]}</option>)}
              </select></div>
          ) : <p>There’s no other class to move to. Add one in My classes first.</p>}
          <p role="alert" className="form-error">{error}</p>
          <div className="actions">
            <button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            {classes.length > 0 && <button type="submit" className="btn btn-primary">Move</button>}
          </div>
        </form>
      </Dialog>
    </>
  );
}

function RecordConsent({ learner, onDone }: { learner: Learner; onDone: (m: string) => void }) {
  const [open, setOpen] = useState(false);
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const how = String(new FormData(e.currentTarget).get("how") ?? "");
    if (!how) return;
    await portal.recordConsent(learner.id, how);
    setOpen(false);
    onDone(messageFor("consent_recorded"));
  }
  return (
    <>
      <button type="button" className="btn btn-primary" onClick={() => setOpen(true)}>Record consent</button>
      <Dialog open={open} title={`Guardian consent for ${learner.name}`} onClose={() => setOpen(false)}>
        <form onSubmit={submit} className="form-grid">
          <fieldset className="field"><legend className="field-label">How did the parent or guardian agree?</legend>
            <label className="check"><input type="radio" name="how" value="signed_form" required /> <span>Signed the consent form</span></label>
            <label className="check"><input type="radio" name="how" value="in_person" /> <span>In person, with me</span></label>
            <label className="check"><input type="radio" name="how" value="phone_call" /> <span>On a phone call with me</span></label>
          </fieldset>
          <p className="note">Magana records only how and when, not the guardian’s name or number.</p>
          <div className="actions"><button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary">Record consent</button></div>
        </form>
      </Dialog>
    </>
  );
}

function LearnerDetail() {
  const id = useSearchParams().get("id") ?? "";
  const [l, setL] = useState<Learner | null>(null);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const load = useCallback(() => {
    portal.learner(id).then(setL).catch((e) => setError((e as PortalError).code));
  }, [id]);
  useEffect(load, [load]);

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  if (!l) return <p aria-busy="true">Loading…</p>;
  const done = (m: string) => { setMessage(m); load(); };
  const initials = l.name.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();

  return (
    <>
      {l.class && <Link href={`/classes/?class=${l.class.id}`} className="back-link">‹ {l.class.name} · Learners</Link>}
      <div className="page-head">
        <div className="learner-head">
          <span className="initials" aria-hidden="true">{initials}</span>
          <div><h1>{l.name}</h1><p>{l.class ? `${l.class.name} · ${modeLabel[l.class.mode]}` : "No class"}</p></div>
        </div>
        {l.status === "active" && (
          <div className="actions">
            <MoveLearner learner={l} onDone={done} />
            <RemoveLearner learner={l} className={l.class?.name ?? "the class"} onDone={done} />
          </div>
        )}
      </div>
      <p role="status" className="status-msg">{message}</p>

      {l.status === "removed" && (
        <p className="note">Removed from the class on {date(l.removed_at!)}: {reasonLabel[l.removed_reason ?? ""] ?? l.removed_reason}.
          {l.deletion ? ` Deletion waiting for a school admin, due by ${date(l.deletion.due)}.` : " Records kept for this term."}</p>
      )}

      <section className="card" aria-labelledby="details-h">
        <h2 id="details-h">Details</h2>
        <dl className="details">
          <div><dt>Preferred formats</dt><dd>{l.formats.map((f) => formatLabel[f] ?? f).join(" · ") || "Not set"}</dd></div>
          <div><dt>Language</dt><dd>{languageLabel[l.language] ?? l.language}</dd></div>
          <div><dt>Guardian consent</dt><dd>{l.consent === "not_needed" ? "Not needed (18 or over)"
            : l.consent === "received" ? `Received ${l.consent_at ? date(l.consent_at) : ""}` : `Pending since ${date(l.joined_at)}`}</dd></div>
          <div><dt>Phone linked</dt><dd>{l.phone_linked ? "Yes, 1 phone" : "No"}</dd></div>
        </dl>
        {l.consent === "pending" && l.status === "active" && (
          <div className="actions"><RecordConsent learner={l} onDone={done} /><ConsentReminder learnerId={l.id} learnerName={l.name} /></div>
        )}
      </section>

      <section className="card" aria-labelledby="term-h">
        <h2 id="term-h">This term</h2>
        <dl className="figures">
          <div><dt>Attendance</dt><dd>{l.term?.sessions ? `${l.term.sessions_attended} of ${l.term.sessions} sessions · ${l.term.attendance}%` : "No register yet"}</dd></div>
          <div><dt>Pages read</dt><dd>{l.term?.pages ?? "—"}</dd></div>
          <div><dt>Done without help</dt><dd>{l.term?.unaided != null ? `${l.term.unaided}%` : "—"}</dd></div>
          <div><dt>Quiz average</dt><dd>{l.term?.quiz_average != null ? `${l.term.quiz_average}%` : "—"}</dd></div>
        </dl>
      </section>
    </>
  );
}

export default function LearnerPage() {
  return <Suspense><LearnerDetail /></Suspense>;
}
