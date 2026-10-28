"use client";

// Register your school (design canvas): for principals and head teachers. Any email works. The
// school stays "pending" until the Magana team confirms it by phone.
import Link from "next/link";
import { useRef, useState, type FormEvent } from "react";
import AddressFields, { addressField, checkAddress, focusFirst, NO_ADDRESS, type AddressErrors } from "@/components/AddressFields";
import DropZone from "@/components/DropZone";
import PlacePicker, { type PlaceValue } from "@/components/PlacePicker";
import { messageFor } from "@/lib/messages";
import { portal, PortalError } from "@/lib/portal";

const ROLES = ["Principal", "Head teacher", "Vice principal", "Proprietor", "Other"];
const PROOF_TYPES = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
const PROOF_MAX = 5 * 1024 * 1024;

function dataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result));
    r.onerror = () => reject(r.error);
    r.readAsDataURL(file);
  });
}

export default function RegisterPage() {
  const [place, setPlace] = useState<PlaceValue>({ state: "", lga: "" });
  const [address, setAddress] = useState(NO_ADDRESS);
  const [addressErrors, setAddressErrors] = useState<AddressErrors>({});
  const [error, setError] = useState("");
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [tried, setTried] = useState(false);
  const [proof, setProof] = useState<File | null>(null);
  const [reference, setReference] = useState("");
  const doneHead = useRef<HTMLHeadingElement>(null);

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setTried(true);
    setError("");
    setAddressErrors({});
    const f = new FormData(e.currentTarget);
    const body = {
      name: String(f.get("name") ?? "").trim(), role: String(f.get("role") ?? ""),
      email: String(f.get("email") ?? "").trim(), phone: String(f.get("phone") ?? "").trim(),
      school: String(f.get("school") ?? "").trim(), state: place.state, lga: place.lga, agree: f.get("agree") === "on",
    };
    if (!body.name || !body.email || !body.phone || !body.school) { setError("Fill in every field."); return; }
    if (!body.state || !body.lga) { setError(messageFor("place_unknown")); return; }
    const where = checkAddress(address);
    setAddress(where.value);
    if (Object.keys(where.errors).length) { setAddressErrors(where.errors); focusFirst("r", where.errors); return; }
    if (!body.agree) { setError(messageFor("agree_required")); return; }
    if (proof && !PROOF_TYPES.includes(proof.type)) { setError(messageFor("proof_wrong_type")); return; }
    if (proof && proof.size > PROOF_MAX) { setError(messageFor("proof_too_big")); return; }
    setBusy(true);
    try {
      const r = await portal.register({ ...body, ...where.value, ministry_no: String(f.get("ministry_no") ?? "").trim(),
                                        proof: proof ? await dataUrl(proof) : null });
      setReference(r.reference);
      setDone(true);
      requestAnimationFrame(() => doneHead.current?.focus());
    } catch (err) {
      const code = (err as PortalError).code;
      const field = addressField(code);
      if (field) { setAddressErrors({ [field]: messageFor(code) }); focusFirst("r", { [field]: code }); return; }
      setError(code === "form_invalid" ? "Check the email address and the phone number (for example 0803 000 0000)." : messageFor(code));
    } finally {
      setBusy(false);
    }
  }

  if (done) {
    return (
      <>
        <h1 ref={doneHead} tabIndex={-1}>Thank you</h1>
        <p className="lead">{messageFor("school_registered")} We’ve emailed you a copy{reference ? <>, reference <b>{reference}</b></> : null}.
          You can sign in now to see the school’s status.</p>
        <Link href="/sign-in/" className="btn btn-primary btn-block">Go to sign in</Link>
      </>
    );
  }

  return (
    <>
      <Link href="/sign-in/" className="back-link">‹ Back to sign in</Link>
      <h1>Register your school</h1>
      <p className="lead">For principals and head teachers. You’ll be the school’s first admin and can then invite your teachers.</p>
      <form onSubmit={submit} className="form-grid" noValidate>
        <div className="field"><label htmlFor="r-name">Your full name</label>
          <input id="r-name" name="name" className="input" autoComplete="name" /></div>
        <div className="field"><label htmlFor="r-role">Your role</label>
          <select id="r-role" name="role" className="select" defaultValue="Principal">
            {ROLES.map((r) => <option key={r}>{r}</option>)}
          </select></div>
        <div className="field"><label htmlFor="r-email">Your email</label>
          <input id="r-email" name="email" type="email" className="input" autoComplete="email" aria-describedby="r-email-hint" />
          <span id="r-email-hint" className="hint">Any email works. We’ll send sign-in codes here.</span></div>
        <div className="field"><label htmlFor="r-phone">Your phone number</label>
          <input id="r-phone" name="phone" type="tel" className="input" autoComplete="tel" aria-describedby="r-phone-hint" />
          <span id="r-phone-hint" className="hint">We’ll call to confirm the school before it goes live.</span></div>
        <div className="field"><label htmlFor="r-school">School name</label>
          <input id="r-school" name="school" className="input" autoComplete="organization" /></div>
        <PlacePicker value={place} onChange={setPlace} invalid={tried} />
        <AddressFields idPrefix="r" value={address} onChange={setAddress} errors={addressErrors} />
        <fieldset className="proof">
          <legend>Proof of school <span className="hint">(optional, speeds up confirmation)</span></legend>
          <p className="hint">One of: a photo of the school’s letterhead or stamp, the Ministry of Education approval letter, or your staff ID card.</p>
          <DropZone label="Proof of school" accept=".jpg,.jpeg,.png,.webp,.pdf,image/jpeg,image/png,image/webp,application/pdf"
                    file={proof} onFile={setProof} compact
                    hint="A photo or PDF, up to 5 MB. Seen only by the Magana team, and deleted once we decide." />
          <div className="field"><label htmlFor="r-ministry">Ministry approval number <span className="hint">(if you have one)</span></label>
            <input id="r-ministry" name="ministry_no" className="input" placeholder="e.g. LSMOE/PS/2019/0412" /></div>
        </fieldset>
        <label className="check">
          <input type="checkbox" name="agree" />
          <span>I confirm I lead this school or have its permission, and I agree to Magana’s <a href="https://magana.ng/privacy/">privacy notice</a> for learners’ data.</span>
        </label>
        <p role="alert" className="form-error">{error}</p>
        <button type="submit" className="btn btn-primary btn-block" disabled={busy}>{busy ? "Registering…" : "Register school"}</button>
        <p className="note">Free during the pilot. The Magana team checks every school by phone within 2 working days.</p>
      </form>
    </>
  );
}
