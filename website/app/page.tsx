import Link from "next/link";
import BrailleName from "@/components/BrailleName";
import HeroDemo from "@/components/HeroDemo";
import Samples from "@/components/Samples";
import { APP_URL, PORTAL_URL, SUPPORT_EMAIL } from "@/lib/site";

// The home page, as on the design canvas ("Website · magana.ng home", desktop and phone), plus
// "Hear a sample" and "Your name in Braille".

function Check() {
  return (
    <svg width="30" height="30" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <circle cx="12" cy="12" r="11" fill="#FFC94A" />
      <path d="M6.5 12.5l3.5 3.5 7.5-8" fill="none" stroke="#14171A" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

const STEPS = [
  { title: "Point your phone", text: "Hold your phone over the page. Magana tells you “higher”, “left” or “hold still” until the whole page is in view, then takes the photo itself." },
  { title: "Listen", text: "Magana reads every line aloud, in order, tables row by row. Repeat a line, skip ahead or jump to a heading with one tap or one word." },
  { title: "Learn and get help", text: "Hear schoolwork explained in your language, practise with a voice quiz, or ask a nurse to call you back about a medicine or result." },
];

const PILLARS = [
  { cls: "pillar-learn", title: "Learn.", sub: "At school and at home", items: ["Textbooks, notes and past questions read aloud", "Explanations in Hausa, Yorùbá, Igbo or English", "Voice quizzes from Primary 1 to SS3"] },
  { cls: "pillar-live", title: "Live.", sub: "Everyday papers, for adults", items: ["Medicine labels and medical reports", "Bank statements and bills", "Letters and forms, and medicine reminders"] },
  { cls: "pillar-lead", title: "Lead.", sub: "Skills and confidence", items: ["Lessons on phone skills and getting around", "Magana Champions: blind mentors helping others", "An Independence Score to track progress"] },
];

const PROMISES = [
  ["Numbers are read exactly as printed.", "Doses, amounts and dates are never guessed, rounded or explained away."],
  ["If Magana isn’t sure, it says so.", "An unclear number is read as “unclear number”, with advice to check it."],
  ["No diagnosis, no financial advice.", "For health questions, a nurse or pharmacist calls you back. Danger signs: go to a clinic or call 112."],
  ["Your photos aren’t kept.", "Pages are read and then deleted. Magana never asks for a PIN or password."],
  ["Safe for children.", "Under-18s use Magana with a teacher or guardian, only for schoolwork."],
  ["Checked by health professionals.", "Health rules are reviewed by a clinical pharmacist and a registered nurse."],
];

const TEAM = [
  { initials: "JD", name: "Jemiri Daniel Taiwo", role: "AI/ML engineer, builds Magana" },
  { initials: "OA", name: "Dr. Oluba Amos", role: "Clinical pharmacist, safety review" },
  { initials: "OO", name: "Oluremi O. Balogun", role: "Registered nurse, user research and safeguarding" },
];

export default function Home() {
  return (
    <>
      <section className="hero" aria-labelledby="hero-h">
        <div className="hero-text">
          <span className="badge">Free · Pilot starts November 2026</span>
          <h1 id="hero-h">Hear any printed page. In your language.</h1>
          <p className="lead">
            Magana is a free app that reads printed pages aloud for blind and low-vision Nigerians: schoolwork, medicine labels,
            bank statements and letters, in English, Hausa, Yorùbá and Igbo.
          </p>
          <div className="btn-row">
            <Link href="/android/" className="btn btn-primary">
              <svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                <path d="M5 10h14v8a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2zM7 9a5 5 0 0 1 10 0z" fill="currentColor" />
                <path d="M8 4.5L6.8 2.8M16 4.5l1.2-1.7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
              </svg>
              Get the Android app
            </Link>
            <a href={APP_URL} className="btn btn-outline">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" focusable="false">
                <circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c2.5 3 2.5 15 0 18M12 3c-2.5 3-2.5 15 0 18" />
              </svg>
              Use it in your browser
            </a>
          </div>
          <ul className="soon">
            <li>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true" focusable="false">
                <rect x="6" y="2.5" width="12" height="19" rx="2.5" /><path d="M10.5 18.5h3" />
              </svg>
              <span><strong>iPhone app coming soon.</strong> Until then, iPhone users can open Magana in Safari and add it to the home screen.</span>
            </li>
            <li>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true" focusable="false">
                <path d="M4 20l1.4-4A8 8 0 1 1 8 18.6z" />
              </svg>
              <span><strong>WhatsApp coming soon.</strong> Send a photo, hear it read. No app needed.</span>
            </li>
          </ul>
        </div>
        <div className="hero-art"><HeroDemo /></div>
      </section>

      <section id="how" className="section" aria-labelledby="how-h">
        <h2 id="how-h">How it works</h2>
        <ol className="cards3">
          {STEPS.map((s, i) => (
            <li key={s.title}>
              <div className="step">
                <span className="step-num" aria-hidden="true">{i + 1}</span>
                <h3><span className="visually-hidden">Step {i + 1}: </span>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section id="sample" className="section section-white" aria-labelledby="sample-h">
        <h2 id="sample-h">Hear a sample</h2>
        <p className="lead">
          Three pages the Magana team made, and exactly what Magana read from each. On the medicine label, one number is smudged:
          Magana says “unclear number” instead of guessing. “Listen” uses your browser’s own voice.
        </p>
        <Samples />
      </section>

      <section id="lll" className="section" aria-labelledby="lll-h">
        <h2 id="lll-h">One reading engine. Three parts of life.</h2>
        <div className="cards3">
          {PILLARS.map((p) => (
            <div key={p.title} className={`pillar ${p.cls}`}>
              <h3>{p.title}</h3>
              <p className="sub">{p.sub}</p>
              <ul>{p.items.map((it) => <li key={it}>{it}</li>)}</ul>
            </div>
          ))}
        </div>
      </section>

      <section id="safety" className="section section-white" aria-labelledby="safety-h">
        <h2 id="safety-h">Built to be trusted with what matters</h2>
        <p className="lead">Health and money papers carry real risk, so Magana follows strict rules.</p>
        <ul className="promises">
          {PROMISES.map(([head, rest]) => (
            <li key={head}><Check /><span><strong>{head}</strong> {rest}</span></li>
          ))}
        </ul>
        <Link href="/privacy/" style={{ alignSelf: "flex-start", fontSize: 21, fontWeight: 700 }}>Read our privacy notice</Link>
      </section>

      <section id="braille" className="section" aria-labelledby="braille-h">
        <h2 id="braille-h">Your name in Braille</h2>
        <p className="lead">The dots in Magana’s logo are the Braille letter m. Type your name to see it in Braille, the way the logo spells ⠍⠁⠛⠁⠝⠁.</p>
        <BrailleName />
      </section>

      <section id="schools" className="section" aria-labelledby="schools-h">
        <h2 id="schools-h">For teachers and schools</h2>
        <div className="schools">
          <ul>
            <li>Upload class notes and tests: learners get audio, Braille-ready files and large print.</li>
            <li>Write voice quizzes for your class in minutes.</li>
            <li>Take attendance and see each learner’s progress.</li>
            <li>Guardian consent is built in for every learner under 18.</li>
          </ul>
          <div className="pilot">
            <p><strong>Free for learners.</strong> We’re looking for schools in Lagos and beyond to join our pilot from February 2027.</p>
            <a href={PORTAL_URL} className="btn btn-amber">Open the teacher portal</a>
            <a href={`mailto:${SUPPORT_EMAIL}?subject=Magana%20school%20pilot`}>Ask about the pilot: {SUPPORT_EMAIL}</a>
          </div>
        </div>
      </section>

      <section id="team" className="section" aria-labelledby="team-h">
        <h2 id="team-h">Made in Nigeria, with the people it serves</h2>
        <p className="lead">
          Want to test Magana, review a language, or help a learner? We’d love to hear from you at{" "}
          <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
        </p>
        <ul className="team">
          {TEAM.map((m) => (
            <li key={m.name}>
              <span className="initials" aria-hidden="true">{m.initials}</span>
              <span style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                <strong style={{ fontSize: 21 }}>{m.name}</strong>
                <span className="role">{m.role}</span>
              </span>
            </li>
          ))}
        </ul>
        <p className="credit">
          Magana is being designed and tested with blind and low-vision Nigerians. It is our entry in the Nigeria AI Collective and
          Data Science Nigeria “AI for Visual Impairment” hackathon. Nigerian-language explanations use N-ATLaS. N-ATLaS is an
          initiative of the Federal Ministry of Communications, Innovation and Digital Economy, and powered by Awarri Technologies.
        </p>
      </section>
    </>
  );
}
