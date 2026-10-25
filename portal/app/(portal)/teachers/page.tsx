"use client";

// Teachers (design canvas: "Teachers (school admin)"): invite teachers with any email, choose
// their role and classes, and remove anyone who has left. Removing someone signs them out
// everywhere; their classes move to another teacher first. At least two admins stay.
import { useCallback, useEffect, useState, type FormEvent } from "react";
import Dialog from "@/components/Dialog";
import { useStaff } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type ClassInfo, type Role, type StaffMember } from "@/lib/portal";

const statusLabel: Record<string, string> = { active: "Active", invited: "Invited", expired: "Invite expired", removed: "Removed" };
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

  async function invite(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const f = new FormData(form);
    const body = { name: String(f.get("name") ?? "").trim(), email: String(f.get("email") ?? "").trim(),
                   role: (f.get("role") ?? "teacher") as Role, class_ids: f.getAll("classes").map(String) };
    if (!body.name || !body.email) { setMessage("Enter their name and email."); return; }
    try {
      await portal.invite(body);
      form.reset();
      done(`Invitation sent to ${body.email}. It expires in 7 days.`);
    } catch (err) {
      const code = (err as PortalError).code;
      setMessage(code === "form_invalid" ? "That doesn’t look like an email address." : messageFor(code));
    }
  }

  if (!me) return null;
  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;

  return (
    <>
      <div className="page-head"><div><h1>Teachers</h1>
        <p>{me.school.name} · invite teachers, choose their classes, and remove anyone who has left.</p></div>
        <a className="btn btn-primary" href="#invite">+ Invite a teacher</a></div>
      <p role="status" className="status-msg">{message}</p>

      <div className="table-wrap" role="region" aria-label="Teachers" tabIndex={0}>
        <table>
          <thead><tr><th scope="col">Name and email</th><th scope="col">Role</th><th scope="col">Classes</th>
            <th scope="col">Status</th><th scope="col">Actions</th></tr></thead>
          <tbody>
            {staff.map((s) => (
              <tr key={s.id}>
                <th scope="row">{s.name}<br /><span className="sub">{s.email}</span></th>
                <td>{roleLabel(s)}</td>
                <td>{s.classes.map((c) => c.name).join(", ") || "—"}</td>
                <td>{statusLabel[s.status]}</td>
                <td className="row-actions">
                  {s.status === "active" && s.id !== me.id && <><EditClasses person={s} classes={classes} onDone={done} />
                    <RemoveStaff person={s} staff={staff} onDone={done} /></>}
                  {s.status === "active" && s.id === me.id && <span>You</span>}
                  {(s.status === "invited" || s.status === "expired") && <>
                    <button type="button" className="btn" onClick={async () => {
                      try { await portal.resend(s.id); done(`Invitation sent again to ${s.email}.`); } catch (e) { setMessage(messageFor((e as PortalError).code)); }
                    }}>Resend invite<span className="visually-hidden"> to {s.name}</span></button>
                    <button type="button" className="btn" onClick={async () => { await portal.cancelInvite(s.id); done("Invitation cancelled."); }}>
                      Cancel invite<span className="visually-hidden"> for {s.name}</span></button></>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <form id="invite" onSubmit={invite} className="card form-grid" aria-labelledby="invite-h">
        <h2 id="invite-h">Invite a teacher</h2>
        <div className="field"><label htmlFor="i-name">Full name</label><input id="i-name" name="name" className="input" /></div>
        <div className="field"><label htmlFor="i-email">Email</label>
          <input id="i-email" name="email" type="email" className="input" aria-describedby="i-email-hint" />
          <span id="i-email-hint" className="hint">Any email works: Gmail, Yahoo, Outlook or a school address.</span></div>
        <div className="field"><label htmlFor="i-role">Role</label>
          <select id="i-role" name="role" className="select" defaultValue="teacher" aria-describedby="i-role-hint">
            <option value="teacher">Teacher</option><option value="admin">School admin</option>
          </select><span id="i-role-hint" className="hint">School admins can invite and remove teachers.</span></div>
        {classes.length > 0 && (
          <fieldset className="field"><legend className="field-label">Classes</legend>
            {classes.map((c) => <label key={c.id} className="check"><input type="checkbox" name="classes" value={c.id} /> <span>{c.name}</span></label>)}
          </fieldset>
        )}
        <button type="submit" className="btn btn-primary">Send invite</button>
        <p className="note">They get an email with a link, and sign in with a 6-digit code, no password. The invite expires in 7 days.
          When you remove a teacher, they’re signed out everywhere at once; choose a new teacher for each of their classes and
          nothing is lost. Every school keeps at least two admins, so the school is never locked out.</p>
      </form>
    </>
  );
}
