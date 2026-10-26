"use client";

// School waiting for confirmation (design canvas): three steps, the reference, and a
// normal-sized Sign out. A school the team couldn't confirm sees why, and what to do.
import AuthShell from "@/components/AuthShell";
import type { School } from "@/lib/portal";
import { SignOutButton } from "@/components/SessionGate";

const REPLY_TO = "support@magana.ng";
const REASONS: Record<string, string> = {
  unreachable: "We tried to call you 3 times but couldn’t get through.",
  role_unconfirmed: "When we called, we couldn’t confirm that you lead the school or have its permission.",
  not_found: "We couldn’t find the school at the place you gave.",
  duplicate: "This school is already on Magana. Ask its Magana admin to invite you.",
};

export default function SchoolWaiting({ name, school }: { name: string; school: School }) {
  const pending = school.status === "pending";
  return (
    <AuthShell wide>
      <span className={`pill ${pending ? "pill-check" : "pill-absent"} pill-lead`}>
        {pending ? "Waiting for confirmation" : "Not confirmed"}</span>
      <h1>{school.name}</h1>
      {pending ? (
        <>
          <p className="lead">Thank you, {name}. We’ve emailed you a copy of your registration.</p>
          <ol className="steps" aria-label="What happens next">
            <li className="step step-done"><span className="step-mark" aria-hidden="true">✓</span>
              <span><b>School registered</b><span>{school.registered}{school.reference ? ` · reference ${school.reference}` : ""}</span>
                <span className="visually-hidden">Done.</span></span></li>
            <li className="step step-now"><span className="step-mark" aria-hidden="true">2</span>
              <span><b>Magana team calls you</b><span>On {school.phone_masked}, by {school.call_by}</span>
                <span className="visually-hidden">Next.</span></span></li>
            <li className="step"><span className="step-mark" aria-hidden="true">3</span>
              <span><b>Invite your teachers</b><span>You’ll get an email as soon as the school is confirmed</span></span></li>
          </ol>
          <p className="box">Wrong phone number or details? Email <b>{REPLY_TO}</b>{school.reference ? <> with reference {school.reference}</> : null}.</p>
        </>
      ) : (
        <>
          <p className="lead">{REASONS[school.reason ?? ""] ?? "The Magana team couldn’t confirm this school."} We’ve emailed you what you can do.</p>
          <p className="box">Reply to that email, or write to <b>{REPLY_TO}</b>{school.reference ? <> with reference {school.reference}</> : null}.
            If we don’t hear from you, your details are deleted 30 days after our decision.</p>
        </>
      )}
      <div><SignOutButton /></div>
    </AuthShell>
  );
}
