"use client";

// The hero's phone demo (boards "Website · magana.ng home", desktop and phone): four scenes,
// 4 s each, looping. CSS animations only (globals.css, "Hero demo"); this component only
// pauses them and jumps to a scene. Screen readers get one description instead of the
// animated parts, which are aria-hidden; the live caption is aria-hidden too, so it isn't read
// out on every change. Pause/Play is WCAG 2.2.2; hovering or focusing the demo pauses it;
// with reduced motion, scene 2 (the reader) shows still.
import { useEffect, useState, type CSSProperties } from "react";

const SCENE_S = 4;
const STEPS = ["Point", "Listen", "Learn", "Get help"];
const k = (name: string): CSSProperties => ({ ["--k" as string]: name });

function StatusBar({ dark }: { dark: boolean }) {
  const c = dark ? "#FFFFFF" : "#14171A";
  return (
    <div className="pd-status" style={{ color: c }}>
      <span>9:41</span>
      <span className="pd-status-icons">
        <svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill={c} /><rect x="5" y="5.5" width="3" height="6.5" rx="1" fill={c} /><rect x="10" y="3" width="3" height="9" rx="1" fill={c} /><rect x="15" y="0" width="3" height="12" rx="1" fill={c} /></svg>
        <svg width="16" height="12" viewBox="0 0 16 12"><path d="M8 11.5l2.2-2.6a3 3 0 0 0-4.4 0zM8 6a6 6 0 0 1 4.2 1.7l1.4-1.7A8.3 8.3 0 0 0 8 3.6 8.3 8.3 0 0 0 2.4 6l1.4 1.7A6 6 0 0 1 8 6z" fill={c} /></svg>
        <svg width="26" height="12" viewBox="0 0 26 12"><rect x=".5" y=".5" width="22" height="11" rx="3" fill="none" stroke={c} opacity=".5" /><rect x="2" y="2" width="16" height="8" rx="1.8" fill={c} /><rect x="23.5" y="4" width="2" height="4" rx="1" fill={c} opacity=".5" /></svg>
      </span>
    </div>
  );
}

function Back() {
  return (
    <span className="pd-back"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#14171A" strokeWidth="2.6" strokeLinecap="round"><path d="M15 18l-6-6 6-6" /></svg></span>
  );
}

