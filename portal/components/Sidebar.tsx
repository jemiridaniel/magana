"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { SignOutButton, useMe } from "@/components/SessionGate";
import { portal } from "@/lib/portal";

const links = [
  { href: "/", label: "Home" },
  { href: "/uploads/", label: "Uploads" },
  { href: "/classes/", label: "My classes" },
  { href: "/quizzes/new/", label: "Quizzes", section: "/quizzes" },
  { href: "/attendance/", label: "Attendance" },
  { href: "/progress/", label: "Learner progress" },
  { href: "/consent/", label: "Consent records" },
];
// The Magana team (boards "Schools to approve", "Team members"): its own pages, by role.
const teamLinks = [
  { href: "/admin/", label: "Schools to approve" },
  { href: "/admin/approved/", label: "Approved schools" },
  { href: "/admin/not-approved/", label: "Not approved" },
  { href: "/admin/activity/", label: "Activity log", roles: ["owner", "reviewer"] },
  { href: "/admin/account/", label: "My account" },
];
const adminLinks = [
  { href: "/teachers/", label: "Teachers" },
  { href: "/school/", label: "School details" },
];

export default function Sidebar() {
  const pathname = usePathname();
  const me = useMe();
  const [pending, setPending] = useState(0);
  useEffect(() => {
    if (me.kind === "team") portal.adminSchools("pending").then((r) => setPending(r.length)).catch(() => null);
  }, [me.kind, pathname]);
  const isCurrent = (href: string, section?: string) =>
    section ? pathname.startsWith(section) : pathname === href || pathname === href.replace(/\/$/, "");
  const item = (l: { href: string; label: string; section?: string }) => (
    <li key={l.href}>
      <Link className="nav-link" href={l.href} aria-current={isCurrent(l.href, l.section) ? "page" : undefined}>{l.label}</Link>
    </li>
  );
  return (
    <header className="sidebar">
      <Link className="brand" href="/" aria-label="Magana for Teachers, Home">
        {/* The Magana mark (brand kit, on-ink colours): decorative, the link has its own name. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="brand-mark" src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}/brand/magana_mark_on_ink.svg`} alt="" width={44} height={44} />
        <span className="brand-text">
          <span className="brand-name">Magana</span>
          <span className="brand-sub">{me.kind === "team" ? "Team admin" : "Teachers"}</span>
        </span>
      </Link>
      <nav aria-label="Main">
        {me.kind === "team" ? (
          <>
            <ul className="nav-list">{teamLinks.filter((l) => !l.roles || l.roles.includes(me.role)).map((l) =>
              l.href === "/admin/" && pending ? (
                <li key={l.href}><Link className="nav-link" href={l.href} aria-current={isCurrent(l.href) ? "page" : undefined}>
                  {l.label}<span className="nav-badge">{pending}<span className="visually-hidden"> waiting</span></span></Link></li>
              ) : item(l))}</ul>
            {me.role === "owner" && (
              <>
                <p className="nav-section" id="nav-owner">Owner only</p>
                <ul className="nav-list" aria-labelledby="nav-owner">{item({ href: "/admin/team/", label: "Magana team" })}</ul>
              </>
            )}
          </>
        ) : (
          <>
            <ul className="nav-list">{links.map(item)}</ul>
            {me.role === "admin" && (
              <>
                <p className="nav-section" id="nav-admin">School admin</p>
                <ul className="nav-list" aria-labelledby="nav-admin">{adminLinks.map(item)}</ul>
              </>
            )}
            <ul className="nav-list nav-after">{item({ href: "/help/", label: "Help" })}</ul>
          </>
        )}
      </nav>
      <div className="sidebar-foot"><SignOutButton className="btn btn-on-ink" /></div>
    </header>
  );
}
