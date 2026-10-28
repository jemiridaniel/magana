"use client";

// My account (Magana team): reset your own authenticator, e.g. if its setup key was seen by
// someone else or you have a new phone. Prove it's you with a current code or a backup code;
// the old key stops working at once and you're signed out everywhere.
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import CodeInput from "@/components/CodeInput";
import { useMe } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

export default function MyAccount() {
  const me = useMe();
  const router = useRouter();
  const [useBackup, setUseBackup] = useState(false);
  const [value, setValue] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  if (me.kind !== "team") return <p role="alert">{messageFor("not_team")}</p>;

  async function reset(e: FormEvent) {
    e.preventDefault();
    setError("");
    const digits = value.replace(/\D/g, "");
    if (digits.length !== (useBackup ? 8 : 6)) {
      setError(useBackup ? "Type a backup code, like 4821-9037." : "Type the 6 digits from your authenticator app."); return;
    }
    setBusy(true);
    try {
      await portal.resetMyAuthenticator(useBackup ? { backup_code: value } : { code: digits });
      router.replace("/sign-in/?reset=1");
    } catch (err) {
      setError(messageFor((err as PortalError).code));
      setBusy(false);
    }
  }

  return (
    <>
      <div className="page-head"><div><h1>My account</h1>
        <p>{me.name} · {me.email} · {me.role_label}</p></div></div>
      <section className="card form-grid" aria-labelledby="reset-h">
        <h2 id="reset-h">Reset my authenticator</h2>
        <p>Do this if someone may have seen your setup key or QR code, or you have a new phone. Your old key stops working
          at once, your backup codes are cancelled, and you’re signed out everywhere. Then sign in again to set up a new one.</p>
        <form onSubmit={reset} className="form-grid" noValidate>
          {useBackup ? (
            <div className="field">
              <label htmlFor="reset-code">A backup code</label>
              <input id="reset-code" className="input code-input" inputMode="numeric" autoComplete="off" maxLength={9}
                     value={value} onChange={(e) => setValue(e.target.value.replace(/[^\d -]/g, ""))}
                     aria-describedby="reset-hint" aria-invalid={error ? true : undefined} />
            </div>
          ) : (
            <CodeInput id="reset-code" label="Your current authenticator code" value={value} onChange={setValue}
                       invalid={!!error} describedBy="reset-hint" />
          )}
          <span id="reset-hint" className="hint">We ask for it to make sure it’s really you.</span>
          <p role="alert" className="form-error">{error}</p>
          <div className="actions">
            <button type="submit" className="btn btn-primary" disabled={busy}>Reset my authenticator</button>
            <button type="button" className="link-button" onClick={() => { setUseBackup((b) => !b); setValue(""); setError(""); }}>
              {useBackup ? "Use my authenticator app instead" : "Lost your phone? Use a backup code"}</button>
          </div>
        </form>
        <p className="note">No phone and no backup codes? Ask the other Magana admin to reset it from Magana team, or, if you’re the
          only one, run <code>python -m app.team_setup --email {me.email} --reset-authenticator</code> on the server.</p>
      </section>
    </>
  );
}
