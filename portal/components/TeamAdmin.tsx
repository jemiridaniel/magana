"use client";

// Team admin (design canvas: "Schools to approve"): the Magana team's own pages, for
// Magana team accounts only (team.py; the server refuses everyone else, and Support only looks). A school is approved only after
// the call: three checks must be ticked. Not approving needs a reason, and the team sees the
// email the applicant will get. Every decision, call note and proof view is in the activity log.
import { useCallback, useEffect, useId, useState } from "react";
import { useMe } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { API_URL } from "@/lib/server";
import { portal, PortalError, type Check, type Reason, type SchoolRequest } from "@/lib/portal";

export type Tab = "pending" | "approved" | "rejected";
const CHECKS: { id: Check; label: string }[] = [
  { id: "person_confirmed", label: "I spoke to the person and they confirmed their role" },
  { id: "school_exists", label: "The school exists (called the school or found its listing)" },
  { id: "details_correct", label: "Location and school name are correct" },
];

function SupportTools({ s }: { s: SchoolRequest }) {
  const [teachers, setTeachers] = useState<{ name: string; email: string; role: string; status: string }[] | null>(null);
  const [msg, setMsg] = useState("");
  return (
    <div className="req-checks">
      <div className="req-actions">
        <button type="button" className="btn" onClick={() => portal.schoolTeachers(s.id).then(setTeachers).catch((e) => setMsg(messageFor((e as PortalError).code)))}>
          Show teachers<span className="visually-hidden">: {s.name}</span></button>
        <button type="button" className="btn" onClick={async () => {
          try { const r = await portal.resendSchoolEmail(s.id); setMsg(r.emailed ? messageFor(r.code) : messageFor("mail_unavailable")); }
          catch (e) { setMsg(messageFor((e as PortalError).code)); } }}>Resend email<span className="visually-hidden">: {s.name}</span></button>
      </div>
      {teachers && (teachers.length ? (
        <ul className="audit">{teachers.map((t) => <li key={t.email}><b>{t.name}</b> · {t.email} · {t.role === "admin" ? "School admin" : "Teacher"} · {t.status}</li>)}</ul>
      ) : <p className="empty">No teachers yet.</p>)}
      <p role="status" className="status-msg">{msg}</p>
    </div>
  );
}

function Request({ s, onDone, viewOnly }: { s: SchoolRequest; onDone: (msg: string) => void; viewOnly: boolean }) {
  const id = useId();
  const [checks, setChecks] = useState<Set<Check>>(new Set(s.checks));
  const [notes, setNotes] = useState(s.call_notes);
  const [rejecting, setRejecting] = useState(false);
  const [reasons, setReasons] = useState<{ reason: Reason; label: string; preview: string }[]>([]);
  const [reason, setReason] = useState<Reason | "">("");
  const [msg, setMsg] = useState("");
  const all = checks.size === CHECKS.length;

  const toggle = (c: Check) => setChecks((now) => { const n = new Set(now); if (!n.delete(c)) n.add(c); return n; });

  async function run(f: () => Promise<unknown>, done?: string) {
    try { await f(); if (done) setMsg(done); } catch (e) { setMsg(messageFor((e as PortalError).code)); }
  }
  async function approve() {
    if (!all) { setMsg(messageFor("checks_required")); return; }
    await run(async () => {
      const r = await portal.decideSchool(s.id, { decision: "approve", checks: [...checks], call_notes: notes });
      onDone(`${s.name} is approved.${r.emailed ? " We emailed the principal." : " The email couldn’t be sent: tell them yourself."}`);
    });
  }
  async function reject() {
    if (!reason) { setMsg(messageFor("reason_required")); return; }
    await run(async () => {
      const r = await portal.decideSchool(s.id, { decision: "reject", reason, call_notes: notes, checks: [...checks] });
      onDone(`${s.name}: not approved.${r.emailed ? " We emailed the applicant the reason." : " The email couldn’t be sent."}`);
    });
  }
  async function openReject() {
    setRejecting(true);
    if (!reasons.length) await run(async () => setReasons(await portal.reasons(s.id)));
  }
  const preview = reasons.find((r) => r.reason === reason)?.preview;

  return (
    <article className="req" aria-labelledby={`${id}-h`}>
      <div className="req-head">
        <div><h2 id={`${id}-h`}>{s.name}</h2><span className="sub">{s.reference} · registered {s.registered}</span></div>
        <span className={`pill ${s.days_left <= 0 ? "pill-absent" : "pill-check"}`}>
          Call by {s.call_by} · {s.days_left <= 0 ? "due today" : `${s.days_left} day${s.days_left === 1 ? "" : "s"} left`}</span>
      </div>
      <dl className="req-facts">
        <div><dt>Location</dt><dd>{s.lga_name}, {s.state_name}</dd></div>
        <div><dt>Registered by</dt><dd>{s.contact_name}</dd></div>
        <div><dt>Role</dt><dd>{s.contact_role}</dd></div>
        <div><dt>Proof of school (optional)</dt><dd>{s.proof
          ? <a className="btn" href={`${API_URL}/portal/admin/schools/${s.id}/proof`} target="_blank" rel="noopener noreferrer">
              {s.proof === "application/pdf" ? "PDF" : "Photo"} · view<span className="visually-hidden"> for {s.name} (opens in a new tab)</span></a>
          : "None"}</dd></div>
        <div><dt>Ministry approval no.</dt><dd>{s.ministry_no || "None"}</dd></div>
        <div><dt>Email</dt><dd>{s.contact_email}</dd></div>
      </dl>
      {viewOnly ? <SupportTools s={s} /> : !rejecting ? (
        <>
          <div className="req-checks">
            <b>Checks before approving</b>
            <a className="btn" href={`tel:${s.phone_tel}`}>Call {s.contact_phone}<span className="visually-hidden"> ({s.contact_name})</span></a>
            {CHECKS.map((c) => (
              <label key={c.id} className="check"><input type="checkbox" checked={checks.has(c.id)} onChange={() => toggle(c.id)} />
                <span>{c.label}</span></label>
            ))}
            <div className="field"><label htmlFor={`${id}-notes`}>Call notes (team only)</label>
              <textarea id={`${id}-notes`} className="input" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)}
                        placeholder="When you called, who you spoke to, what they confirmed" /></div>
            <div><button type="button" className="btn" onClick={() => run(() => portal.saveCallNotes(s.id, notes, [...checks]), messageFor("notes_saved"))}>
              Save notes<span className="visually-hidden"> for {s.name}</span></button></div>
          </div>
          <div className="req-actions">
            <button type="button" className="btn btn-primary" aria-disabled={!all} aria-describedby={`${id}-why`} onClick={approve}>
              Approve school<span className="visually-hidden"> {s.name}</span></button>
            <button type="button" className="btn" onClick={openReject}>Don’t approve<span className="visually-hidden"> {s.name}</span></button>
            <span id={`${id}-why`} className="hint">Approve unlocks when all three checks are ticked. The principal gets the “Your school is ready” email.</span>
          </div>
        </>
      ) : (
        <>
          <fieldset className="checks">
            <legend>Reason (the applicant sees this)</legend>
            <div className="radio-list">
              {reasons.map((r) => (
                <label key={r.reason} className="check"><input type="radio" name={`${id}-reason`} value={r.reason}
                  checked={reason === r.reason} onChange={() => setReason(r.reason)} /> <span>{r.label}</span></label>
              ))}
            </div>
          </fieldset>
          <p className="preview" aria-live="polite">{preview ? <><b>Email preview:</b> “{preview}”</> : "Choose a reason to see the email."}</p>
          <div className="req-actions">
            <button type="button" className="btn" onClick={() => { setRejecting(false); setReason(""); setMsg(""); }}>Cancel</button>
            <button type="button" className="btn btn-primary" onClick={reject}>Send and don’t approve<span className="visually-hidden"> {s.name}</span></button>
          </div>
        </>
      )}
      <p role="status" className="status-msg">{msg}</p>
    </article>
  );
}

