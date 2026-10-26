"use client";

// Teachers (board "Teachers + Invite modal (school admin)"): invite teachers with any email in a
// modal, choosing their role and classes, and remove anyone who has left. Removing someone signs
// them out everywhere; their classes move to another teacher first. At least two admins stay.
import { useCallback, useEffect, useState, type FormEvent } from "react";
import Dialog from "@/components/Dialog";
import { useStaff } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ClassInfo, type Role, type StaffMember } from "@/lib/portal";
import { Undeliverable } from "@/components/Undeliverable";

const statusLabel: Record<string, string> = { active: "Active", invited: "Invited", expired: "Invite expired", removed: "Removed" };
const ROLES: { id: Role; label: string; can: string }[] = [
  { id: "teacher", label: "Teacher", can: "Teaches their classes, uploads pages, sets quizzes. Can’t invite or remove people." },
  { id: "admin", label: "School admin", can: "Everything a teacher can do, plus invite and remove teachers and edit school details." },
];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const roleLabel = (s: StaffMember) => (s.role === "admin" ? "School admin" : "Teacher") + (s.title ? ` · ${s.title}` : "");

function RemoveStaff({ person, staff, onDone }: { person: StaffMember; staff: StaffMember[]; onDone: (m: string) => void }) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  const others = staff.filter((s) => s.id !== person.id && s.status === "active");

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const reassign = Object.fromEntries(person.classes.map((c) => [c.id, String(f.get(`to-${c.id}`) ?? "")]));
    if (Object.values(reassign).some((v) => !v)) { setError(messageFor("classes_need_new_teacher")); return; }
    try {
      await portal.removeStaff(person.id, reassign);
      setOpen(false);
      onDone(`${person.name} is removed and signed out everywhere. Their classes have new teachers.`);
    } catch (err) {
      setError(messageFor((err as PortalError).code));
    }
  }

  return (
    <>
      <button type="button" className="btn" onClick={() => { setError(""); setOpen(true); }}>
        Remove<span className="visually-hidden"> {person.name}</span>
      </button>
      <Dialog open={open} title={`Remove ${person.name}?`} onClose={() => setOpen(false)} describedBy={`what-${person.id}`}>
        <form onSubmit={submit} className="form-grid">
          <p id={`what-${person.id}`}>They’re signed out everywhere at once. Their classes and learners stay with the school.</p>
          {person.classes.map((c) => (
            <div className="field" key={c.id}><label htmlFor={`to-${c.id}`}>New teacher for {c.name}</label>
              <select id={`to-${c.id}`} name={`to-${c.id}`} className="select" defaultValue="">
                <option value="" disabled>Choose a teacher</option>
                {others.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
              </select></div>
          ))}
          <p role="alert" className="form-error">{error}</p>
          <div className="actions"><button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary">Remove</button></div>
        </form>
      </Dialog>
    </>
  );
}

function EditClasses({ person, classes, onDone }: { person: StaffMember; classes: ClassInfo[]; onDone: (m: string) => void }) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    try {
      await portal.editStaff(person.id, { class_ids: f.getAll("classes").map(String), role: f.get("role") as Role });
      setOpen(false);
      onDone(`${person.name}: saved.`);
    } catch (err) {
      setError(messageFor((err as PortalError).code));
    }
  }
  const mine = new Set(person.classes.map((c) => c.id));
  return (
    <>
      <button type="button" className="btn" onClick={() => { setError(""); setOpen(true); }}>
        Edit<span className="visually-hidden"> {person.name}</span>
      </button>
      <Dialog open={open} title={`Edit ${person.name}`} onClose={() => setOpen(false)}>
        <form onSubmit={submit} className="form-grid">
          <div className="field"><label htmlFor={`role-${person.id}`}>Role</label>
            <select id={`role-${person.id}`} name="role" className="select" defaultValue={person.role}>
              <option value="teacher">Teacher</option><option value="admin">School admin</option>
            </select>
            <span className="hint">School admins can invite and remove teachers and see every class.</span></div>
          <fieldset className="field"><legend className="field-label">Classes they teach</legend>
            {classes.map((c) => (
              <label key={c.id} className="check"><input type="checkbox" name="classes" value={c.id} defaultChecked={mine.has(c.id)} />
                <span>{c.name}{c.teacher && !mine.has(c.id) ? ` (now ${c.teacher})` : ""}</span></label>
            ))}</fieldset>
          <p role="alert" className="form-error">{error}</p>
          <div className="actions"><button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary">Save</button></div>
        </form>
      </Dialog>
    </>
  );
}

