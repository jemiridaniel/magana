"use client";

// A 6-digit code: the sign-in code from the email, or an authenticator code. One real input
// (autocomplete "one-time-code"), so the phone can fill it from the email or the authenticator
// and a paste fills it whole, even "642 126" or "642-126". Six boxes are drawn over it (board
// "Enter sign-in code"); screen readers hear only the input, named e.g. "Verification code, 6 digits".
import { useState, type ClipboardEvent } from "react";

export const CODE_LENGTH = 6;
const digitsOf = (text: string) => text.replace(/\D/g, "").slice(0, CODE_LENGTH);

export default function CodeInput({ id, label, value, onChange, invalid, describedBy }: {
  id: string; label: string; value: string; onChange: (code: string) => void; invalid?: boolean; describedBy?: string;
}) {
  const [focused, setFocused] = useState(false);

  function paste(e: ClipboardEvent<HTMLInputElement>) {
    // Ourselves, not the browser's: maxLength would cut "642 126" to "642 12" before we see it.
    e.preventDefault();
    const pasted = e.clipboardData.getData("text").replace(/\D/g, "");
    if (pasted.length >= CODE_LENGTH) { onChange(pasted.slice(0, CODE_LENGTH)); return; }
    const el = e.currentTarget;
    const start = el.selectionStart ?? value.length, end = el.selectionEnd ?? value.length;
    onChange(digitsOf(value.slice(0, start) + pasted + value.slice(end)));
  }

  const active = Math.min(value.length, CODE_LENGTH - 1);
  return (
    <div className="field">
      {/* The visible label, and the full name on the input: it starts with the visible words. */}
      <label htmlFor={id} className="field-label">{label}</label>
      <div className={`code-boxes${focused ? " is-focused" : ""}`}>
        <input
          id={id} className="code-real" type="text" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]*"
          maxLength={CODE_LENGTH} spellCheck={false} value={value}
          onChange={(e) => onChange(digitsOf(e.target.value))} onPaste={paste}
          onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
          aria-label={`${label}, ${CODE_LENGTH} digits`} aria-invalid={invalid ? true : undefined} aria-describedby={describedBy}
        />
        {Array.from({ length: CODE_LENGTH }, (_, i) => (
          <span key={i} aria-hidden="true" className={`code-box${focused && i === active ? " is-active" : ""}`}>{value[i] ?? ""}</span>
        ))}
      </div>
    </div>
  );
}
