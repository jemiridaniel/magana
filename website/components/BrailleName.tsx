"use client";

// "Your name in Braille": letters a–z become Braille cells, with the loader's dot animation, and a
// live region reads the result once the typing pauses. Anything else shows "not yet supported".
// Runs in the browser only; nothing typed is sent anywhere.
import { useEffect, useId, useState } from "react";
import { describe, dotPosition, toCells, type Cell } from "@/lib/braille";

const MAX = 24;

function CellSvg({ dots, label }: { dots: number[]; label: string }) {
  return (
    <svg width="44" height="64" viewBox="0 0 44 64" aria-hidden="true" focusable="false">
      {[1, 2, 3, 4, 5, 6].map((d) => {
        const { col, row } = dotPosition(d);
        const on = dots.includes(d);
        return (
          <circle
            key={`${label}-${d}-${on}`}
            className={on ? "bdot" : undefined}
            style={on ? { animationDelay: `${dots.indexOf(d) * 70}ms` } : undefined}
            cx={12 + col * 20}
            cy={12 + row * 20}
            r={on ? 8 : 6}
            fill={on ? "#0A6B4B" : "none"}
            stroke={on ? "none" : "#5A6068"}
            strokeWidth="2"
          />
        );
      })}
    </svg>
  );
}

export default function BrailleName() {
  const id = useId();
  const [text, setText] = useState("");
  const [said, setSaid] = useState("");
  const cells: Cell[] = toCells(text.slice(0, MAX));

  // Read the result out once typing pauses, not on every key.
  useEffect(() => {
    const t = setTimeout(() => {
      const trimmed = text.trim();
      setSaid(trimmed ? `${trimmed.slice(0, MAX)} in Braille: ${describe(toCells(trimmed.slice(0, MAX)))}.` : "");
    }, 700);
    return () => clearTimeout(t);
  }, [text]);

  return (
    <div className="braille-box">
      <div className="field">
        <label htmlFor={`${id}-name`}>Type your name</label>
        <input
          id={`${id}-name`}
          type="text"
          autoComplete="off"
          spellCheck={false}
          maxLength={MAX}
          value={text}
          onChange={(e) => setText(e.target.value)}
          aria-describedby={`${id}-hint`}
        />
        <span id={`${id}-hint`} className="hint">Letters a to z, up to {MAX}. Nothing you type leaves this page.</span>
      </div>
      <ul className="cells" aria-hidden="true">
        {cells.map((c, i) =>
          c.kind === "space" ? (
            <li key={i} className="cell cell-space" />
          ) : c.kind === "unsupported" ? (
            <li key={i} className="cell">
              <CellSvg dots={[]} label={`${i}`} />
              <span className="cell-letter">{c.char}</span>
              <span className="cell-unsupported">not yet supported</span>
            </li>
          ) : (
            <li key={`${i}-${c.char}`} className="cell">
              <CellSvg dots={c.dots} label={`${i}${c.char}`} />
              <span className="cell-letter">{c.char}</span>
            </li>
          ),
        )}
      </ul>
      <p role="status" className="visually-hidden">{said}</p>
    </div>
  );
}