type Errors = { name?: string; email?: string; form?: string };

// "+ Invite a teacher" and its modal. Errors show under their field and are announced.
function InviteTeacher({ classes, onSent }: { classes: ClassInfo[]; onSent: (email: string) => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<Role>("teacher");
  const [picked, setPicked] = useState<string[]>([]);
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);

  function start() { setName(""); setEmail(""); setRole("teacher"); setPicked([]); setErrors({}); setOpen(true); }
  async function send(e: FormEvent) {
    e.preventDefault();
    const body = { name: name.trim(), email: email.trim(), role, class_ids: picked };
    const errs: Errors = {};
    if (body.name.length < 2) errs.name = "Enter their full name.";
    if (!body.email) errs.email = "Enter their email address.";
    else if (!EMAIL.test(body.email)) errs.email = "Enter an email address like name@gmail.com.";
    setErrors(errs);
    if (errs.name || errs.email) { document.getElementById(errs.name ? "i-name" : "i-email")?.focus(); return; }
    setBusy(true);
    try {
      await portal.invite(body);
      setOpen(false);
      onSent(body.email);
    } catch (err) {
      const code = (err as PortalError).code;
      if (["email_taken", "email_is_team", "form_invalid", "mail_undeliverable"].includes(code)) {
        setErrors({ email: code === "form_invalid" ? "That doesn’t look like an email address." : messageFor(code) });
        document.getElementById("i-email")?.focus();
      } else setErrors({ form: messageFor(code) });
    } finally { setBusy(false); }
  }
  const describe = (id: string, hint: string | null, err?: string) => ({
    "aria-invalid": err ? true : undefined,
    "aria-describedby": [hint, err ? `${id}-err` : ""].filter(Boolean).join(" ") || undefined,
  });

  return (
    <>
      <button type="button" className="btn btn-primary" aria-haspopup="dialog" onClick={start}>+ Invite a teacher</button>
      <Dialog open={open} title="Invite a teacher" onClose={() => setOpen(false)} closeButton>
        <form onSubmit={send} className="form-grid" noValidate>
          <div className="field"><label htmlFor="i-name">Full name</label>
            <input id="i-name" className="input" autoComplete="off" required data-autofocus value={name}
                   onChange={(e) => setName(e.target.value)} {...describe("i-name", null, errors.name)} />
            <p id="i-name-err" className="field-error" aria-live="polite">{errors.name}</p></div>
          <div className="field"><label htmlFor="i-email">Email</label>
            <input id="i-email" type="email" className="input" autoComplete="off" required value={email}
                   onChange={(e) => setEmail(e.target.value)} {...describe("i-email", "i-email-hint", errors.email)} />
            <span id="i-email-hint" className="hint">Any email works: Gmail, Yahoo, Outlook or a school address.</span>
            <p id="i-email-err" className="field-error" aria-live="polite">{errors.email}</p></div>
          <div className="field"><label htmlFor="i-role">Role</label>
            <select id="i-role" className="select" value={role} onChange={(e) => setRole(e.target.value as Role)} aria-describedby="i-role-hint">
              {ROLES.map((r) => <option key={r.id} value={r.id}>{r.label}</option>)}
            </select>
            <span id="i-role-hint" className="hint">{ROLES.find((r) => r.id === role)!.can}</span></div>
          {classes.length > 0 ? (
            <fieldset className="field"><legend className="field-label">Classes <span className="legend-note">(optional, can add later)</span></legend>
              <div className="chips">{classes.map((c) => (
                <label key={c.id} className="chip">
                  <input type="checkbox" checked={picked.includes(c.id)}
                         onChange={(e) => setPicked((p) => e.target.checked ? [...p, c.id] : p.filter((x) => x !== c.id))} />
                  {c.name}</label>))}</div>
            </fieldset>
          ) : <p className="hint">Add classes later from My classes.</p>}
          <p className="hint">They get an email with a link and sign in with a 6-digit code, no password. The invite expires in 7 days.</p>
          <p role="alert" className="form-error">{errors.form}</p>
          <div className="actions actions-end">
            <button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={busy}>Send invite</button>
          </div>
        </form>
      </Dialog>
    </>
  );
}

