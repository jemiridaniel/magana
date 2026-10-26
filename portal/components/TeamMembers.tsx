"use client";

// Magana team (board "Magana team admin · Team members"): Owners add, invite, change and remove
// team members. One role each; at least one owner always; a team member can't also be a teacher
// or school admin (the server checks all three).
import { useCallback, useEffect, useState, type FormEvent } from "react";
import Dialog from "@/components/Dialog";
import { useMe } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type TeamMember, type TeamRole } from "@/lib/portal";

const ROLES: { id: TeamRole; label: string; can: string }[] = [
  { id: "reviewer", label: "School reviewer", can: "Approve or reject schools, view proof documents, see the activity log." },
  { id: "support", label: "Support (view only)", can: "See schools and teachers, resend emails. Can’t approve or change anything." },
  { id: "owner", label: "Owner", can: "Everything, including adding and removing team members. Keep to 2 people." },
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
  const [role, setRole] = useState<TeamRole>("reviewer");
  const load = useCallback(() => { portal.teamMembers().then(setRows).catch((e) => setError((e as PortalError).code)); }, []);
  useEffect(load, [load]);
  const done = (m: string) => { setMessage(m); load(); };
  if (me.kind !== "team" || me.role !== "owner") return <p role="alert">{messageFor("team_role_needed")}</p>;
  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;

  async function add(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const f = new FormData(form);
    const body = { name: String(f.get("name") ?? "").trim(), email: String(f.get("email") ?? "").trim(), role };
    if (!body.name || !body.email) { setMessage("Enter their name and email."); return; }
    try {
      const r = await portal.addTeamMember(body);
      form.reset();
      done(r.emailed ? `Invitation sent to ${body.email}. It works for 7 days.` : `${body.email} is added, but the email couldn’t be sent. Try Resend.`);
    } catch (err) {
      const code = (err as PortalError).code;
      setMessage(code === "form_invalid" ? "Check the name and the email address." : messageFor(code));
    }
  }

  return (
    <>
      <div className="page-head"><div><h1>Magana team</h1>
        <p>People who run Magana. Separate from schools: a team member can’t also be a teacher or school admin.</p></div>
        <a className="btn btn-primary" href="#add">+ Add team member</a></div>
      <p role="status" className="status-msg">{message}</p>
      <div className="table-wrap" role="region" aria-label="Team members table" tabIndex={0}>
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
                  <><ChangeRole m={m} onDone={done} /><ResetAuthenticator m={m} onDone={done} /><RemoveMember m={m} onDone={done} /></>
                ) : (
                  <>
                    <button type="button" className="btn" onClick={async () => {
                      try { await portal.resendTeamInvite(m.id); done(`Invitation sent again to ${m.email}.`); }
                      catch (e) { setMessage(messageFor((e as PortalError).code)); } }}>Resend<span className="visually-hidden">: {m.name}</span></button>
                    <button type="button" className="btn btn-danger" onClick={async () => {
                      try { await portal.cancelTeamInvite(m.id); done(`Invitation to ${m.email} cancelled.`); }
                      catch (e) { setMessage(messageFor((e as PortalError).code)); } }}>Cancel invite<span className="visually-hidden">: {m.name}</span></button>
                  </>
                )}
              </td>
            </tr>))}</tbody>
        </table>
      </div>
      <div className="team-grid">
        <form id="add" className="card form-grid team-add" onSubmit={add} aria-labelledby="add-h">
          <h2 id="add-h">Add a team member</h2>
          <div className="field"><label htmlFor="t-name">Full name</label><input id="t-name" name="name" className="input" /></div>
          <div className="field"><label htmlFor="t-email">Email</label><input id="t-email" name="email" type="email" className="input" /></div>
          <RoleChoice name="new-role" value={role} onChange={setRole} />
          <div><button type="submit" className="btn btn-primary">Send invite</button></div>
        </form>
        <section className="card protect" aria-labelledby="sec-h">
          <h2 id="sec-h">Extra protection for team accounts</h2>
          <ul>
            <li>Sign in with an email code <b>plus</b> an authenticator app code.</li>
            <li>Signed out after 15 minutes without activity.</li>
            <li><b>No access to learners’ names, progress or consent.</b> The team sees schools and teachers only.</li>
            <li>Every approval, rejection and role change goes in the activity log.</li>
            <li>There must always be at least one owner; an owner can’t remove themselves if they’re the last one.</li>
          </ul>
        </section>
      </div>
    </>
  );
}
