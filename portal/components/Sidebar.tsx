"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/uploads", label: "Uploads" },
  { href: "/classes", label: "My classes" },
  { href: "/attendance", label: "Attendance" },
  { href: "/progress", label: "Learner progress" },
  { href: "/consent", label: "Consent records" },
  { href: "/help", label: "Help" },
];

export default function Sidebar() {
  const pathname = usePathname();
  return (
    <header className="sidebar">
      <div className="brand">
        <span className="brand-name">Magana</span>
        <span className="brand-sub">Teachers</span>
      </div>
      <nav aria-label="Main">
        <ul className="nav-list">
          {links.map((l) => (
            <li key={l.href}>
              <Link className="nav-link" href={l.href} aria-current={pathname === l.href ? "page" : undefined}>
                {l.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </header>
  );
}