export default function TeachersPage() {
  const me = useStaff();
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const load = useCallback(() => {
    portal.staff().then(setStaff).catch((e) => setError((e as PortalError).code));
    portal.classes().then(setClasses).catch(() => null);
  }, []);
  useEffect(load, [load]);
  const done = (m: string) => { setMessage(m); load(); };

  if (!me) return null;
  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;

  return (
    <>
      <div className="page-head"><div><h1>Teachers</h1>
        <p>{me.school.name} · invite teachers, choose their classes, and remove anyone who has left.</p></div>
        <InviteTeacher classes={classes} onSent={(email) => done(`Invite sent to ${email}`)} /></div>
      <p role="status" className="status-msg">{message}</p>

      <div className="table-wrap table-box" role="region" aria-label="Teachers" tabIndex={0}>
        <table>
          <thead><tr><th scope="col">Name and email</th><th scope="col">Role</th><th scope="col">Classes</th>
            <th scope="col">Status</th><th scope="col">Actions</th></tr></thead>
          <tbody>
            {staff.map((s) => (
              <tr key={s.id}>
                <th scope="row">{s.name}<br /><span className="sub">{s.email}</span><Undeliverable show={s.undeliverable} /></th>
                <td>{roleLabel(s)}</td>
                <td>{s.classes.map((c) => c.name).join(", ") || "—"}</td>
                <td><span className={`pill ${s.status === "active" ? "pill-ready" : s.status === "removed" ? "pill-processing" : "pill-check"}`}>{statusLabel[s.status]}</span></td>
                <td className="row-actions">
                  {s.status === "active" && s.id !== me.id && <div className="row-btns"><EditClasses person={s} classes={classes} onDone={done} />
                    <RemoveStaff person={s} staff={staff} onDone={done} /></div>}
                  {s.status === "active" && s.id === me.id && <span>You</span>}
                  {(s.status === "invited" || s.status === "expired") && <div className="row-btns">
                    <button type="button" className="btn" onClick={async () => {
                      try { await portal.resend(s.id); done(`Invitation sent again to ${s.email}.`); } catch (e) { setMessage(messageFor((e as PortalError).code)); }
                    }}>Resend invite<span className="visually-hidden"> to {s.name}</span></button>
                    <button type="button" className="btn" onClick={async () => { await portal.cancelInvite(s.id); done("Invitation cancelled."); }}>
                      Cancel invite<span className="visually-hidden"> for {s.name}</span></button></div>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div role="note" className="warn-note">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><path d="M12 3l10 18H2z" /><path d="M12 10v5M12 18v.5" strokeLinecap="round" /></svg>
        <span><strong>When you remove a teacher</strong>, they’re signed out everywhere at once. Their classes and learners stay with the
          school: choose a new teacher for each class, and nothing is lost. Every school keeps at least two admins, so the school is
          never locked out.</span>
      </div>
    </>
  );
}
