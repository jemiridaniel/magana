"use client";

// State (a select) and local government area (an ARIA 1.2 combobox you can type into,
// filtered by the state). Stores codes, never free text (backend/app/places.py; the lists are
// content/places/ng_states_lgas.json, MIT). Screen readers hear "2 of 20 LGAs".
import { useEffect, useId, useMemo, useRef, useState } from "react";
import { portal, type Place } from "@/lib/portal";

export interface PlaceValue { state: string; lga: string }

export default function PlacePicker({ value, onChange, invalid }: {
  value: PlaceValue; onChange: (v: PlaceValue) => void; invalid?: boolean;
}) {
  const id = useId();
  const [states, setStates] = useState<Place[]>([]);
  const [text, setText] = useState("");
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => { portal.places().then((p) => setStates(p.states)).catch(() => setStates([])); }, []);

  const state = states.find((s) => s.code === value.state);
  const matches = useMemo(() => {
    if (!state) return [];
    const q = text.trim().toLowerCase();
    return state.lgas.filter((l) => !q || l.name.toLowerCase().includes(q));
  }, [state, text]);

  function pick(i: number) {
    const l = matches[i];
    if (!l) return;
    onChange({ state: value.state, lga: l.code });
    setText(l.name);
    setOpen(false);
  }

  function onKey(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      if (!open) { setOpen(true); setActive(0); return; }
      setActive((a) => Math.min(a + 1, matches.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((a) => Math.max(a - 1, 0));
    } else if (e.key === "Enter") {
      if (open && matches.length) { e.preventDefault(); pick(active); }
    } else if (e.key === "Escape") {
      if (open) { e.preventDefault(); setOpen(false); }
    }
  }

  const count = state ? `${matches.length} of ${state.name}’s ${state.lgas.length} LGAs` : "";

  // One grid: the two labels on the first row, the two fields on the second (so they sit at the
  // same height even when "Local government area" wraps), and the hint across both underneath.
  return (
    <div className="place-grid">
      <label className="field-label pg-l1" htmlFor={`${id}-state`}>State</label>
      <label className="field-label pg-l2" htmlFor={`${id}-lga`}>Local government area</label>
      <select
        id={`${id}-state`} className="select pg-c1" value={value.state} aria-invalid={invalid && !value.state ? true : undefined}
        aria-describedby={`${id}-hint`}
        onChange={(e) => { onChange({ state: e.target.value, lga: "" }); setText(""); }}
      >
        <option value="">Choose a state</option>
        {states.map((s) => <option key={s.code} value={s.code}>{s.name}</option>)}
      </select>
      <div className="combo pg-c2">
        <input
          ref={input} id={`${id}-lga`} className="input" role="combobox" autoComplete="off"
          aria-autocomplete="list" aria-expanded={open && matches.length > 0} aria-controls={`${id}-list`}
          aria-activedescendant={open && matches[active] ? `${id}-opt-${active}` : undefined}
          aria-describedby={`${id}-count ${id}-hint`} aria-invalid={invalid && !value.lga ? true : undefined}
          disabled={!state} value={text}
          onChange={(e) => { setText(e.target.value); setOpen(true); setActive(0); if (value.lga) onChange({ ...value, lga: "" }); }}
          onFocus={() => state && setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
          onKeyDown={onKey}
        />
        {open && matches.length > 0 && (
          <ul id={`${id}-list`} role="listbox" className="listbox" aria-label={`${state?.name} LGAs`}>
            {matches.map((l, i) => (
              <li
                key={l.code} id={`${id}-opt-${i}`} role="option" aria-selected={i === active}
                className={i === active ? "option active" : "option"}
                onMouseDown={(e) => { e.preventDefault(); pick(i); }}
              >{l.name}</li>
            ))}
          </ul>
        )}
      </div>
      <p id={`${id}-hint`} className="hint pg-hint">
        All 36 states and the FCT, and each state’s LGAs. {state ? "Type to filter, then choose with the arrow keys and Enter." : "Choose the state first."}
      </p>
      <span id={`${id}-count`} className="visually-hidden" aria-live="polite">{open ? count : ""}</span>
    </div>
  );
}
