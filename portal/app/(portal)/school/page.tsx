"use client";

// School details (school admins): the school and its address (editable, checked as at
// registration; each change goes in the log), the deletion requests waiting for an admin, and
// the audit log of who invited, removed or changed whom, and when.
import { useCallback, useEffect, useState, type FormEvent } from "react";
import AddressFields, { addressField, addressText, checkAddress, focusFirst, type AddressErrors } from "@/components/AddressFields";
import { useRefreshMe, useStaff } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type SchoolAddress } from "@/lib/portal";

const actionLabel: Record<string, string> = {
  school_registered: "registered the school", school_approved: "approved the school", staff_invited: "invited",
  invite_accepted: "accepted the invitation", invite_resent: "resent the invitation to", invite_cancelled: "cancelled the invitation for",
  staff_changed: "changed", staff_removed: "removed", class_created: "created a class", class_reassigned: "moved a class",
  class_code_rotated: "made a new class code", teacher_code_rotated: "made a new teacher code", consent_recorded: "recorded consent",
  learner_joined: "joined a class (learner)", learner_moved: "moved a learner", learner_removed: "removed a learner from a class",
  learner_changed_class: "changed class (learner)", learner_moved_by_teacher_code: "moved a learner with their teacher code",
  deletion_requested: "asked for a learner’s data to be deleted", learner_data_deleted: "deleted a learner’s data",
  school_details_changed: "changed the school’s address",
};

function SchoolAddressCard({ initial, onSaved }: { initial: SchoolAddress; onSaved: () => void }) {
  const [saved, setSaved] = useState(initial);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(initial);
  const [errors, setErrors] = useState<AddressErrors>({});
  const [formError, setFormError] = useState("");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function save(e: FormEvent) {
    e.preventDefault();
    setFormError("");
    const { value, errors: errs } = checkAddress(draft);
    setDraft(value);
    setErrors(errs);
    if (Object.keys(errs).length) { focusFirst("s", errs); return; }
    setBusy(true);
    try {
      const r = await portal.editSchool(value);
      setSaved(r.address);
      setEditing(false);
      setStatus(messageFor(r.code));
      onSaved();
      requestAnimationFrame(() => document.getElementById("s-edit")?.focus());
    } catch (err) {
      const code = (err as PortalError).code;
      const field = addressField(code);
      if (field) { setErrors({ [field]: messageFor(code) }); focusFirst("s", { [field]: code }); }
      else setFormError(messageFor(code));
    } finally { setBusy(false); }
  }

  return (
    <section className="card form-grid" aria-labelledby="addr-h">
      <h2 id="addr-h">School address</h2>
      <p role="status" className="status-msg">{status}</p>
      {editing ? (
        <form onSubmit={save} className="form-grid" noValidate>
          <AddressFields idPrefix="s" value={draft} onChange={setDraft} errors={errors} />
          <p role="alert" className="form-error">{formError}</p>
          <div className="actions">
            <button type="submit" className="btn btn-primary" disabled={busy}>{busy ? "Saving…" : "Save address"}</button>
            <button type="button" className="btn" onClick={() => { setEditing(false); setErrors({}); setFormError(""); }}>Cancel</button>
          </div>
        </form>
      ) : (
        <>
          <dl className="req-facts">
            <div><dt>School address</dt><dd>{saved.address || "Not given"}</dd></div>
            <div><dt>Town or area</dt><dd>{saved.town || "Not given"}</dd></div>
            <div><dt>Nearest landmark</dt><dd>{saved.landmark || "Not given"}</dd></div>
          </dl>
          <div><button id="s-edit" type="button" className="btn" onClick={() => {
            setDraft(saved); setErrors({}); setStatus(""); setEditing(true);
            requestAnimationFrame(() => document.getElementById("s-address")?.focus());
          }}>Edit address<span className="visually-hidden">: {addressText(saved)}</span></button></div>
        </>
      )}
    </section>
  );
}

export default function SchoolPage() {
  const me = useStaff();
  const refreshMe = useRefreshMe();
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

      <SchoolAddressCard initial={{ address: me.school.address ?? "", town: me.school.town ?? "", landmark: me.school.landmark ?? "" }}
                         onSaved={() => { refreshMe(); load(); }} />

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
