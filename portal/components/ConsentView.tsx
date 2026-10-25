"use client";

// Consent records: every under-18 learner in your classes, whether a parent or guardian has
// agreed, and the two actions: record consent (how they agreed) or send a reminder. Until
// consent is recorded the learner's class stays unlinked and they can only read pages.
import Link from "next/link";
import { useEffect, useState } from "react";
import ConsentReminder from "@/components/ConsentReminder";
import { useStaff } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ClassInfo, type Learner } from "@/lib/portal";

type Row = Learner & { className: string };
type Filter = "all" | "pending" | "received";

export default function ConsentView() {
  const me = useStaff();
  const [rows, setRows] = useState<Row[]>([]);
  const [filter, setFilter] = useState<Filter>("all");
  const [error, setError] = useState("");

  useEffect(() => {
    portal.classes()
      .then((cs: ClassInfo[]) => Promise.all(cs.filter((c) => c.mode !== "classroom").map((c) =>
        portal.learners(c.id).then((ls) => ls.map((l) => ({ ...l, className: c.name }))))))
      .then((all) => setRows(all.flat().filter((l) => l.under_18 && l.status === "active")
        .sort((a, b) => Number(b.consent === "pending") - Number(a.consent === "pending"))))
      .catch((e) => setError((e as PortalError).code));
  }, []);

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  const shown = rows.filter((r) => filter === "all" || r.consent === filter);
  const count = (f: Filter) => rows.filter((r) => f === "all" || r.consent === f).length;

  return (
    <>
      <div className="page-head"><div><h1>Consent records</h1>
        <p>Learners under 18 need a parent’s or guardian’s agreement before their class is linked. Until then they can only read pages.</p></div></div>

      <div className="filters" role="group" aria-label="Show">
        {(["all", "pending", "received"] as Filter[]).map((f) => (
          <button key={f} type="button" className="btn" aria-pressed={filter === f} onClick={() => setFilter(f)}>
            {f === "all" ? "All" : f === "pending" ? "Pending" : "Received"} ({count(f)})
          </button>
        ))}
      </div>

      {shown.length === 0 ? (
        <p className="empty">{rows.length === 0 ? "No learners under 18 have joined your classes yet." : "No learners here."}</p>
      ) : (
        <div className="table-wrap" role="region" aria-label="Consent records" tabIndex={0}>
          <table>
            <thead><tr><th scope="col">Learner</th><th scope="col">Class</th><th scope="col">Consent</th><th scope="col">Actions</th></tr></thead>
            <tbody>
              {shown.map((r) => (
                <tr key={r.id}>
                  <th scope="row"><Link href={`/learner/?id=${r.id}`}>{r.name}</Link></th>
                  <td>{r.className}</td>
                  <td>{r.consent === "received"
                    ? <span className="pill pill-ready">Received {r.consent_at ? new Date(r.consent_at).toLocaleDateString("en-NG", { day: "numeric", month: "short" }) : ""}</span>
                    : <span className="pill pill-check">Pending</span>}</td>
                  <td className="row-actions">{r.consent === "pending" && <>
                    <Link className="btn btn-primary" href={`/learner/?id=${r.id}`}>Record consent<span className="visually-hidden"> for {r.name}</span></Link>
                    <ConsentReminder learnerId={r.id} learnerName={r.name} /></>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {me?.role === "admin" && <p className="note">Deletion requests from guardians are on <Link href="/school/#deletions">School details</Link>.</p>}
    </>
  );
}
