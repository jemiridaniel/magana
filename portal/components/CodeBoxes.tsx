"use client";

// The 6-digit sign-in code as six boxes (board "Enter sign-in code"). Paste or type the whole code
// into the first box, or let the phone fill it from the email ("one-time-code"), and it fills all
// six. Backspace in an empty box goes back one. Screen readers hear one labelled group.
import { useId, useRef, type ClipboardEvent, type KeyboardEvent } from "react";

const N = 6;

export default function CodeBoxes({ label, value, onChange, invalid, describedBy }: {
  label: string; value: string; onChange: (code: string) => void; invalid?: boolean; describedBy?: string;
}) {
  const id = useId();
  const boxes = useRef<(HTMLInputElement | null)[]>([]);
  const digits = value.padEnd(N, " ").slice(0, N).split("");

  function put(from: number, typed: string) {
    const d = typed.replace(/\D/g, "");
    const next = digits.slice();
    if (!d) { next[from] = " "; onChange(next.join("").trimEnd()); return; }
    for (let i = 0; i < d.length && from + i < N; i++) next[from + i] = d[i];
    onChange(next.join("").replace(/ /g, "").slice(0, N));
    boxes.current[Math.min(from + d.length, N - 1)]?.focus();
  }

  function key(i: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Backspace" && !digits[i].trim() && i > 0) { e.preventDefault(); put(i - 1, ""); boxes.current[i - 1]?.focus(); }
    if (e.key === "ArrowLeft" && i > 0) boxes.current[i - 1]?.focus();
    if (e.key === "ArrowRight" && i < N - 1) boxes.current[i + 1]?.focus();
  }

  function paste(i: number, e: ClipboardEvent<HTMLInputElement>) {
    e.preventDefault();
    put(i, e.clipboardData.getData("text"));
  }

  return (
    <div className="field">
      <span className="field-label" id={`${id}-l`}>{label}</span>
      <div className="code-boxes" role="group" aria-labelledby={`${id}-l`} aria-describedby={describedBy}>
        {digits.map((d, i) => (
          <input
            key={i} ref={(el) => { boxes.current[i] = el; }} className="input code-box"
            inputMode="numeric" autoComplete={i === 0 ? "one-time-code" : "off"} pattern="[0-9]*"
            aria-label={i === 0 ? `${label}, digit 1 of ${N}` : `Digit ${i + 1} of ${N}`}
            aria-invalid={invalid ? true : undefined}
            value={d.trim()} onChange={(e) => {
              const v = e.target.value;
              // A whole code (pasted, or filled in by the phone) fills from here; one typed digit replaces this box's.
              put(i, v.replace(/\D/g, "").length >= N || !d.trim() ? v : v.replace(d.trim(), "") || v);
            }}
            onKeyDown={(e) => key(i, e)} onPaste={(e) => paste(i, e)} onFocus={(e) => e.target.select()}
          />
        ))}
      </div>
    </div>
  );
}
