"use client";

import { Fragment, useEffect, useRef, useState, type FormEvent } from "react";
import { classes, consentLabel, consentRecords, languages, needsConsent, pupils, type ConsentRecord, type ConsentStatus, type Language } from "@/lib/data";

type Filter = "all" | ConsentStatus;
const filters: { id: Filter; label: string }[] = [
  { id: "all", label: "All" },
  { id: "pending", label: consentLabel.pending },
  { id: "received", label: consentLabel.received },
  { id: "withdrawn", label: consentLabel.withdrawn },
];
const channels = ["SMS link", "WhatsApp message to guardian", "Printed form"] as const;

const className = (id: string) => classes.find((c) => c.id === id)?.name ?? "";

function StatusPill({ status }: { status: ConsentStatus }) {
  const cls = status === "received" ? "pill-ready" : status === "pending" ? "pill-check" : "pill-withdrawn";
  return <span className={`pill ${cls}`}>{consentLabel[status]}</span>;
}

// Learners in under-18 classes who could need a request: pending first, as on the board.
const requestable = pupils
  .filter((p) => needsConsent(classes.find((c) => c.id === p.classId)!.mode))
  .map((p) => ({ ...p, status: consentRecords.find((r) => r.pupilId === p.id)?.status }))
  .sort((a, b) => Number(b.status === "pending") - Number(a.status === "pending"));

