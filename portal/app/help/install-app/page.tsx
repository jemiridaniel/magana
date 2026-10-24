import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "Install the learner app" };

// The teacher-facing summary of docs/TESTER_INSTALL.md. The learner app never links here:
// learners don't need the portal.
export default function InstallAppPage() {
  return (
    <>
      <header className="page-head">
        <div>
          <Link href="/help" className="back-link">‹ Help</Link>
          <h1>Install the learner app</h1>
          <p>
            Magana runs on the learner&rsquo;s own phone. These steps are for you or a helper to do with the learner the first time.
            Magana is in testing, so ask the Magana team for the app file or the web address.
          </p>
        </div>
      </header>

      <section className="card form-grid" aria-labelledby="android-h">
        <h2 id="android-h">On an Android phone (recommended)</h2>
        <ol className="steps">
          <li>Save the file <strong>magana-&lt;version&gt;.apk</strong> the Magana team sends you (WhatsApp, email or Google Drive) on the phone.</li>
          <li>Open it. When the phone says it can&rsquo;t install apps from this source, choose <strong>Settings</strong>, turn on <strong>Allow from this source</strong>, go back and choose <strong>Install</strong>.</li>
          <li>If Google Play Protect says the app is blocked, choose <strong>More details</strong>, then <strong>Install anyway</strong>. It only blocks Magana because Magana isn&rsquo;t in the Play Store yet.</li>
          <li>Turn on <strong>TalkBack</strong>: hold both volume buttons for 3 seconds, or go to Settings → Accessibility → TalkBack.</li>
        </ol>
      </section>

      <section className="card form-grid" aria-labelledby="iphone-h">
        <h2 id="iphone-h">On an iPhone (the web version, for testing)</h2>
        <ol className="steps">
          <li>Open the Magana web address in <strong>Safari</strong>.</li>
          <li>Choose <strong>Share</strong> (the square with an arrow pointing up), then <strong>Add to Home Screen</strong>, then <strong>Add</strong>.</li>
          <li>Open Magana from the home screen. Turn on <strong>VoiceOver</strong> in Settings → Accessibility → VoiceOver, or ask Siri.</li>
        </ol>
        <p className="note">The web version can&rsquo;t ring medicine reminders, and learners under 18 answer by tapping or through Magana&rsquo;s own speech recognition. The iPhone app is coming through TestFlight.</p>
      </section>

      <section className="card form-grid" aria-labelledby="chrome-h">
        <h2 id="chrome-h">On Android without the APK (the web version)</h2>
        <ol className="steps">
          <li>Open the Magana web address in <strong>Chrome</strong>.</li>
          <li>Choose <strong>Install</strong> when Chrome offers it, or the <strong>⋮ menu</strong> (top right) → <strong>Install app</strong> or <strong>Add to Home screen</strong>.</li>
        </ol>
      </section>

      <section className="card form-grid" aria-labelledby="first-h">
        <h2 id="first-h">First start</h2>
        <ol className="steps">
          <li>The learner chooses a language, then their age group.</li>
          <li>Learners aged 13 to 17 choose their class and need a parent&rsquo;s or guardian&rsquo;s consent. Under 13, Magana only runs in a session you start, and you choose the class for that session.</li>
          <li>If a learner chose the wrong class, you can change it in the app&rsquo;s Settings → My class.</li>
          <li>Your quizzes only reach learners inside your class session: on each learner&rsquo;s phone, open Practice quiz → &ldquo;Teacher: open your class session&rdquo; and type the session code shown when you assigned the quiz. On their own, learners only get Magana&rsquo;s sample questions.</li>
        </ol>
        <p className="note">
          Problems? Email <a href="mailto:maganasupport@gmail.com">maganasupport@gmail.com</a> with the screen name, what the learner did and what Magana said.
        </p>
      </section>
    </>
  );
}
