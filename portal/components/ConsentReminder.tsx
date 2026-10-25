"use client";

// "Send reminder": Magana holds no guardian contact, so the portal writes the message and the
// teacher sends it (WhatsApp, SMS or a note home).
import { useState } from "react";
import Dialog from "@/components/Dialog";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

export default function ConsentReminder({ learnerId, learnerName }: { learnerId: string; learnerName: string }) {
  const [text, setText] = useState("");
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");

  async function make() {
    setError("");
    try {
      const r = await portal.remind(learnerId);
      setText(`Hello. ${learnerName} has joined ${r.class_name} at ${r.school} on Magana, a free app that reads printed `
        + `pages aloud. Learners under 18 need a parent or guardian to agree. Please tell the class teacher if you agree, `
        + `in person or by phone. Thank you.`);
      setOpen(true);
    } catch (e) {
      setError(messageFor((e as PortalError).code));
    }
  }

  return (
    <>
      <button type="button" className="btn" onClick={make}>Send reminder</button>
      {error && <p role="alert" className="form-error">{error}</p>}
      <Dialog open={open} title="A message for the guardian" onClose={() => setOpen(false)} describedBy="reminder-help">
        <p id="reminder-help">Copy it into WhatsApp or a text message. Magana doesn’t keep guardians’ phone numbers.</p>
        <label className="field" htmlFor="reminder-text"><span className="field-label">Message</span>
          <textarea id="reminder-text" className="input textarea" readOnly value={text} rows={6} /></label>
        <div className="actions">
          <button type="button" className="btn btn-primary" onClick={() => navigator.clipboard?.writeText(text)}>Copy message</button>
          <button type="button" className="btn" onClick={() => setOpen(false)}>Close</button>
        </div>
      </Dialog>
    </>
  );
}
