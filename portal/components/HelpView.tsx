"use client";

import Link from "next/link";
import { useState, type FormEvent } from "react";
import { recentUploads } from "@/lib/data";

interface Guide {
  id: string;
  title: string;
  summary: string;
  steps: string[];
  link: { href: string; label: string };
}

// Short guides built from what the portal does today. Full guides are still to be written.
const guides: Guide[] = [
  {
    id: "start",
    title: "Getting started",
    summary: "Create a class and invite your first learners.",
    steps: [
      "Open My classes and choose ‘+ New class’.",
      "Choose the learners’ age: 13–17 is Guided mode, under 13 is Classroom mode, 18 and over is Standard mode.",
      "Choose ‘Invite learner’ and enter their name, preferred formats and language.",
      "For learners under 18, request a guardian’s consent from Consent records. Their account stays locked until it arrives.",
    ],
    link: { href: "/classes", label: "Open My classes" },
  },
  {
    id: "versions",
    title: "Making Braille and audio versions",
    summary: "Upload notes and print BRF files on an embosser.",
    steps: [
      "Open Uploads and choose the class.",
      "Tick the versions to make: audio in English, Hausa, Yorùbá or Igbo, Braille (BRF) and large print.",
      "Drop in a PDF, a Word file or photos of the pages.",
      "When the status says Ready, download the BRF file and send it to your Braille embosser.",
      "If the status says Check, review those parts first.",
    ],
    link: { href: "/uploads", label: "Open Uploads" },
  },
  {
    id: "safety",
    title: "Keeping learners safe",
    summary: "Age modes, consent and what Magana will not do.",
    steps: [
      "Under 13: Classroom mode only, on your device, during a lesson. No accounts, and sessions are not saved.",
      "13 to 17: Guided mode, curriculum only, once a parent or guardian has consented.",
      "You see progress summaries only, never the pages learners photograph or the questions they ask.",
      "Magana never diagnoses or gives financial advice, and never asks for a PIN or password.",
      "When consent is withdrawn, the account closes and the learner’s data is deleted.",
    ],
    link: { href: "/consent", label: "Open Consent records" },
  },
  {
    id: "teaching",
    title: "Teaching with Magana",
    summary: "Help learners take clear photos and check answers.",
    steps: [
      "Magana speaks framing guidance while the learner points the camera at a page.",
      "When it is unsure about a word or number, it says so instead of guessing. Ask the learner to take the photo again.",
      "Learner progress suggests camera tips for learners with many unclear photos.",
    ],
    link: { href: "/progress", label: "Open Learner progress" },
  },
];

const faqs: { q: string; a: string }[] = [
  {
    q: "What should I do when an item says “Check”?",
    a: "Magana was unsure about part of the page, often a faint line, a formula or a diagram. Open it, compare with the original and correct it before sharing.",
  },
  { q: "Can learners under 13 use Magana?", a: "Only in Classroom mode, on your device, during a lesson. They do not get their own accounts." },
  {
    q: "Does Magana work without internet?",
    a: "Basic reading aloud works offline on the learner’s phone. Tables, maths, diagrams and explanations in Hausa, Yorùbá and Igbo need a connection.",
  },
  { q: "Who can see what my learners read?", a: "No one. Photos are deleted after reading, and teachers only see progress summaries." },
];

// Accent-insensitive match, so "yoruba" finds "Yorùbá".
const fold = (s: string) => s.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();

