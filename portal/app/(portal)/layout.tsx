import ServerBanner from "@/components/ServerBanner";
import SessionGate from "@/components/SessionGate";
import Sidebar from "@/components/Sidebar";

// Every portal page: signed in (SessionGate), with the sidebar.
export default function PortalLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <SessionGate>
      <div className="shell">
        <Sidebar />
        <main id="main" className="main" tabIndex={-1}>
          <ServerBanner />
          <div className="content">{children}</div>
        </main>
      </div>
    </SessionGate>
  );
}