export default function ConsentView() {
  const [filter, setFilter] = useState<Filter>("all");
  const [open, setOpen] = useState<ConsentRecord | null>(null);
  const [learnerId, setLearnerId] = useState(requestable[0].id);
  const [language, setLanguage] = useState<Language>(requestable[0].language);
  const [message, setMessage] = useState("");
  const [formMessage, setFormMessage] = useState("");
  const recordHead = useRef<HTMLHeadingElement>(null);

  const shown = consentRecords.filter((r) => filter === "all" || r.status === filter);
  const count = (f: Filter) => consentRecords.filter((r) => f === "all" || r.status === f).length;

  // Move to the record once it is on screen (it opens as a row under the learner).
  useEffect(() => {
    if (open) recordHead.current?.focus();
  }, [open]);

  function chooseLearner(id: string) {
    setLearnerId(id);
    const p = requestable.find((x) => x.id === id);
    if (p) setLanguage(p.language); // a starting point: change it if the guardian prefers another language
    setFormMessage("");
  }

  function send(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const via = new FormData(e.currentTarget).get("via");
    const p = requestable.find((x) => x.id === learnerId)!;
    setFormMessage(
      `Not sent: consent requests go out once the portal is connected to the Magana server. Nothing has gone to ${p.name}'s guardian (${String(via)}, ${language}).`,
    );
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Consent records</h1>
          <p>Every learner under 18 needs a parent&rsquo;s or guardian&rsquo;s consent before their account opens.</p>
        </div>
      </div>

      <div className="consent-layout">
        <section aria-labelledby="records-head">
          <h2 id="records-head" className="visually-hidden">Consent list</h2>
          <div className="filters" role="group" aria-label="Filter by status" style={{ marginBottom: 16 }}>
            {filters.map((f) => (
              <button
                key={f.id} type="button" className="filter" aria-pressed={filter === f.id}
                onClick={() => { setFilter(f.id); setMessage(`${f.label}: ${count(f.id)} ${count(f.id) === 1 ? "record" : "records"}`); }}
              >
                {f.label} ({count(f.id)})
              </button>
            ))}
          </div>
          <div className="table-wrap" role="region" aria-label="Consent records table" tabIndex={0}>
            <table className="consent-table">
              <thead>
                <tr>
                  <th scope="col">Learner</th>
                  <th scope="col">Guardian</th>
                  <th scope="col">Covers</th>
                  <th scope="col">Status</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {shown.map((r) => (
                  <Fragment key={r.pupilId}>
                  <tr>
                    <th scope="row">
                      {r.learner}
                      <span className="sub">{className(r.classId)}</span>
                    </th>
                    <td>{r.guardian}</td>
                    <td>{r.covers.join(" · ")}</td>
                    <td><StatusPill status={r.status} /></td>
                    <td>
                      {r.status === "received" && (
                        <button type="button" className="btn-link" aria-label={`View record for ${r.learner}`} aria-expanded={open?.pupilId === r.pupilId} onClick={() => setOpen(open?.pupilId === r.pupilId ? null : r)}>
                          View record
                        </button>
                      )}
                      {r.status === "pending" && (
                        <button
                          type="button" className="btn-link" aria-label={`Send reminder to ${r.learner}'s guardian`}
                          onClick={() => setMessage(`Reminder not sent to ${r.guardian}. Reminders go out once the portal is connected to the Magana server.`)}
                        >
                          Send reminder
                        </button>
                      )}
                      {r.status === "withdrawn" && <span className="note">Account closed, data deleted</span>}
                    </td>
                  </tr>
                  {open?.pupilId === r.pupilId && (
                    <tr>
                      <td colSpan={5} className="record-cell">
                        <div className="record-panel">
                          <h3 id="record-head" ref={recordHead} tabIndex={-1}>Consent record: {open.learner}</h3>
                          <dl className="record-list">
                            <dt>Class</dt><dd>{className(open.classId)}</dd>
                            <dt>Guardian</dt><dd>{open.guardian}</dd>
                            <dt>Covers</dt><dd>{open.covers.join(", ")}</dd>
                            <dt>Status</dt><dd>{consentLabel[open.status]} on {open.date}</dd>
                            <dt>Sent by</dt><dd>{open.via}</dd>
                            <dt>Guardian&rsquo;s language</dt><dd>{open.guardianLanguage}</dd>
                          </dl>
                          <p className="note">Sample record. Real consent records will be kept here once the portal is connected to the Magana server.</p>
                          <div><button type="button" className="btn" onClick={() => setOpen(null)}>Close record</button></div>
                        </div>
                      </td>
                    </tr>
                  )}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </div>
          <p className="status-msg" role="status" aria-live="polite" style={{ marginTop: 8 }}>{message}</p>

        </section>

        <section className="card" aria-labelledby="send-head">
          <h2 id="send-head">Request consent</h2>
          <form className="form-grid" style={{ marginTop: 16, gap: 20 }} onSubmit={send}>
            <div className="field">
              <label htmlFor="req-learner">Learner</label>
              <select id="req-learner" className="select" value={learnerId} onChange={(e) => chooseLearner(e.target.value)}>
                <optgroup label="Waiting for consent">
                  {requestable.filter((p) => p.status === "pending").map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                </optgroup>
                <optgroup label="Consent received">
                  {requestable.filter((p) => p.status !== "pending").map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                </optgroup>
              </select>
            </div>
            <fieldset className="checks">
              <legend>Send by</legend>
              <div className="radio-list">
                {channels.map((c) => (
                  <label key={c} className="check">
                    <input type="radio" name="via" value={c} defaultChecked={c === "SMS link"} onChange={() => setFormMessage("")} />
                    {c}
                  </label>
                ))}
              </div>
            </fieldset>
            <fieldset className="checks">
              <legend>Guardian&rsquo;s language</legend>
              <div className="radio-grid">
                {languages.map((l) => (
                  <label key={l} className="check">
                    <input type="radio" name="glang" value={l} checked={language === l} onChange={() => { setLanguage(l); setFormMessage(""); }} />
                    {l}
                  </label>
                ))}
              </div>
            </fieldset>
            <button type="submit" className="btn btn-primary">Send request</button>
            <p className="status-msg" role="status" aria-live="polite">{formMessage}</p>
            <p className="note" style={{ fontSize: "1rem" }}>
              Guardians can listen to the consent form, and can withdraw at any time. When consent is withdrawn, the account
              closes and the learner&rsquo;s data is deleted.
            </p>
          </form>
        </section>
      </div>
    </>
  );
}
