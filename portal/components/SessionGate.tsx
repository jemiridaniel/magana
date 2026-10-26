"use client";

// Signed-in pages: loads who is signed in (/portal/me) and shares it. Not signed in, or signed
// out after 30 idle minutes: to /sign-in/. A school still waiting for the Magana team sees
// only that. The Magana team sees the admin page.
import { usePathname, useRouter } from "next/navigation";
import { createContext, useCallback, useContext, useEffect, useState } from "react";
import SchoolWaiting from "@/components/SchoolWaiting";
import ServerBanner from "@/components/ServerBanner";
import { messageFor } from "@/lib/messages";
import { portal, PortalError, type Me } from "@/lib/portal";

type Staff = Me & { kind: "staff" };
const SessionContext = createContext<{ me: Me; refresh: () => void } | null>(null);

export function useMe(): Me {
  const s = useContext(SessionContext);
  if (!s) throw new Error("useMe outside SessionGate");
  return s.me;
}

export function useStaff(): Staff | null {
  const me = useMe();
  return me.kind === "staff" ? me : null;
}

export default function SessionGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [me, setMe] = useState<Me | null>(null);
  const [problem, setProblem] = useState("");

  const load = useCallback(() => {
    portal.me().then(setMe).catch((e: unknown) => {
      if (e instanceof PortalError && (e.code === "not_signed_in" || e.code === "session_expired")) {
        const why = e.code === "session_expired" ? "?expired=1" : "";
        router.replace(`/sign-in/${why}`);
      } else {
        setProblem(e instanceof PortalError ? e.code : "failed");
      }
    });
  }, [router]);

  useEffect(load, [load]);

  useEffect(() => {
    if (me?.kind === "team" && !pathname.startsWith("/admin")) router.replace("/admin/");
  }, [me, pathname, router]);

  if (problem && problem !== "server_sleeping") {
    return <main id="main" className="main"><p role="alert">{messageFor(problem)}</p></main>;
  }
  if (!me) {
    // The server may be asleep: then say so here, with "Try again", instead of a blank page.
    return (
      <main id="main" className="main" aria-busy={problem ? undefined : true}>
        <ServerBanner />
        {problem === "server_sleeping"
          ? <button type="button" className="btn btn-primary" onClick={() => { setProblem(""); load(); }}>Open the portal again</button>
          : <p className="visually-hidden">Loading</p>}
      </main>
    );
  }
  if (me.kind === "staff" && me.school.status !== "approved") {
    return <SchoolWaiting name={me.name} school={me.school} />;
  }
  return <SessionContext.Provider value={{ me, refresh: load }}>{children}</SessionContext.Provider>;
}

export function SignOutButton({ className = "btn" }: { className?: string }) {
  const router = useRouter();
  return (
    <button type="button" className={className} onClick={async () => {
      await portal.signOut().catch(() => null);
      router.replace("/sign-in/");
    }}>Sign out</button>
  );
}
