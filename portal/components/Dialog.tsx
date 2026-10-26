"use client";

// An accessible modal: the native <dialog> opened with showModal() makes the page behind inert;
// Tab and Shift+Tab cycle inside it (browsers would otherwise let focus leave for the address
// bar); Escape closes it; focus goes back to the button that opened it.
import { useEffect, useId, useRef } from "react";

export default function Dialog({ open, title, onClose, children, describedBy, className = "dialog", closeButton = false }: {
  open: boolean; title: string; onClose: () => void; children: React.ReactNode; describedBy?: string;
  className?: string;   // "dialog drawer": a side panel
  closeButton?: boolean;  // a × in the corner, besides Escape
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const opener = useRef<Element | null>(null);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) {
      opener.current = document.activeElement;
      d.showModal();
    } else if (!open && d.open) {
      d.close();
    }
  }, [open]);

  return (
    <dialog
      ref={ref} className={className} aria-labelledby={titleId} aria-describedby={describedBy}
      onClose={() => {
        onClose();
        (opener.current as HTMLElement | null)?.focus?.();
      }}
      onCancel={(e) => { e.preventDefault(); ref.current?.close(); }}
      onKeyDown={(e) => {
        if (e.key !== "Tab" || !ref.current) return;
        const items = [...ref.current.querySelectorAll<HTMLElement>(
          "button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])")]
          .filter((el) => !el.hasAttribute("disabled") && el.offsetParent !== null);
        if (!items.length) return;
        const first = items[0], last = items[items.length - 1];
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
      }}
    >
      <div className="dialog-head">
        <h2 id={titleId}>{title}</h2>
        {closeButton && <button type="button" className="btn btn-icon" aria-label="Close" onClick={() => ref.current?.close()}>×</button>}
      </div>
      {children}
    </dialog>
  );
}
