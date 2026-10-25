"use client";

// Home (design canvas: "Teacher portal · Home"): the greeting, quick actions, what needs the
// teacher's attention (from real data), their classes and this week's figures.
import Link from "next/link";
import { useEffect, useState } from "react";
import ConsentReminder from "@/components/ConsentReminder";
import { SignOutButton } from "@/components/SessionGate";
import { messageFor } from "@/lib/messages";
import { modeLabel, portal, PortalError, type Attention, type HomeData } from "@/lib/portal";

function greeting(now: Date) {
  const h = now.getHours();
  return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
}

function AttentionItem({ a }: { a: Attention }) {
  switch (a.kind) {
    case "consent":
      return (
        <li className="attention">
          <div>
            <strong>{a.count === 1 ? "1 guardian hasn’t agreed yet" : `${a.count} guardians haven’t agreed yet`}</strong>
            <span>{a.learners.map((l) => `${l.name}${l.class ? ` (${l.class})` : ""}`).join(", ")}</span>
          </div>
          <ConsentReminder learnerId={a.learners[0].id} learnerName={a.learners[0].name} />
        </li>
      );
    case "upload_check":
      return (
        <li className="attention">
          <div><strong>{a.upload.title} needs checking</strong><span>{a.upload.note || "Magana was unsure about part of it."}</span></div>
          <Link className="btn" href={`/uploads/?check=${a.upload.id}`}>Review</Link>
        </li>
      );
    case "upload_ready":
      return (
        <li className="attention">
          <div><strong>{a.upload.title} is ready</strong><span>Audio, Braille-ready file and large print</span></div>
          <Link className="btn" href={`/uploads/?share=${a.upload.id}`}>Share with class</Link>
        </li>
      );
    case "low_attendance":
      return (
        <li className="attention">
          <div>
            <strong>{a.learner.name} missed {a.sessions - a.attended} of the last {a.sessions} sessions</strong>
            <span>{a.learner.class ? `${a.learner.class} · ` : ""}attendance {a.attendance}%</span>
          </div>
          <Link className="btn" href={`/learner/?id=${a.learner.id}`}>View learner</Link>
        </li>
      );
    case "second_admin":
      return (
        <li className="attention">
          <div><strong>Add a second school admin</strong><span>Every school keeps at least two admins, so it’s never locked out.</span></div>
          <Link className="btn" href="/teachers/">Teachers</Link>
        </li>
      );
    case "deletion":
      return (
        <li className="attention">
          <div><strong>A guardian asked for a learner’s data to be deleted</strong>
            <span>Confirm by {new Date(a.deletion.due).toLocaleDateString("en-NG", { day: "numeric", month: "long" })}.</span></div>
          <Link className="btn" href="/consent/#deletions">Review</Link>
        </li>
      );
  }
}

export default function HomePage() {
  const [data, setData] = useState<HomeData | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    portal.home().then(setData).catch((e) => setError((e as PortalError).code));
  }, []);

  if (error) return error === "server_sleeping" ? null : <p role="alert">{messageFor(error)}</p>;
  if (!data) return <p aria-busy="true">Loading…</p>;

  const me = data.me;
  const today = new Date().toLocaleDateString("en-NG", { weekday: "long", day: "numeric", month: "long" });
  const first = data.classes[0];
  return (
    <>
      <header className="page-head home-head">
        <div>
          <h1>{greeting(new Date())}, {me.name}</h1>
          <p>{me.school.name} · {today}</p>
        </div>
        <div className="actions">
          <span className="badge">{me.role === "admin" ? "School admin" : "Teacher"}</span>
          <SignOutButton />
        </div>
      </header>

      <section aria-labelledby="quick-h" className="card-section">
        <h2 id="quick-h">Quick actions</h2>
        <ul className="quick">
          <li><Link href="/uploads/"><strong>Upload a page</strong><span>Notes, tests, photos</span></Link></li>
          <li><Link href="/attendance/"><strong>Take attendance</strong><span>{first ? first.name : "For a class"}</span></Link></li>
          <li><Link href="/quizzes/new/"><strong>Create a quiz</strong><span>Voice quiz for a class</span></Link></li>
          <li><Link href="/classes/"><strong>Add a learner</strong><span>Share a class code</span></Link></li>
        </ul>
      </section>

      <section aria-labelledby="att-h" className="card-section">
        <h2 id="att-h">Needs your attention{data.attention.length ? ` · ${data.attention.length}` : ""}</h2>
        {data.attention.length ? (
          <ul className="attention-list">{data.attention.map((a, i) => <AttentionItem key={i} a={a} />)}</ul>
        ) : (
          <p className="empty">Nothing needs your attention. Well done.</p>
        )}
      </section>

      <section aria-labelledby="cls-h" className="card-section">
        <div className="section-head"><h2 id="cls-h">Your classes</h2><Link href="/classes/">All classes ›</Link></div>
        {data.classes.length ? (
          <ul className="class-cards">
            {data.classes.map((c) => (
              <li key={c.id}>
                <Link href={`/classes/?class=${c.id}`}>
                  <strong>{c.name}</strong>
                  <span>{modeLabel[c.mode]}</span>
                  <span>{c.mode === "classroom" ? "Teacher-led only" : `${c.learners} ${c.learners === 1 ? "learner" : "learners"}`}
                    {c.attendance !== null ? ` · attendance ${c.attendance}%` : ""}</span>
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="empty">No classes yet. <Link href="/classes/">Add your first class</Link> to get its code.</p>
        )}
      </section>

      <section aria-labelledby="week-h" className="card-section">
        <h2 id="week-h">This week</h2>
        {data.week ? (
          <dl className="figures">
            <div><dt>Pages read this week</dt><dd>{data.week.pages}</dd></div>
            <div><dt>Done without sighted help</dt><dd>{data.week.unaided}%</dd></div>
            <div><dt>Average quiz score</dt><dd>{data.week.quiz_average === null ? "—" : `${data.week.quiz_average}%`}</dd></div>
          </dl>
        ) : (
          <p className="empty">No figures yet this week. They appear when learners share their progress from the app.</p>
        )}
      </section>
    </>
  );
}
