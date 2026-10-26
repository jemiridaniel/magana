"use client";

// Magana team (boards "Magana team admin · Team members" and "Team members + Add member modal"):
// Magana admins (role "owner") invite, change and remove team members. One role each; at least one
// and at most 2 Magana admins; a team member can't also be a teacher or school admin (the server
// checks all of it).
import { useCallback, useEffect, useState, type FormEvent } from "react";
import Dialog from "@/components/Dialog";
import { useMe } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type TeamMember, type TeamRole } from "@/lib/portal";

const ROLES: { id: TeamRole; label: string; can: string }[] = [
  { id: "reviewer", label: "School reviewer", can: "Approve or reject schools, view proof documents, see the activity log." },
  { id: "support", label: "Support (view only)", can: "See schools and teachers, resend emails. Can’t approve or change anything." },
  { id: "owner", label: "Magana admin", can: "Everything, including adding and removing team members. Keep to 2 people." },
];
const STATUS: Record<TeamMember["status"], string> = { active: "Active", invited: "Invited", expired: "Invite expired" };

function RoleChoice({ name, value, onChange }: { name: string; value: TeamRole; onChange: (r: TeamRole) => void }) {
  return (
    <fieldset className="checks">
      <legend>Role</legend>
      <div className="role-cards">
        {ROLES.map((r) => (
          <label key={r.id} className={`role-card${value === r.id ? " is-on" : ""}`}>
            <input type="radio" name={name} value={r.id} checked={value === r.id} onChange={() => onChange(r.id)} />
            <span><b>{r.label}</b><span>{r.can}</span></span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
type Errors = { name?: string; email?: string; role?: string; form?: string };

// "+ Add team member" and its modal: Full name, Email, Role (a native <select>, which TalkBack and
// VoiceOver read well) with what the chosen role can do under it. Errors show under their field.
function AddMember({ onSent }: { onSent: (email: string, emailed: boolean) => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<TeamRole>("reviewer");
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);
  const chosen = ROLES.find((r) => r.id === role)!;

  function start() { setName(""); setEmail(""); setRole("reviewer"); setErrors({}); setOpen(true); }
  async function send(e: FormEvent) {
    e.preventDefault();
    const body = { name: name.trim(), email: email.trim(), role };
    const errs: Errors = {};
    if (body.name.length < 2) errs.name = "Enter their full name.";
    if (!body.email) errs.email = "Enter their email address.";
    else if (!EMAIL.test(body.email)) errs.email = "Enter an email address like name@example.com.";
    setErrors(errs);
    if (errs.name || errs.email) {
      document.getElementById(errs.name ? "t-name" : "t-email")?.focus();
      return;
    }
    setBusy(true);
    try {
      const r = await portal.addTeamMember(body);
      setOpen(false);
      onSent(body.email, r.emailed);
    } catch (err) {
      const code = (err as PortalError).code;
      const msg = code === "form_invalid" ? "Check the name and the email address." : messageFor(code);
      const field = ["team_already_member", "team_already_invited", "email_is_teacher"].includes(code) ? "email"
        : code === "team_admins_max" ? "role" : "form";
      setErrors({ [field]: msg });
      if (field !== "form") document.getElementById(`t-${field}`)?.focus();
    } finally { setBusy(false); }
  }
  const described = (id: string, err?: string) => ({
    "aria-invalid": err ? true : undefined,
    "aria-describedby": [id === "t-role" ? "t-role-can" : "", err ? `${id}-err` : ""].filter(Boolean).join(" ") || undefined,
  });

  return (
    <>
      <button type="button" className="btn btn-primary" aria-haspopup="dialog" onClick={start}>+ Add team member</button>
      <Dialog open={open} title="Add a team member" onClose={() => setOpen(false)} closeButton className="dialog add-member">
        <form onSubmit={send} className="form-grid" noValidate>
          <div className="field"><label htmlFor="t-name">Full name</label>
            <input id="t-name" name="name" className="input" autoComplete="off" required data-autofocus
                   value={name} onChange={(e) => setName(e.target.value)} {...described("t-name", errors.name)} />
            <p id="t-name-err" className="field-error" aria-live="polite">{errors.name}</p></div>
          <div className="field"><label htmlFor="t-email">Email</label>
            <input id="t-email" name="email" type="email" className="input" autoComplete="off" required
                   value={email} onChange={(e) => setEmail(e.target.value)} {...described("t-email", errors.email)} />
            <p id="t-email-err" className="field-error" aria-live="polite">{errors.email}</p></div>
          <div className="field"><label htmlFor="t-role">Role</label>
            <select id="t-role" name="role" className="select" value={role}
                    onChange={(e) => { setRole(e.target.value as TeamRole); setErrors((x) => ({ ...x, role: undefined })); }}
                    {...described("t-role", errors.role)}>
              {ROLES.map((r) => <option key={r.id} value={r.id}>{r.label}</option>)}
            </select>
            <p id="t-role-can" className="hint">{chosen.can}</p>
            <p id="t-role-err" className="field-error" aria-live="polite">{errors.role}</p></div>
          <p className="note">They get an email invitation, valid for 7 days. On first sign-in they set up an authenticator app.</p>
          <p role="alert" className="form-error">{errors.form}</p>
          <div className="actions">
            <button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={busy}>Send invite</button>
          </div>
        </form>
      </Dialog>
    </>
  );
}

function ChangeRole({ m, onDone }: { m: TeamMember; onDone: (msg: string) => void }) {
  const [open, setOpen] = useState(false);
  const [role, setRole] = useState<TeamRole>(m.role);
  const [error, setError] = useState("");
  async function save(e: FormEvent) {
    e.preventDefault();
    try { await portal.changeTeamRole(m.id, role); setOpen(false); onDone(`${m.name} is now ${ROLES.find((r) => r.id === role)?.label}.`); }
    catch (err) { setError(messageFor((err as PortalError).code)); }
  }
  return (
    <>
      <button type="button" className="btn" onClick={() => { setRole(m.role); setError(""); setOpen(true); }}>
        Change role<span className="visually-hidden">: {m.name}</span></button>
      <Dialog open={open} title={`Change ${m.name}’s role`} onClose={() => setOpen(false)}>
        <form onSubmit={save} className="form-grid">
          <RoleChoice name={`role-${m.id}`} value={role} onChange={setRole} />
          <p role="alert" className="form-error">{error}</p>
          <div className="actions"><button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="submit" className="btn btn-primary">Save</button></div>
        </form>
      </Dialog>
    </>
  );
}

function ResetAuthenticator({ m, onDone }: { m: TeamMember; onDone: (msg: string) => void }) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  async function go() {
    try { await portal.resetMemberAuthenticator(m.id); setOpen(false); onDone(`${m.name}’s authenticator is reset. They’re signed out and set it up again at their next sign-in.`); }
    catch (err) { setError(messageFor((err as PortalError).code)); }
  }
  return (
    <>
      <button type="button" className="btn" onClick={() => { setError(""); setOpen(true); }}>
        Reset authenticator<span className="visually-hidden">: {m.name}</span></button>
      <Dialog open={open} title={`Reset ${m.name}’s authenticator?`} onClose={() => setOpen(false)}>
        <div className="form-grid">
          <p>Their old key and backup codes stop working at once and they’re signed out everywhere. At their next sign-in
            they set up the authenticator again. It goes in the activity log.</p>
          <p role="alert" className="form-error">{error}</p>
          <div className="actions"><button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="button" className="btn btn-primary" onClick={go}>Reset authenticator</button></div>
        </div>
      </Dialog>
    </>
  );
}

function RemoveMember({ m, onDone }: { m: TeamMember; onDone: (msg: string) => void }) {
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  async function go() {
    try { await portal.removeTeamMember(m.id); setOpen(false); onDone(`${m.name} is removed and signed out everywhere.`); }
    catch (err) { setError(messageFor((err as PortalError).code)); }
  }
  return (
    <>
      <button type="button" className="btn btn-danger" onClick={() => { setError(""); setOpen(true); }}>
        Remove<span className="visually-hidden">: {m.name}</span></button>
      <Dialog open={open} title={`Remove ${m.name} from the Magana team?`} onClose={() => setOpen(false)}>
        <div className="form-grid">
          <p>They’re signed out everywhere at once. What they did stays in the activity log.</p>
          <p role="alert" className="form-error">{error}</p>
          <div className="actions"><button type="button" className="btn" onClick={() => setOpen(false)}>Cancel</button>
            <button type="button" className="btn btn-primary" onClick={go}>Remove</button></div>
        </div>
      </Dialog>
    </>
  );
}

export default function TeamMembers() {
  const me = useMe();
  const [rows, setRows] = useState<TeamMember[]>([]);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const load = useCallback(() => { portal.teamMembers().then(setRows).catch((e) => setError((e as PortalError).code)); }, []);
  useEffect(load, [load]);
  const done = (m: string) => { setMessage(m); load(); };
  if (me.kind !== "team" || me.role !== "owner") return <p role="alert">{messageFor("team_role_needed")}</p>;
  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;

  return (
    <>
      <div className="page-head"><div><h1>Magana team</h1>
        <p>People who run Magana. Separate from schools: a team member can’t also be a teacher or school admin.</p></div>
        <AddMember onSent={(email, emailed) => done(emailed ? `Invite sent to ${email}`
          : `${email} is added, but the email couldn’t be sent. Try Resend.`)} /></div>
      <p role="status" className="status-msg">{message}</p>
      <div className="table-wrap table-box" role="region" aria-label="Team members table" tabIndex={0}>
        <table>
          <thead><tr><th scope="col">Name and email</th><th scope="col">Role and what they can do</th>
            <th scope="col">Last sign-in</th><th scope="col">Status</th><th scope="col">Actions</th></tr></thead>
          <tbody>{rows.map((m) => (
            <tr key={m.id}>
              <th scope="row">{m.name}<span className="sub">{m.email}</span></th>
              <td><b>{m.role_label}</b><span className="sub">{m.can}</span></td>
              <td>{m.last_sign_in ?? "—"}</td>
              <td><span className={`pill ${m.status === "active" ? "pill-ready" : "pill-check"}`}>{STATUS[m.status]}</span></td>
              <td className="row-actions">
                {m.email === me.email ? <span>You</span> : m.status === "active" ? (
                  <div className="row-btns"><ChangeRole m={m} onDone={done} /><ResetAuthenticator m={m} onDone={done} /><RemoveMember m={m} onDone={done} /></div>
                ) : (
                  <div className="row-btns">
                    <button type="button" className="btn" onClick={async () => {
                      try { await portal.resendTeamInvite(m.id); done(`Invitation sent again to ${m.email}.`); }
                      catch (e) { setMessage(messageFor((e as PortalError).code)); } }}>Resend<span className="visually-hidden">: {m.name}</span></button>
                    <button type="button" className="btn btn-danger" onClick={async () => {
                      try { await portal.cancelTeamInvite(m.id); done(`Invitation to ${m.email} cancelled.`); }
                      catch (e) { setMessage(messageFor((e as PortalError).code)); } }}>Cancel invite<span className="visually-hidden">: {m.name}</span></button>
                  </div>
                )}
              </td>
            </tr>))}</tbody>
        </table>
      </div>
      <div className="team-grid">
        <section className="card protect" aria-labelledby="sec-h">
          <h2 id="sec-h">Extra protection for team accounts</h2>
          <ul>
            <li>Sign in with an email code <b>plus</b> an authenticator app code.</li>
            <li>Signed out after 15 minutes without activity.</li>
            <li><b>No access to learners’ names, progress or consent.</b> The team sees schools and teachers only.</li>
            <li>Every approval, rejection and role change goes in the activity log.</li>
            <li>There are always 1 or 2 Magana admins; the last one can’t remove themselves.</li>
          </ul>
        </section>
      </div>
    </>
  );
}
