"use client";

// "Hear a sample": three of the team's own test pages, with exactly what Magana read from each
// (website/scripts/make_samples.py runs them through the real reader). "Listen" says those lines
// with the browser's own speech: an unreliable number is said as "unclear number", followed by
// Magana's warning. No uploads, no API calls.
import { useEffect, useRef, useState } from "react";
import samples from "@/data/samples.json";

type Line = { shown: string; said: string; warning: string | null };
type Sample = { id: string; title: string; alt: string; width: number; height: number; lines: Line[] };

function Shown({ text }: { text: string }) {
  const parts = text.split("[unclear number]");
  return (
    <>
      {parts.map((p, i) => (
        <span key={i}>
          {p}
          {i < parts.length - 1 && <span className="unclear">[unclear number]</span>}
        </span>
      ))}
    </>
  );
}

function pickVoice(): SpeechSynthesisVoice | undefined {
  const voices = window.speechSynthesis.getVoices();
  return (
    voices.find((v) => v.lang === "en-NG") ??
    voices.find((v) => v.lang === "en-GB") ??
    voices.find((v) => v.lang.startsWith("en"))
  );
}

export default function Samples() {
  const [supported, setSupported] = useState(true);
  const [playing, setPlaying] = useState<string | null>(null);
  const [line, setLine] = useState(-1);
  const run = useRef(0);

  useEffect(() => {
    // Speech is a browser feature, so this can only be known after the page has loaded here.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setSupported("speechSynthesis" in window);
    return () => window.speechSynthesis?.cancel();
  }, []);

  function stop() {
    run.current++;
    window.speechSynthesis.cancel();
    setPlaying(null);
    setLine(-1);
  }

  function listen(s: Sample) {
    stop();
    const mine = ++run.current;
    setPlaying(s.id);
    const voice = pickVoice();
    const sayLine = (i: number) => {
      if (run.current !== mine) return;
      if (i >= s.lines.length) {
        setPlaying(null);
        setLine(-1);
        return;
      }
      setLine(i);
      const u = new SpeechSynthesisUtterance(s.lines[i].said);
      u.lang = voice?.lang ?? "en-NG";
      if (voice) u.voice = voice;
      u.rate = 0.95;
      u.onend = () => sayLine(i + 1);
      u.onerror = () => sayLine(i + 1);
      window.speechSynthesis.speak(u);
    };
    sayLine(0);
  }

  return (
    <>
      {!supported && (
        <p className="note" role="status">
          This browser can’t read aloud, so the lines Magana read are shown under each page instead.
        </p>
      )}
      <div className="samples">
        {(samples as Sample[]).map((s) => {
          const on = playing === s.id;
          return (
            <section key={s.id} className="sample" aria-labelledby={`sample-${s.id}`}>
              <h3 id={`sample-${s.id}`}>{s.title}</h3>
              <figure>
                {/* eslint-disable-next-line @next/next/no-img-element -- a static export: no image optimiser */}
                <img src={`/samples/${s.id}.png`} alt={s.alt} width={s.width} height={s.height} loading="lazy" decoding="async" />
                <figcaption className="note">A test page the Magana team made. What Magana read:</figcaption>
              </figure>
              <ol aria-label={`What Magana read from the ${s.title.toLowerCase()}`}>
                {s.lines.map((l, i) => (
                  <li key={i} data-speaking={on && line === i ? "" : undefined}>
                    <Shown text={l.shown} />
                    {l.warning && <span className="warn">{l.warning}</span>}
                  </li>
                ))}
              </ol>
              {supported && (
                <button
                  type="button"
                  className={on ? "btn btn-outline" : "btn btn-primary"}
                  aria-label={on ? `Stop reading the ${s.title.toLowerCase()}` : `Listen to the ${s.title.toLowerCase()}`}
                  onClick={() => (on ? stop() : listen(s))}
                >
                  <svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                    {on ? <rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor" /> : <path d="M7 4.5v15l12.5-7.5z" fill="currentColor" />}
                  </svg>
                  {on ? "Stop" : "Listen"}
                </button>
              )}
            </section>
          );
        })}
      </div>
    </>
  );
}
