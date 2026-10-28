"use client";

// Sign in (design canvas: "Teacher portal · Sign in" and "Enter sign-in code"): an email, then
// a 6-digit code by email, valid for 10 minutes. No password. Any email works. Magana team
// members then give an authenticator code; the first time, they set the app up and get 8 backup
// codes, shown once (board "Magana team admin · Team members").
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState, type FormEvent } from "react";
import CodeInput from "@/components/CodeInput";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

function SignIn() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState(params.get("email") ?? "");
  const [step, setStep] = useState<"email" | "code" | "setup" | "totp" | "backup">("email");
  const [setup, setSetup] = useState<{ key: string; uri: string; qr: string; account: string } | null>(null);
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [useBackup, setUseBackup] = useState(false);
  const [team, setTeam] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(params.get("expired") ? messageFor("session_expired")
    : params.get("reset") ? messageFor("authenticator_reset") : "");
  const [wait, setWait] = useState(0);
  const heading = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    if (wait <= 0) return;
    const t = setTimeout(() => setWait((w) => w - 1), 1000);
    return () => clearTimeout(t);
  }, [wait]);

  useEffect(() => { heading.current?.focus(); }, [step]);

  async function send(e?: FormEvent) {
    e?.preventDefault();
    setError("");
    if (!email.trim()) { setError("Enter your email address."); return; }
    setBusy(true);
    try {
      const r = await portal.requestCode(email.trim());
      setWait(r.retry_after);
      setStep("code");
    } catch (err) {
      const pe = err as PortalError;
      if (pe.code === "code_sent_recently") { setStep("code"); setWait(Number(pe.detail.retry_after) || 45); }
      else setError(pe.code === "form_invalid" ? "That doesn’t look like an email address." : messageFor(pe.code));
    } finally {
      setBusy(false);
    }
  }

  async function verify(e: FormEvent) {
    e.preventDefault();
    setError("");
    const digits = code.replace(/\D/g, "");
    if (digits.length !== 6) { setError("Type all 6 digits of the code."); return; }
    setBusy(true);
    try {
      const r = await portal.verify(email.trim(), digits);
      if (r.code === "signed_in") { router.replace(r.me.kind === "team" ? "/admin/" : "/"); return; }
      if (r.code === "totp_setup") setSetup({ key: r.key, uri: r.uri, qr: r.qr, account: r.account });
      setStep(r.code === "totp_setup" ? "setup" : "totp");
      setBusy(false);
    } catch (err) {
      setError(messageFor((err as PortalError).code));
      setBusy(false);
    }
  }

  async function verifyTotp(e: FormEvent) {
    e.preventDefault();
    setError("");
    const value = team.trim();
    if (!useBackup && value.replace(/\D/g, "").length !== 6) { setError("Type the 6 digits from your authenticator app."); return; }
    if (useBackup && value.replace(/\D/g, "").length !== 8) { setError("Type a backup code, like 4821-9037."); return; }
    setBusy(true);
    try {
      const r = await portal.totp(useBackup ? { backup_code: value } : { code: value.replace(/\D/g, "") });
      if (r.backup_codes) { setBackupCodes(r.backup_codes); setStep("backup"); setBusy(false); return; }
      router.replace("/admin/");
    } catch (err) {
      setError(messageFor((err as PortalError).code));
      setBusy(false);
    }
  }

  // The authenticator's 6 digits in the one-time-code field; a backup code ("4821-9037") in a plain one.
  const totpField = useBackup ? (
    <div className="field">
      <label htmlFor="totp">Backup code</label>
      <input id="totp" className="input code-input" inputMode="numeric" autoComplete="off" maxLength={9}
             value={team} onChange={(e) => setTeam(e.target.value.replace(/[^\d -]/g, ""))}
             aria-describedby="totp-hint" aria-invalid={error ? true : undefined} />
      <span id="totp-hint" className="hint">One of the 8 codes you saved. Each works once.</span>
    </div>
  ) : (
    <>
      <CodeInput id="totp" label="Authenticator code" value={team} onChange={setTeam} invalid={!!error} describedBy="totp-hint" />
      <span id="totp-hint" className="hint">From your authenticator app. They change every 30 seconds.</span>
    </>
  );

  if (step === "setup" && setup) {
    const groups = setup.key.split(" ");
    return (
      <>
        <h1 ref={heading} tabIndex={-1}>Set up your authenticator</h1>
        <p className="lead">Magana team accounts need a second step. Use Google Authenticator, Microsoft Authenticator, Authy or 2FAS
          on your phone.</p>
        <ol className="setup-steps">
          <li>In the app, tap <b>+</b> then <b>Scan a QR code</b>.</li>
          <li>Point your phone at the code below.</li>
          <li>Type the 6-digit code the app shows.</li>
        </ol>
        <div className="qr-card">
          {/* Drawn on Magana's own server from the otpauth:// link: no outside QR service. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={setup.qr} width={180} height={180} alt="QR code for your authenticator app" className="qr" />
          <p><b>Magana · {setup.account}</b><br />Shown once. Don’t screenshot or share it: anyone with this code can make your
            sign-in codes.</p>
        </div>
        <details className="setup-key-box">
          <summary>Can’t scan? Enter a setup key instead</summary>
          <p className="hint">Also for screen reader users: the key is read out in groups of four.</p>
          <p>In the app, choose <b>Enter a setup key</b>. Account: <b>Magana</b>. Key:</p>
          <p className="setup-key">
            <span className="visually-hidden">Setup key, in groups of four: {groups.join(", ")}.</span>
            <span aria-hidden="true">{setup.key}</span>
          </p>
          <p><a className="btn" href={setup.uri}>Open in my authenticator app</a></p>
        </details>
        <form onSubmit={verifyTotp} className="form-grid" noValidate>
          {totpField}
          <p role="alert" className="form-error">{error}</p>
          <button type="submit" className="btn btn-primary btn-block" disabled={busy}>{busy ? "Checking…" : "Finish setting up"}</button>
        </form>
      </>
    );
  }

  if (step === "backup") {
    return (
      <>
        <h1 ref={heading} tabIndex={-1}>Save your backup codes</h1>
        <p className="lead">If you lose your phone, each of these codes signs you in once. <b>We show them only now.</b>
          Write them down or keep them in a password manager.</p>
        <ul className="backup-codes" aria-label="Backup codes">
          {backupCodes.map((b) => <li key={b}><code>{b}</code></li>)}
        </ul>
        <button type="button" className="btn btn-primary btn-block" onClick={() => router.replace("/admin/")}>I’ve saved them</button>
      </>
    );
  }

  if (step === "totp") {
    return (
      <>
        <h1 ref={heading} tabIndex={-1}>Enter your authenticator code</h1>
        <p className="lead">Magana team accounts sign in with the email code and a code from your authenticator app.</p>
        <form onSubmit={verifyTotp} className="form-grid" noValidate>
          {totpField}
          <p role="alert" className="form-error">{error}</p>
          <button type="submit" className="btn btn-primary btn-block" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</button>
        </form>
        <p><button type="button" className="link-button" onClick={() => { setUseBackup((b) => !b); setTeam(""); setError(""); }}>
          {useBackup ? "Use my authenticator app instead" : "Lost your phone? Use a backup code"}</button></p>
      </>
    );
  }

  if (step === "code") {
    return (
      <>
        <button type="button" className="link-button" onClick={() => { setStep("email"); setCode(""); setError(""); }}>
          ‹ Use a different email
        </button>
        <h1 ref={heading} tabIndex={-1}>Check your email</h1>
        <p className="lead">We sent a 6-digit code to <strong>{email}</strong>. It works for 10 minutes.</p>
        <form onSubmit={verify} className="form-grid" noValidate>
          <CodeInput id="code" label="Verification code" value={code} onChange={setCode} invalid={!!error} describedBy="code-hint" />
          <span id="code-hint" className="hint">From the email “Your Magana verification code”. Paste the whole code, or let your phone fill it in.</span>
          <p role="alert" className="form-error">{error}</p>
          <button type="submit" className="btn btn-primary btn-block" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</button>
        </form>
        <p className="resend" aria-live="polite">
          Didn’t get it?{" "}
          {wait > 0 ? <span>You can ask for a new code in {wait} s.</span>
            : <button type="button" className="link-button" onClick={() => send()}>Send a new code</button>}
        </p>
        <p className="note">Check your spam folder. The email comes from Magana for Teachers.</p>
      </>
    );
  }

  return (
    <>
      <h1 ref={heading} tabIndex={-1}>Sign in</h1>
      <p className="lead">Enter your email: Gmail, Yahoo or a school address. We’ll send you a 6-digit code. No password needed.</p>
      <form onSubmit={send} className="form-grid" noValidate>
        <div className="field">
          <label htmlFor="email">Email address</label>
          <input id="email" className="input" type="email" autoComplete="email" value={email}
                 onChange={(e) => setEmail(e.target.value)} aria-invalid={error ? true : undefined} />
        </div>
        <p role="alert" className="form-error">{error}</p>
        <button type="submit" className="btn btn-primary btn-block" disabled={busy}>{busy ? "Sending…" : "Send me a code"}</button>
      </form>
      <p className="note">
        Only teachers invited by their school can sign in. Principal or head teacher?{" "}
        <Link href="/register/">Register your school</Link>
      </p>
      <p className="note">Signing in from a shared computer? You’ll be signed out after 30 minutes without activity.</p>
    </>
  );
}

export default function SignInPage() {
  return <Suspense><SignIn /></Suspense>;
}
