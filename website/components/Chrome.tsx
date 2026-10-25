// The accessibility bar, header and footer on every page (design canvas, "Website · magana.ng home").
import Link from "next/link";
import Lockup, { Mark } from "@/components/Lockup";
import { PORTAL_URL, SUPPORT_EMAIL } from "@/lib/site";

const LANGUAGES = [
  { code: "ha", name: "Hausa" },
  { code: "yo", name: "Yorùbá" },
  { code: "ig", name: "Igbo" },
];

function AccessBar() {
  return (
    <div className="access-bar">
      <p>This website works with screen readers, keyboards and zoom.</p>
      <ul className="langs" aria-label="Website language">
        <li><span className="lang lang-current" lang="en" aria-current="true">English</span></li>
        {LANGUAGES.map((l) => (
          <li key={l.code}>
            <span className="lang" lang={l.code}>{l.name}</span> <span className="lang-note">translation coming</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

const NAV = [
  { href: "/#how", label: "How it works" },
  { href: "/#schools", label: "For schools" },
  { href: "/#safety", label: "Safety" },
  { href: "/#team", label: "Team" },
];

export function Header() {
  return (
    <header className="site-top">
      <AccessBar />
      <div className="site-header">
      <Link href="/" className="home-link" aria-label="Magana home"><Lockup width={190} /></Link>
      <nav aria-label="Main" className="nav-wide">
        {NAV.map((n) => <a key={n.href} href={n.href}>{n.label}</a>)}
        <Link href="/android/" className="btn btn-primary">Get Magana</Link>
      </nav>
      {/* Phones: the same links behind one button, with no JavaScript needed. */}
      <details className="nav-narrow">
        <summary className="btn btn-outline">Menu</summary>
        <nav aria-label="Main">
          {NAV.map((n) => <a key={n.href} href={n.href}>{n.label}</a>)}
          <Link href="/android/" className="btn btn-primary">Get Magana</Link>
        </nav>
      </details>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="site-footer">
      <div className="footer-brand">
        <span className="footer-name">
          <Mark fill="#FFC94A" dot="#14171A" size={40} />
          <span className="footer-word">Magana</span>
          <span className="footer-braille" role="img" aria-label="magana in Braille">⠍⠁⠛⠁⠝⠁</span>
        </span>
        <span className="footer-tag">Learn. Live. Lead.</span>
      </div>
      <nav aria-label="Footer" className="footer-nav">
        <Link href="/privacy/">Privacy notice</Link>
        <Link href="/accessibility/">Accessibility statement</Link>
        <Link href="/android/">Get the Android app</Link>
        <a href={PORTAL_URL}>Teacher portal</a>
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
      </nav>
      <p className="footer-small">
        © 2026 Magana. Magana does not give medical or financial advice. In an emergency, call 112.
        This website sets no cookies and uses no analytics or trackers.
      </p>
    </footer>
  );
}
