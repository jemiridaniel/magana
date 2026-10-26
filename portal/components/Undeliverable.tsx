// Shown next to an address that bounced or was marked as spam (backend ses_events.py): Magana
// sends nothing more to it, so invites and resends are refused too.
export function Undeliverable({ show }: { show?: boolean }) {
  if (!show) return null;
  return (
    <span className="undeliverable">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
        <path d="M12 3l10 18H2z" /><path d="M12 10v5M12 18v.5" strokeLinecap="round" /></svg>
      We couldn’t deliver to this address
    </span>
  );
}
