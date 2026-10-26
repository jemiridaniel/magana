"use client";

// Activity log (board "Activity log + details"): everything the Magana team does, newest first.
// Search, an action filter, page size and pages; "View details" opens a side panel (focus kept
// inside, Escape closes it, focus goes back to the button). Entries can't be edited or deleted
// and are kept 2 years; they never hold learner data or codes.
import { useCallback, useEffect, useState } from "react";
import Dialog from "@/components/Dialog";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ActivityDetail, type ActivityPage } from "@/lib/portal";

const TONE: Record<string, string> = {
  school_approved: "tag-good", team_invite_accepted: "tag-good", school_rejected: "tag-bad", team_member_removed: "tag-bad",
  team_authenticator_reset: "tag-warn", team_role_changed: "tag-warn", team_member_invited: "tag-info", school_registered: "tag-info",
};
const SIZES = [10, 25, 50];

function Details({ id, onClose }: { id: number | null; onClose: () => void }) {
  const [d, setD] = useState<ActivityDetail | null>(null);
  useEffect(() => { if (id !== null) portal.activityEntry(id).then(setD).catch(() => setD(null)); }, [id]);
  const rows: [string, string | null | undefined][] = d ? [
    ["When", d.when], ["Who", `${d.who}${d.who_role ? ` (${d.who_role})` : ""}`], ["Email", d.who_email || null],
    ["School", d.school], ["Reference", d.reference], ["About", d.target ? `${d.target.name}${d.target.role ? `, ${d.target.role}` : ""}` : d.about],
    ["Signed in from", d.signed_in_from ? [d.signed_in_from.browser, d.signed_in_from.place].filter(Boolean).join(" · ") : null],
  ] : [];
  return (
    <Dialog open={id !== null} title="Activity details" onClose={onClose} className="dialog drawer" closeButton>
      {d && (
        <div className="drawer-body">
          <span className={`tag ${TONE[d.action] ?? ""}`}>{d.label}</span>
          <dl className="facts">{rows.filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}</dl>
          {d.changes.length > 0 && (
            <section aria-labelledby="chg-h"><h3 id="chg-h">What changed</h3>
              <dl className="changes">{d.changes.map((c) => (
                <div key={c.field}><dt>{c.field}</dt><dd>{c.before ? <><del>{c.before}</del><span aria-hidden="true"> → </span>
                  <span className="visually-hidden"> changed to </span></> : null}<b>{c.after || "(empty)"}</b></dd></div>))}</dl></section>
          )}
          {d.call_notes && <section aria-labelledby="notes-h"><h3 id="notes-h">Call notes</h3><p className="box">{d.call_notes}</p></section>}
          {d.emails.length > 0 && (
            <section aria-labelledby="mail-h"><h3 id="mail-h">Emails sent</h3>
              <ul className="plain">{d.emails.map((m, i) => <li key={i}>“{m.subject}” → {m.to} · {m.sent ? "sent" : "couldn’t be sent"}</li>)}</ul></section>
          )}
          <p className="note">Activity entries can’t be edited or deleted. Kept for {d.kept_for}.</p>
        </div>
      )}
    </Dialog>
  );
}

export default function ActivityLog() {
  const [q, setQ] = useState("");
  const [action, setAction] = useState("");
  const [size, setSize] = useState(25);
  const [page, setPage] = useState(1);
  const [data, setData] = useState<ActivityPage | null>(null);
  const [error, setError] = useState("");
  const [open, setOpen] = useState<number | null>(null);

  const load = useCallback(() => {
    portal.activity({ q, action, page, size }).then(setData).catch((e) => setError((e as PortalError).code));
  }, [q, action, page, size]);
  useEffect(() => { const t = setTimeout(load, 250); return () => clearTimeout(t); }, [load]);
  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;

  return (
    <>
      <div className="page-head"><div><h1>Activity log</h1><p>Everything the Magana team does, newest first.</p></div></div>
      <div className="log-filters">
        <div className="field"><label htmlFor="log-q">Search</label>
          <input id="log-q" className="input" type="search" placeholder="Name, email or school" value={q}
                 onChange={(e) => { setQ(e.target.value); setPage(1); }} /></div>
        <div className="field"><label htmlFor="log-action">Action</label>
          <select id="log-action" className="select" value={action} onChange={(e) => { setAction(e.target.value); setPage(1); }}>
            <option value="">All actions</option>
            {data?.actions.map((a) => <option key={a.action} value={a.action}>{a.label}</option>)}
          </select></div>
      </div>
      <p className="visually-hidden" aria-live="polite">{data ? `${data.total} entr${data.total === 1 ? "y" : "ies"}` : ""}</p>
      {data && (data.items.length === 0 ? <p className="empty">No activity matches.</p> : (
        <div className="table-wrap" role="region" aria-label="Activity table" tabIndex={0}>
          <table>
            <thead><tr><th scope="col">When</th><th scope="col">Who</th><th scope="col">Action</th><th scope="col">About</th>
              <th scope="col"><span className="visually-hidden">Details</span></th></tr></thead>
            <tbody>{data.items.map((e) => (
              <tr key={e.id} className={open === e.id ? "is-open" : undefined}>
                <td><b>{e.date}</b><span className="sub">{e.time}</span></td>
                <td><b>{e.who}</b>{e.who_email && <span className="sub">{e.who_email}</span>}</td>
                <td><span className={`tag ${TONE[e.action] ?? ""}`}>{e.label}</span></td>
                <td>{e.about}</td>
                <td><button type="button" className="btn" aria-expanded={open === e.id} onClick={() => setOpen(e.id)}>
                  View details<span className="visually-hidden">: {e.label}, {e.date} {e.time}</span></button></td>
              </tr>))}</tbody>
          </table>
        </div>
      ))}
      {data && data.total > 0 && (
        <nav className="pager" aria-label="Activity pages">
          <div className="field pager-size"><label htmlFor="log-size">Per page</label>
            <select id="log-size" className="select" value={size} onChange={(e) => { setSize(Number(e.target.value)); setPage(1); }}>
              {SIZES.map((n) => <option key={n} value={n}>{n}</option>)}
            </select></div>
          <div className="pager-pages">
            <button type="button" className="btn" disabled={data.page <= 1} onClick={() => setPage(data.page - 1)}>‹ Previous</button>
            <span aria-current="page">Page {data.page} of {data.pages}</span>
            <button type="button" className="btn" disabled={data.page >= data.pages} onClick={() => setPage(data.page + 1)}>Next ›</button>
          </div>
        </nav>
      )}
      <Details id={open} onClose={() => setOpen(null)} />
    </>
  );
}
