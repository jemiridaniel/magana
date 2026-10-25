"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/uploads", label: "Uploads" },
  { href: "/classes", label: "My classes" },
  { href: "/quizzes/new", label: "Quizzes", section: "/quizzes" },
  { href: "/attendance", label: "Attendance" },
  { href: "/progress", label: "Learner progress" },
  { href: "/consent", label: "Consent records" },
  { href: "/help", label: "Help" },
];

export default function Sidebar() {
  const pathname = usePathname();
  return (
    <header className="sidebar">
      <Link className="brand" href="/uploads" aria-label="Magana for Teachers, home">
        {/* The Magana mark (brand kit, on-ink colours): decorative, the link has its own name. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="brand-mark" src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}/brand/magana_mark_on_ink.svg`} alt="" width={44} height={44} />
        <span className="brand-text">
          <span className="brand-name">Magana</span>
          <span className="brand-sub">Teachers</span>
        </span>
      </Link>
      <nav aria-label="Main">
        <ul className="nav-list">
          {links.map((l) => {
            const current = l.section ? pathname.startsWith(l.section) : pathname === l.href;
            return (
              <li key={l.href}>
                <Link className="nav-link" href={l.href} aria-current={current ? "page" : undefined}>
                  {l.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
    </header>
  );
}
