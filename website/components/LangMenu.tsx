"use client";

// The website language dropdown in the accessibility bar (design canvas, "Website · magana.ng
// home", phone board 402 wide). A <details> menu, so it opens and closes without JavaScript;
// with JavaScript, Escape and a tap outside close it too. Only English exists so far: the other
// languages are listed with "translation coming".
import { useEffect, useRef } from "react";

const LANGUAGES = [
  { code: "ha", name: "Hausa" },
  { code: "yo", name: "Yorùbá" },
  { code: "ig", name: "Igbo" },
];

export default function LangMenu() {
  const ref = useRef<HTMLDetailsElement>(null);

  useEffect(() => {
    const menu = ref.current;
    if (!menu) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && menu.open) {
        menu.open = false;
        menu.querySelector("summary")?.focus();
      }
    };
    const onPointer = (e: PointerEvent) => {
      if (menu.open && !menu.contains(e.target as Node)) menu.open = false;
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointer);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onPointer);
    };
  }, []);

  return (
    <details className="lang-menu" ref={ref}>
      <summary>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" focusable="false">
          <circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c2.5 3 2.5 15 0 18M12 3c-2.5 3-2.5 15 0 18" />
        </svg>
        <span><span className="visually-hidden">Website language: </span>English</span>
        <svg className="lang-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
          <path d="M6 9l6 6 6-6" />
        </svg>
      </summary>
      <ul className="lang-list" aria-label="Website language">
        <li>
          <span className="lang-option lang-current" lang="en" aria-current="true">
            English
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
              <path d="M5 12.5l4.5 4.5L19 7.5" />
            </svg>
          </span>
        </li>
        {LANGUAGES.map((l) => (
          <li key={l.code}>
            <span className="lang-option">
              <span lang={l.code}>{l.name}</span> <span className="lang-note">translation coming</span>
            </span>
          </li>
        ))}
      </ul>
    </details>
  );
}