function Phone() {
  return (
    <div className="pd-phone">
      <span className="pd-btn" style={{ left: -4, top: 150, height: 34 }} />
      <span className="pd-btn" style={{ left: -4, top: 200, height: 58 }} />
      <span className="pd-btn" style={{ left: -4, top: 268, height: 58 }} />
      <span className="pd-btn pd-btn-r" style={{ right: -4, top: 220, height: 92 }} />
      <div className="pd-screen">
        {/* 1 · Point: camera guidance on a label */}
        <div className="sc pd-camera" style={k("s1")}>
          <div className="an pd-label" style={k("paper")}>
            <div className="pd-label-name">PARACETAMOL 500 mg</div>
            <div>Take 1 to 2 tablets every 4 to 6 hours</div>
            <div className="pd-label-faint">Do not take more than 8 in 24 hours</div>
            <div>Store below 30 °C. Keep out of reach of children.</div>
            <div>EXP 08/2027</div>
          </div>
          <div className="pd-frame">
            <span className="an pd-corner tl" style={k("corners")} /><span className="an pd-corner tr" style={k("corners")} />
            <span className="an pd-corner bl" style={k("corners")} /><span className="an pd-corner br" style={k("corners")} />
          </div>
          <span className="an pd-prompt" style={{ ...k("c1a"), background: "#FFFFFF", color: "#14171A" }}>◀ Move a little left</span>
          <span className="an pd-prompt" style={{ ...k("c1b"), background: "#FFC94A", color: "#14171A" }}>Hold still…</span>
          <span className="an pd-prompt" style={{ ...k("c1c"), background: "#0A6B4B", color: "#FFFFFF" }}>✓ Got it</span>
          <div className="an pd-flash" style={k("flash")} />
          <div className="pd-shutter-note">Magana takes the photo for you</div>
          <div className="pd-shutter"><span><span /></span></div>
        </div>

        {/* 2 · Listen: the Reader, line by line, with the unclear number */}
        <div className="sc s2" style={k("s2")}>
          <div className="pd-head"><Back /><span><b>Medicine label</b><span>Read exactly as printed</span></span></div>
          <div className="pd-lines">
            <div className="pd-line"><b>PARACETAMOL 500 mg</b></div>
            <div className="an pd-line" style={k("hl1")}>Take 1 to 2 tablets every 4 to 6 hours</div>
            <div className="an pd-line pd-unclear" style={k("hl3")}>Do not take more than <b>[unclear number]</b> in 24 hours</div>
            <div className="an pd-line" style={k("hl2")}>Store below 30 °C. Keep out of reach of children.</div>
          </div>
          <div className="pd-bottom">
            <div className="pd-wave">
              {[10, 18, 24, 14, 26, 20, 12, 22, 16, 8].map((h, i) => (
                <span key={i} className="bar" style={{ height: h, animationDelay: `${i * 0.08}s` }} />
              ))}
            </div>
            <div className="pd-controls"><span>Repeat</span><span className="pd-pause">⏸ Pause</span><span>Next</span></div>
          </div>
        </div>

        {/* 3 · Learn: the Primary 5 quiz */}
        <div className="sc" style={k("s3")}>
          <div className="pd-head"><Back /><span><b>Basic Science quiz</b><span>Primary 5 · Question 3 of 5</span></span></div>
          <div className="pd-quiz">
            <div className="pd-q">Which part of a plant makes food?</div>
            <div className="an pd-opt" style={k("qa")}><b>A</b>The leaf</div>
            <div className="pd-opt"><b>B</b>The root</div>
            <div className="pd-opt"><b>C</b>The flower</div>
          </div>
          <div className="pd-bottom"><span className="pd-say">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#14171A" strokeWidth="2.4"><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5 11a7 7 0 0 0 14 0M12 18v3" /></svg>
            Say A, B or C</span></div>
        </div>

        {/* 4 · Get help: the health worker call-back */}
        <div className="sc" style={k("s4")}>
          <div className="pd-head"><Back /><span><b>Talk to a health worker</b><span>A nurse calls you back</span></span></div>
          <div className="pd-help">
            <div className="an pd-check" style={k("h0")}>
              <span>Quick check · question 1</span>
              <b>Do you have a fever, or does your body feel very hot?</b>
              <div><span className="pd-yes">Yes</span><span>No</span><span>I can’t tell</span></div>
            </div>
            <div className="an pd-booked" style={k("h1")}>
              <svg width="54" height="54" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#0A6B4B" /><path d="M7.5 6.5h2l1 3-1.4 1a7 7 0 0 0 3.4 3.4l1-1.4 3 1v2a1.5 1.5 0 0 1-1.6 1.5A10 10 0 0 1 6 8.1 1.5 1.5 0 0 1 7.5 6.5z" fill="#FFFFFF" /></svg>
              <b>A nurse will call you within 2 hours</b>
              <span>Reference MG-4821</span>
            </div>
          </div>
          <div className="pd-emergency"><b>Emergency?</b> Don’t wait. Go to a clinic or call 112.</div>
        </div>

        <div className="pd-island" />
        <div className="sc pd-bar" style={k("s1")}><StatusBar dark /></div>
        <div className="sc s2 pd-bar" style={k("s2")}><StatusBar dark={false} /></div>
        <div className="sc pd-bar" style={k("s3")}><StatusBar dark={false} /></div>
        <div className="sc pd-bar" style={k("s4")}><StatusBar dark={false} /></div>
        <div className="pd-home" />
        <div className="pd-glass" />
      </div>
    </div>
  );
}

