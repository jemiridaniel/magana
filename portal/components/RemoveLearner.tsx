"use client";

// "Remove from class" (design canvas: "Learner, remove from class"): a reason is required.
// The phone is unlinked at once; the term's records stay with the school. "Guardian asked us
// to delete their data" also starts a deletion request that a school admin confirms.
import { useId, useState, type FormEvent } from "react";
import Dialog from "@/components/Dialog";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, reasonLabel } from "@/lib/portal";

export default function RemoveLearner({ learner, className, onDone }: {
  learner: { id: string; name: string }; className: string; onDone: (msg: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const whatId = useId();

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const reason = new FormData(e.currentTarget).get("reason");
    if (!reason) { setError(messageFor("reason_required")); return; }
    setBusy(true);
    try {
      const r = await portal.removeLearner(learner.id, String(reason));
      setOpen(false);
      onDone(r.deletion_id
        ? `${learner.name} is removed from ${className}. A school admin will confirm the deletion; everything is deleted within 7 days.`
        : `${learner.name} is removed from ${className}. Their phone is unlinked.`);
    } catch (err) {
      setError(messageFor((err as PortalError).code));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button type="button" className="btn" aria-label={`Remove from class: ${learner.name}`}
              onClick={() => { setError(""); setOpen(true); }}>Remove from class</button>
      <Dialog open={open} title={`Remove ${learner.name} from ${className}?`} onClose={() => setOpen(false)} describedBy={whatId}>
        <form onSubmit={submit} className="form-grid">
          <p id={whatId}>
            Their phone is unlinked straight away. They can still use Magana to read on their own, but won’t see this
            class’s quizzes or notes.
          </p>
          <fieldset className="field">
            <legend className="field-label">Reason</legend>
            {Object.entries(reasonLabel).map(([value, label]) => (
              <label key={value} className="check"><input type="radio" name="reason" value={value} /> <span>{label}</span></label>
            ))}
          </fieldset>
          <p className="note">
            Their attendance and progress stay in the school’s records for this term. If a guardian asks for deletion, a
            school admin deletes everything within 7 days.
          </p>
          <p role="alert" className="form-error">{error}</p>
          <div className="actions">
            <button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={busy}>Remove from class</button>
          </div>
        </form>
      </Dialog>
    </>
  );
}
