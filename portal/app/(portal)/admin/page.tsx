"use client";

// Schools to approve: the Magana team's own page (MAGANA_TEAM_EMAILS on the server). New
// schools stay "pending" until someone here has called the principal and approves them.
import { useCallback, useEffect, useState } from "react";
import { useMe } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

export default function AdminPage() {
  const me = useMe();
  const [schools, setSchools] = useState<Awaited<ReturnType<typeof portal.pendingSchools>>>([]);
  const [message, setMessage] = useState("");
  const load = useCallback(() => {
    portal.pendingSchools().then(setSchools).catch((e) => setMessage(messageFor((e as PortalError).code)));
  }, []);
  useEffect(load, [load]);
  if (me.kind !== "team") return <p role="alert">{messageFor("not_team")}</p>;

  async function decide(id: string, decision: "approve" | "reject", name: string) {
    await portal.decideSchool(id, decision);
    setMessage(`${name}: ${decision === "approve" ? "approved" : "not approved"}.`);
    load();
  }

  return (
    <>
      <div className="page-head"><div><h1>Schools to approve</h1>
        <p>Call the principal on the number they gave before approving.</p></div></div>
      <p role="status" className="status-msg">{message}</p>
      {schools.length === 0 ? <p className="empty">No schools waiting.</p> : (
        <ul className="attention-list">
          {schools.map((s) => (
            <li key={s.id} className="attention">
              <div><strong>{s.name}</strong>
                <span>{s.lga_name}, {s.state_name} · {s.contact_name} ({s.contact_role}) · {s.contact_email} · {s.contact_phone}</span></div>
              <div className="actions">
                <button type="button" className="btn btn-primary" onClick={() => decide(s.id, "approve", s.name)}>
                  Approve<span className="visually-hidden"> {s.name}</span></button>
                <button type="button" className="btn" onClick={() => decide(s.id, "reject", s.name)}>
                  Don’t approve<span className="visually-hidden"> {s.name}</span></button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
