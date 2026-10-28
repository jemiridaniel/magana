"use client";

// The school's address (board "Register your school (principal, with address)"): street and
// number, town or area (both needed), nearest landmark (optional). Used by Register your school
// and School details. The server checks the same (portal_api._address_in) and answers with
// message codes; each error shows under its field and is announced.
import { messageFor } from "@/lib/messages";
import { ADDRESS_MAX, type SchoolAddress } from "@/lib/portal";

export type AddressErrors = Partial<Record<keyof SchoolAddress, string>>;
export const NO_ADDRESS: SchoolAddress = { address: "", town: "", landmark: "" };

const FIELDS: { key: keyof SchoolAddress; label: string; hint?: string; optional?: boolean }[] = [
  { key: "address", label: "School address", hint: "Street and number, as you’d give it to a visitor." },
  { key: "town", label: "Town or area" },
  { key: "landmark", label: "Nearest landmark", optional: true },
];

/** Spaces trimmed, and the first problem with each field, worded as the server's codes are. */
export function checkAddress(a: SchoolAddress): { value: SchoolAddress; errors: AddressErrors } {
  const value = { address: a.address.trim(), town: a.town.trim(), landmark: a.landmark.trim() };
  const errors: AddressErrors = {};
  for (const { key, optional } of FIELDS) {
    if (!optional && !value[key]) errors[key] = messageFor(`${key}_required`);
    else if (value[key].length > ADDRESS_MAX[key]) errors[key] = messageFor(`${key}_too_long`);
  }
  return { value, errors };
}

/** The field a server code is about ("town_required" → town), or null. */
export function addressField(code: string): keyof SchoolAddress | null {
  const m = /^(address|town|landmark)_(required|too_long)$/.exec(code);
  return m ? (m[1] as keyof SchoolAddress) : null;
}

/** Moves focus to the first field with an error. */
export function focusFirst(idPrefix: string, errors: AddressErrors) {
  const first = FIELDS.find((f) => errors[f.key]);
  if (first) document.getElementById(`${idPrefix}-${first.key}`)?.focus();
}

/** "14 Allen Avenue, Ikeja", or "Not given" for a school registered before the address was asked for. */
export const addressText = (a: SchoolAddress) => [a.address, a.town].filter(Boolean).join(", ") || "Not given";

export default function AddressFields({ idPrefix, value, onChange, errors }: {
  idPrefix: string; value: SchoolAddress; onChange: (v: SchoolAddress) => void; errors: AddressErrors;
}) {
  return (
    <>
      {FIELDS.map(({ key, label, hint, optional }) => {
        const id = `${idPrefix}-${key}`;
        const err = errors[key];
        const describedBy = [hint ? `${id}-hint` : "", err ? `${id}-err` : ""].filter(Boolean).join(" ") || undefined;
        return (
          <div className="field" key={key}>
            <label htmlFor={id}>{label}{optional ? <> <span className="hint">(optional)</span></> : null}</label>
            <input id={id} name={key} className="input" autoComplete="off" required={!optional} maxLength={ADDRESS_MAX[key]}
                   value={value[key]} onChange={(e) => onChange({ ...value, [key]: e.target.value })}
                   onBlur={(e) => { if (e.target.value !== e.target.value.trim()) onChange({ ...value, [key]: e.target.value.trim() }); }}
                   aria-invalid={err ? true : undefined} aria-describedby={describedBy} />
            {hint ? <span id={`${id}-hint`} className="hint">{hint}</span> : null}
            <p id={`${id}-err`} className="field-error" aria-live="polite">{err}</p>
          </div>
        );
      })}
    </>
  );
}