const CAPTIONS: [string, string][] = [
  ["s1", "“Move a little left… hold still… got it.”"],
  ["k1", "“Take 1 to 2 tablets every 4 to 6 hours.”"],
  ["k2", "“Do not take more than… unclear number… in 24 hours. Please check it with a pharmacist.”"],
  ["k3", "“Store below 30 degrees. Keep out of reach of children.”"],
  ["q0", "“Which part of a plant makes food? A, the leaf…”"],
  ["q1", "“You said A. Is that right?”"],
  ["q2", "“Correct! Leaves make food using sunlight.”"],
  ["h0", "“Do you have a fever?”"],
  ["h1", "“Thank you. A nurse will call you within 2 hours.”"],
];

export default function HeroDemo() {
  const [paused, setPaused] = useState(false);
  const [run, setRun] = useState({ key: 0, from: 0, focus: -1 });

  // A jump restarts every animation, the chips' too, at that scene (a negative delay starts
  // them part-way); focus goes back to the chip that was pressed.
  const jump = (scene: number) => setRun((r) => ({ key: r.key + 1, from: scene * SCENE_S + 0.2, focus: scene }));
  useEffect(() => {
    if (run.focus >= 0) document.getElementById(`pd-chip-${run.focus + 1}`)?.focus();
  }, [run]);
  const delay = { ["--d" as string]: `-${run.from}s` } as CSSProperties;

  return (
    <div className={`pd${paused ? " pd-paused" : ""}`} style={delay}>
      <p className="visually-hidden" id="demo-desc">
        A short demo of Magana on a phone, in four steps. Point: Magana tells you to move the phone a little left, then to
        hold still, and takes the photo of a medicine label. Listen: it reads the label line by line, and says “unclear
        number” where it can’t read a number. Learn: a Primary 5 quiz question, answered by saying A. Get help: a quick
        health check books a nurse call-back, and in an emergency you’re told to go to a clinic or call 112.
      </p>
      <div key={run.key} aria-hidden="true" className="pd-visual">
        <Phone />
        <div className="pd-caption">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#0A6B4B" strokeWidth="2.2" strokeLinecap="round"><path d="M4 9v6h4l5 4V5L8 9z" fill="#0A6B4B" /><path d="M16 8.5a5 5 0 0 1 0 7M18.5 6a8.5 8.5 0 0 1 0 12" /></svg>
          <div className="pd-caption-track">
            {CAPTIONS.map(([key, text]) => <span key={key} className={`an pd-cap pd-cap-${key}`} style={k(key)}>{text}</span>)}
          </div>
        </div>
      </div>
      <div key={`steps-${run.key}`} className="pd-steps" role="group" aria-label="Demo steps">
        {STEPS.map((s, i) => (
          <button key={s} id={`pd-chip-${i + 1}`} type="button" className={`tab pd-chip pd-chip-${i + 1}`} style={k(`t${i + 1}`)}
                  onClick={() => jump(i)} aria-describedby="demo-desc">
            <span className="visually-hidden">Show step </span>{i + 1} {s}
          </button>
        ))}
        <button type="button" className="pd-playpause" onClick={() => setPaused((p) => !p)}
                aria-label={paused ? "Play demo" : "Pause demo"}>
          {paused ? (
            <svg width="16" height="16" viewBox="0 0 14 14" aria-hidden="true"><path d="M3 1.5v11l9-5.5z" fill="currentColor" /></svg>
          ) : (
            <svg width="16" height="16" viewBox="0 0 14 14" aria-hidden="true"><rect x="2" y="1" width="3.5" height="12" rx="1" fill="currentColor" /><rect x="8.5" y="1" width="3.5" height="12" rx="1" fill="currentColor" /></svg>
          )}
        </button>
      </div>
    </div>
  );
}
