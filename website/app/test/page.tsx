import type { Metadata } from "next";
import Link from "next/link";
import { APK_URL, SUPPORT_EMAIL } from "@/lib/site";

export const metadata: Metadata = { title: "What to test" };

// For the team's testers (magana.ng/test): six short tasks and how to tell us what happened.
const TASKS: { title: string; how: string; listen: string }[] = [
  { title: "Read an English page",
    how: "Open Magana, choose Read a page, and take a photo of a page of an English textbook or a printed letter.",
    listen: "Does it read every line, in order? Does it warn you about anything it isn't sure of?" },
  { title: "Read a page with two columns",
    how: "Photograph a page set in two columns, like a newspaper or many textbooks.",
    listen: "Does it read the left column to the end before the right one? Say “next column” to jump." },
  { title: "Read a table",
    how: "Photograph a page with a table, such as a timetable or a list of results.",
    listen: "Does it read each row with its column names? Are the numbers exactly as printed?" },
  { title: "Read a Hausa, Yorùbá or Igbo page",
    how: "Photograph a printed page in one of these languages.",
    listen: "Does it warn you once that it can miss special letters? Try Spell word on a marked word." },
  { title: "Read a page in airplane mode",
    how: "Turn on airplane mode, then read a page.",
    listen: "Does it say “No internet. Reading on this phone.”? Turn airplane mode off later: does the full reading appear in My library?" },
  { title: "Read a medicine label",
    how: "Choose Everyday papers, then Medicine label, and photograph a real medicine box or label.",
    listen: "Are the medicine name, dose and dates read exactly? Does anything unclear say “unclear number”?" },
];

export default function TestPage() {
  return (
    <div className="page">
      <article className="prose" aria-labelledby="test-h">
        <h1 id="test-h">What to test</h1>
        <p>Thank you for testing Magana. Each task takes a few minutes. Try them with TalkBack on if you can. Nothing you photograph is kept.</p>
        <p>
          <a href={APK_URL} className="btn btn-primary">Download for Android</a>{" "}
          <Link href="/android/">How to install it</Link>
        </p>
        <h2>Six tasks</h2>
        <ol className="test-tasks">
          {TASKS.map((t) => (
            <li key={t.title}>
              <h3>{t.title}</h3>
              <p>{t.how}</p>
              <p><strong>Listen for:</strong> {t.listen}</p>
            </li>
          ))}
        </ol>
        <h2>Tell us what happened</h2>
        <p>Right after anything goes wrong, use <strong>Report a problem</strong> in the app. It goes straight to the Magana team.</p>
        <ul>
          <li>Say “report a problem” on the Home screen or while a page is being read, or open <strong>Settings → Report a problem</strong>.</li>
          <li>Choose what went wrong. You can add a short voice note (up to 60 seconds).</li>
          <li>Switch on “Include this page’s text” only if you are happy to share it. Photos are never sent.</li>
        </ul>
        <p>Anything else: email <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.</p>
      </article>
    </div>
  );
}
