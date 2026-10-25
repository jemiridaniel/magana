"use client";

// Sign in (design canvas: "Teacher portal · Sign in" and "Enter sign-in code"): an email, then
// a 6-digit code by email, valid for 10 minutes. No password. Any email works.
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState, type FormEvent } from "react";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

function SignIn() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [step, setStep] = useState<"email" | "code">("email");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(params.get("expired") ? messageFor("session_expired") : "");
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
      router.replace(r.me.kind === "team" ? "/admin/" : "/");
    } catch (err) {
      setError(messageFor((err as PortalError).code));
      setBusy(false);
    }
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
          <div className="field">
            <label htmlFor="code">Sign-in code</label>
            <input
              id="code" className="input code-input" inputMode="numeric" autoComplete="one-time-code" maxLength={7}
              value={code} onChange={(e) => setCode(e.target.value.replace(/[^\d ]/g, ""))}
              aria-describedby="code-hint" aria-invalid={error ? true : undefined}
            />
            <span id="code-hint" className="hint">6 digits, from the email “Your Magana sign-in code”.</span>
          </div>
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
