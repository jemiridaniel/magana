"use client";

import { useState } from "react";
import { classes, hasAccounts, periods, progress, pupils, suggestionLabel, type Period } from "@/lib/data";

const mean = (xs: number[]) => (xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : 0);
const GRID = [100, 75, 50, 25, 0];

/** One bar per week. The numbers sit on the bars; the same numbers are in the table view and the text alternative. */
function WeeksChart({ weeks, label }: { weeks: { week: number; value: number }[]; label: string }) {
  const last = weeks[weeks.length - 1]?.week;
  return (
    <div className="chart" role="img" aria-label={label}>
      <div className="chart-grid" aria-hidden="true">
        {GRID.map((g) => (
          <div key={g} className="chart-gridline" style={{ top: `${100 - g}%` }}><span>{g}%</span></div>
        ))}
      </div>
      <div className="chart-bars" aria-hidden="true">
        {weeks.map((w) => (
          <div key={w.week} className="chart-col">
            <div className="chart-plot">
              <span className="chart-value">{w.value}%</span>
              <div className={`chart-bar${w.week === last ? " is-current" : ""}`} style={{ height: `${w.value}%` }} />
            </div>
            <span className="chart-label">Wk {w.week}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function ProgressView() {
  // Classroom-mode classes (under 13) have no accounts and their sessions are never saved, so they have no progress.
  const tracked = classes.filter((c) => hasAccounts(c.mode) && progress[c.id]);
  const untracked = classes.filter((c) => !hasAccounts(c.mode));
  const [classId, setClassId] = useState(tracked[0].id);
  const [period, setPeriod] = useState<Period>("week");
  const [asTable, setAsTable] = useState(false);

  const cls = classes.find((c) => c.id === classId)!;
  const data = progress[classId];
  const roster = pupils.filter((p) => p.classId === classId);
  const stat = (pupilId: string) => data.learners.find((l) => l.pupilId === pupilId);
  const rows = data.learners.map((l) => l[period]);

  const thisWeek = mean(data.learners.map((l) => l.week[1]));
  const weeks = [...data.earlierWeeks, thisWeek].map((value, i) => ({ week: i + 1, value }));
  const first = weeks[0];
  const lastWeek = weeks[weeks.length - 1];

  const unaided = mean(rows.map((r) => r[1]));
  const quiz = mean(rows.map((r) => r[2]));
  const pages = period === "week" ? data.pages[data.pages.length - 1] : data.pages.reduce((a, b) => a + b, 0);
  const periodText = period === "week" ? "this week" : "this term";

  const trend = `Share of reading tasks done without sighted help ${lastWeek.value >= first.value ? "rose" : "fell"} from ${first.value}% to ${lastWeek.value}% over ${weeks.length} weeks.`;
  const chartLabel = `Bar chart: tasks done without sighted help by week. ${weeks.map((w) => `Week ${w.week} ${w.value}%`).join(", ")}.`;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Learner progress</h1>
          <p>How independently your learners are studying, week by week.</p>
        </div>
        <div className="actions">
          <div className="field">
            <label htmlFor="prog-class">Class</label>
            <select id="prog-class" className="select" value={classId} onChange={(e) => setClassId(e.target.value)}>
              {tracked.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="prog-period">Period</label>
            <select id="prog-period" className="select" value={period} onChange={(e) => setPeriod(e.target.value as Period)}>
              {periods.map((p) => <option key={p.id} value={p.id}>{p.label}</option>)}
            </select>
          </div>
        </div>
      </div>

      {untracked.length > 0 && (
        <p className="note">
          {untracked.map((c) => c.name).join(", ")} {untracked.length === 1 ? "is" : "are"} in Classroom mode: sessions are
          teacher-led and never saved, so there is no progress to show.
        </p>
      )}

      <section aria-labelledby="totals-head">
        <h2 id="totals-head" className="visually-hidden">{cls.name}, {periodText}</h2>
        <ul className="stat-grid">
          <li className="stat">
            <span className="stat-label">Tasks done without sighted help</span>
            <span className="stat-num accent">{unaided}%</span>
          </li>
          <li className="stat">
            <span className="stat-label">Pages read by the class</span>
            <span className="stat-num">{pages}</span>
          </li>
          <li className="stat">
            <span className="stat-label">Average quiz score</span>
            <span className="stat-num">{quiz}%</span>
          </li>
        </ul>
      </section>

      <section className="card" aria-labelledby="trend-head">
        <h2 id="trend-head" style={{ marginBottom: 8 }}>Independence over time</h2>
        <p className="note" id="trend-summary">{trend}</p>
        {asTable ? (
          <div className="table-wrap" role="region" aria-label="Independence by week table" tabIndex={0} style={{ marginTop: 16 }}>
            <table>
              <caption className="visually-hidden">Tasks done without sighted help by week, {cls.name}</caption>
              <thead>
                <tr>
                  <th scope="col">Week</th>
                  <th scope="col">Tasks done without sighted help</th>
                </tr>
              </thead>
              <tbody>
                {weeks.map((w) => (
                  <tr key={w.week}>
                    <th scope="row">Week {w.week}{w.week === lastWeek.week ? " (this week)" : ""}</th>
                    <td>{w.value}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <WeeksChart weeks={weeks} label={chartLabel} />
        )}
        <div style={{ marginTop: 16 }}>
            <button type="button" className="btn no-print" aria-pressed={asTable} onClick={() => setAsTable((t) => !t)}>
              Show as table
            </button>
        </div>
      </section>

      <section className="card" aria-labelledby="by-learner-head">
        <div className="card-head">
          <h2 id="by-learner-head">By learner</h2>
          <p className="note">{periods.find((p) => p.id === period)!.label}</p>
        </div>
        <div className="table-wrap" role="region" aria-label="Progress by learner table" tabIndex={0}>
          <table>
            <thead>
              <tr>
                <th scope="col">Learner</th>
                <th scope="col">Reading sessions</th>
                <th scope="col">Done without help</th>
                <th scope="col">Quiz average</th>
                <th scope="col">Suggestion</th>
              </tr>
            </thead>
            <tbody>
              {roster.map((p) => {
                const s = stat(p.id);
                if (!s) {
                  return (
                    <tr key={p.id}>
                      <th scope="row">{p.name}</th>
                      <td colSpan={4} className="note">No progress yet: the account opens once a parent or guardian gives consent.</td>
                    </tr>
                  );
                }
                const [sessions, done, avg] = s[period];
                return (
                  <tr key={p.id}>
                    <th scope="row">{p.name}</th>
                    <td>{sessions}</td>
                    <td>{done}%</td>
                    <td>{avg}%</td>
                    <td>
                      {s.suggestion === "on-track" ? suggestionLabel[s.suggestion] : (
                        <span className="pill pill-check pill-wrap">{suggestionLabel[s.suggestion]}</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="callout" style={{ marginTop: 16 }}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--green-ink)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
          <p>
            You see summaries only, never the pages learners photograph or the questions they ask. Learners can see their own
            progress in the app.
          </p>
        </div>
      </section>
    </>
  );
}
