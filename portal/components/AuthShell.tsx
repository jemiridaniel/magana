import ServerBanner from "@/components/ServerBanner";

// The brand panel, then the page (design canvas: "Teacher portal · Sign in", "Register your
// school", "School waiting for confirmation").
export default function AuthShell({ children, wide = false }: { children: React.ReactNode; wide?: boolean }) {
  return (
    <div className="auth">
      <header className="auth-brand">
        <span className="auth-logo">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}/brand/magana_mark_on_ink.svg`} alt="" width={52} height={52} />
          <span>
            <span className="auth-name">Magana</span>
            <span className="auth-sub">for Teachers</span>
          </span>
        </span>
        <div className="auth-pitch">
          <p className="auth-headline">Make every page accessible for your class.</p>
          <p>Upload notes, write voice quizzes, take attendance and follow each learner’s progress.</p>
        </div>
        <span className="auth-braille" role="img" aria-label="magana in Braille">⠍⠁⠛⠁⠝⠁</span>
      </header>
      <main id="main" className="auth-main" tabIndex={-1}>
        <div className={`auth-form${wide ? " auth-form-wide" : ""}`}>
          <ServerBanner />
          {children}
        </div>
      </main>
    </div>
  );
}