function Decided({ rows, rejected }: { rows: SchoolRequest[]; rejected: boolean }) {
  const [open, setOpen] = useState<string | null>(null);
  if (!rows.length) return <p className="empty">{rejected ? "No schools turned down." : "No schools approved yet."}</p>;
  return (
    <div className="table-wrap" role="region" aria-label={rejected ? "Schools not approved" : "Approved schools"} tabIndex={0}>
      <table>
        <thead><tr><th scope="col">School</th><th scope="col">Location</th><th scope="col">Principal</th>
          {rejected && <th scope="col">Reason</th>}<th scope="col">Decided</th><th scope="col">Call notes</th>
          <th scope="col">Actions</th></tr></thead>
        <tbody>{rows.map((s) => (
          <tr key={s.id}>
            <th scope="row">{s.name}<span className="sub">{s.reference}</span></th>
            <td>{s.lga_name}, {s.state_name}</td>
            <td>{s.contact_name}<span className="sub">{s.contact_role}</span></td>
            {rejected && <td>{s.reason_label}</td>}
            <td>{s.decided_at}<span className="sub">{s.decided_by}</span></td>
            <td>{s.call_notes || "—"}</td>
            <td>{open === s.id ? <SupportTools s={s} /> : (
              <button type="button" className="btn" onClick={() => setOpen(s.id)}>Teachers and emails<span className="visually-hidden">: {s.name}</span></button>)}</td>
          </tr>))}</tbody>
      </table>
    </div>
  );
}

/** Only these team roles see the page (the server checks too). */
export function TeamOnly({ roles, children }: { roles: string[]; children: React.ReactNode }) {
  const me = useMe();
  if (me.kind !== "team" || !roles.includes(me.role)) return <p role="alert">{messageFor("team_role_needed")}</p>;
  return <>{children}</>;
}

const TITLES: Record<Tab, [string, string]> = {
  pending: ["Schools to approve", "Call the person on the number they gave before approving. We promise a call within 2 working days."],
  approved: ["Approved schools", "Schools the team has confirmed, and who confirmed them."],
  rejected: ["Not approved", "Schools we couldn’t confirm, and why. Their details are deleted 30 days after the decision."],
};

export default function TeamAdmin({ tab }: { tab: Tab }) {
  const me = useMe();
  const [schools, setSchools] = useState<SchoolRequest[] | null>(null);
  const [message, setMessage] = useState("");
  const load = useCallback(() => {
    const fail = (e: unknown) => setMessage(messageFor((e as PortalError).code));
    portal.adminSchools(tab).then(setSchools).catch(fail);
  }, [tab]);
  useEffect(load, [load]);
  if (me.kind !== "team") return <p role="alert">{messageFor("not_team")}</p>;
  const [title, intro] = TITLES[tab];

  return (
    <>
      <div className="page-head"><div><h1>{title}</h1><p>{intro}</p></div>
        {tab === "pending" && <span className="pill pill-ready">New requests are emailed to the team</span>}</div>
      <p role="status" className="status-msg">{message}</p>
      {schools === null ? null
        : tab === "pending" ? (schools.length === 0 ? <p className="empty">No schools waiting. New requests are emailed to the team.</p> : (
            <ul className="list-plain">{schools.map((s) => (
              <li key={s.id}><Request s={s} viewOnly={me.role === "support"} onDone={(m) => { setMessage(m); load(); }} /></li>))}</ul>))
        : <Decided rows={schools} rejected={tab === "rejected"} />}
    </>
  );
}