export default function HelpView() {
  const [query, setQuery] = useState("");
  const [openGuide, setOpenGuide] = useState<string | null>(null);
  const [reporting, setReporting] = useState(false);
  const [reportMessage, setReportMessage] = useState("");

  const words = fold(query).split(/\s+/).filter(Boolean);
  const matches = (text: string) => words.every((w) => fold(text).includes(w));
  const shownGuides = guides.filter((g) => matches([g.title, g.summary, ...g.steps].join(" ")));
  const shownFaqs = faqs.filter((f) => matches(`${f.q} ${f.a}`));
  const total = shownGuides.length + shownFaqs.length;

  function report(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const what = String(new FormData(e.currentTarget).get("what") ?? "").trim();
    if (!what) {
      setReportMessage("Describe the problem first.");
      return;
    }
    setReportMessage("Not sent: problem reports go out once the portal is connected to the Magana server. Your description is still in the box: copy it into an email to maganasupport@gmail.com.");
  }

  return (
    <>
      <div className="page-head">
        <div style={{ display: "grid", gap: 16, width: "100%" }}>
          <h1>Help</h1>
          <div className="field" style={{ maxWidth: 560 }}>
            <label htmlFor="help-search">Search help</label>
            <input
              id="help-search" type="search" className="input" placeholder="For example: Braille files" autoComplete="off"
              value={query} onChange={(e) => setQuery(e.target.value)} aria-describedby="help-results"
            />
          </div>
          <p id="help-results" className="status-msg" role="status" aria-live="polite">
            {words.length ? (total ? `${total} ${total === 1 ? "result" : "results"} for “${query.trim()}”` : `No help matches “${query.trim()}”. Try another word, or contact us below.`) : ""}
          </p>
        </div>
      </div>

      {shownGuides.length > 0 && (
        <section aria-labelledby="guides-head" style={{ display: "grid", gap: 16 }}>
          <h2 id="guides-head">Guides</h2>
          <ul className="guide-grid">
            {shownGuides.map((g) => {
              const expanded = openGuide === g.id;
              return (
                <li key={g.id} className="guide">
                  <h3>
                    <button
                      type="button" className="guide-toggle" aria-expanded={expanded} aria-controls={`guide-${g.id}`}
                      onClick={() => setOpenGuide(expanded ? null : g.id)}
                    >
                      <span className="guide-title">{g.title}<span aria-hidden="true">{expanded ? "−" : "+"}</span></span>
                      <span className="note" style={{ fontSize: "1rem", fontWeight: 400 }}>{g.summary}</span>
                    </button>
                  </h3>
                  {expanded && (
                    <div id={`guide-${g.id}`} className="guide-body">
                      <ol>{g.steps.map((s) => <li key={s}>{s}</li>)}</ol>
                      <Link className="link-target" href={g.link.href} style={{ paddingLeft: 0 }}>{g.link.label}</Link>
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {shownFaqs.length > 0 && (
        <section aria-labelledby="faq-head" style={{ display: "grid", gap: 16 }}>
          <h2 id="faq-head">Common questions</h2>
          <div className="faq">
            {shownFaqs.map((f) => (
              <details key={f.q}>
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
        </section>
      )}

      <section className="card contact" aria-labelledby="contact-head">
        <div style={{ display: "grid", gap: 4 }}>
          <h2 id="contact-head">Still need help?</h2>
          <p>
            Email <a href="mailto:maganasupport@gmail.com">maganasupport@gmail.com</a>. You can also report a problem with any reading.
          </p>
        </div>
        <button
          type="button" className="btn btn-primary" aria-expanded={reporting} aria-controls="report-form"
          onClick={() => { setReporting((r) => !r); setReportMessage(""); }}
        >
          Report a problem
        </button>
        {reporting && (
          <form id="report-form" className="form-grid" style={{ width: "100%" }} onSubmit={report} noValidate aria-label="Report a problem">
            <div className="field" style={{ maxWidth: 560 }}>
              <label htmlFor="report-item">Which reading?</label>
              <select id="report-item" name="item" className="select" defaultValue="">
                <option value="">Not about one upload</option>
                {recentUploads.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
              </select>
            </div>
            <div className="field">
              <label htmlFor="report-what">What went wrong?</label>
              <textarea id="report-what" name="what" className="input" aria-describedby="report-hint" />
              <span id="report-hint" className="hint">Please do not include learners&rsquo; personal details.</span>
            </div>
            <div className="actions">
              <button type="submit" className="btn btn-primary">Send report</button>
              <button type="button" className="btn" onClick={() => setReporting(false)}>Cancel</button>
            </div>
            <p className="status-msg" role="status" aria-live="polite">{reportMessage}</p>
          </form>
        )}
      </section>

      <p className="note">
        This portal is designed for screen readers such as NVDA and JAWS, and for keyboard-only use. Accessibility statement:{" "}
        <span className="placeholder-text">to be added</span>.
      </p>
    </>
  );
}
