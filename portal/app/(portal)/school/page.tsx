"use client";

// School details (school admins): the school, the deletion requests waiting for an admin, and
// the audit log of who invited, removed or changed whom, and when.
import { useCallback, useEffect, useState } from "react";
import { useStaff } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

const actionLabel: Record<string, string> = {
  school_registered: "registered the school", school_approved: "approved the school", staff_invited: "invited",
  invite_accepted: "accepted the invitation", invite_resent: "resent the invitation to", invite_cancelled: "cancelled the invitation for",
  staff_changed: "changed", staff_removed: "removed", class_created: "created a class", class_reassigned: "moved a class",
  class_code_rotated: "made a new class code", teacher_code_rotated: "made a new teacher code", consent_recorded: "recorded consent",
  learner_joined: "joined a class (learner)", learner_moved: "moved a learner", learner_removed: "removed a learner from a class",
  learner_changed_class: "changed class (learner)", learner_moved_by_teacher_code: "moved a learner with their teacher code",
  deletion_requested: "asked for a learner’s data to be deleted", learner_data_deleted: "deleted a learner’s data",
};

export default function SchoolPage() {
  const me = useStaff();
  const [log, setLog] = useState<Awaited<ReturnType<typeof portal.audit>>>([]);
  const [deletions, setDeletions] = useState<Awaited<ReturnType<typeof portal.deletions>>>([]);
  const [message, setMessage] = useState("");

  const load = useCallback(() => {
    portal.audit().then(setLog).catch((e) => setMessage(messageFor((e as PortalError).code)));
    portal.deletions().then(setDeletions).catch(() => null);
  }, []);
  useEffect(load, [load]);
  if (!me) return null;

  return (
    <>
      <div className="page-head"><div><h1>School details</h1><p>{me.school.name}</p></div></div>
      <p role="status" className="status-msg">{message}</p>

      <section className="card form-grid" aria-labelledby="del-h" id="deletions">
        <h2 id="del-h">Deletion requests</h2>
        {deletions.length === 0 ? <p className="empty">No deletion requests.</p> : (
          <ul className="attention-list">
            {deletions.map((d) => (
              <li key={d.id} className="attention">
                <div><strong>{d.learner_name ?? "A learner"}</strong>
                  <span>A guardian asked for all their data to be deleted. Due by {new Date(d.due).toLocaleDateString("en-NG", { day: "numeric", month: "long" })}.</span></div>
                <button type="button" className="btn btn-primary" onClick={async () => {
                  await portal.confirmDeletion(d.id);
                  setMessage(messageFor("learner_data_deleted"));
                  load();
                }}>Delete all their data<span className="visually-hidden"> ({d.learner_name})</span></button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="card form-grid" aria-labelledby="audit-h">
        <h2 id="audit-h">Who changed what</h2>
        {log.length === 0 ? <p className="empty">Nothing yet.</p> : (
          <ol className="audit">
            {log.map((a) => (
              <li key={a.id}><time dateTime={a.at}>{new Date(a.at).toLocaleString("en-NG", { dateStyle: "medium", timeStyle: "short" })}</time>
                {" "}<strong>{a.actor_name?.startsWith("learner:") ? "A learner" : a.actor_name}</strong> {actionLabel[a.action] ?? a.action}
                {a.target_name ? ` ${a.target_name}` : ""}</li>
            ))}
          </ol>
        )}
      </section>
    </>
  );
}
