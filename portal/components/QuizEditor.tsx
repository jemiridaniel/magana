"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState, useSyncExternalStore, type ChangeEvent } from "react";
import { isPrimary, level as levelOf, maxOptions, PRIMARY_WORD_HINT, subjectNames, subjectsFor, type LevelId } from "@/lib/curriculum";
import { portal, type ClassInfo } from "@/lib/portal";
import { messageFor } from "@/lib/messages";
import {
  assignQuiz,
  blocking,
  check,
  getQuiz,
  languageNames,
  newQuestion,
  QuizError,
  saveQuiz,
  savesToServer,
  spokenMinutes,
  spokenQuestion,
  words,
  type Lang,
  type Question,
  type QuizDraft,
} from "@/lib/quizzes";
import { canSpeak, speak } from "@/lib/speech";

const LETTERS = ["A", "B", "C", "D"];

// "Questions read in": English always, with at most one Nigerian language beside it.
const languageChoices: { id: string; label: string; langs: Lang[] }[] = [
  { id: "en", label: "English", langs: ["en"] },
  { id: "ha", label: "Hausa and English", langs: ["en", "ha"] },
  { id: "yo", label: "Yorùbá and English", langs: ["en", "yo"] },
  { id: "ig", label: "Igbo and English", langs: ["en", "ig"] },
];

const noSubscribe = () => () => {};

const today = () => new Date().toISOString().slice(0, 10);
/** "2026-10-30" → "Thu 30 Oct 2026": the session's name in the portal and on the code. */
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const sessionName = (day: string) => {
  const d = new Date(`${day}T12:00:00`);
  return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
};

function blankQuiz(): QuizDraft {
  return {
    title: "",
    class_id: "",
    level: "p5",
    subject: subjectsFor("p5")[0],
    languages: ["en"],
    questions: [newQuestion("q1")], // a fixed id: this runs while rendering
  };
}

function Tick() {
  return <span aria-hidden="true"> ✓</span>;
}

export default function QuizEditor() {
  const [quiz, setQuiz] = useState<QuizDraft>(blankQuiz);
  const [id, setId] = useState<string | undefined>();
  const [status, setStatus] = useState<"draft" | "assigned">("draft");
  const [code, setCode] = useState<string | null>(null);
  const [index, setIndex] = useState(0);
  const [classes, setClasses] = useState<ClassInfo[]>([]);
  const [sessionDay, setSessionDay] = useState(today());
  const [assignedTo, setAssignedTo] = useState<string | null>(null);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  // Known only in the browser: false while rendering on the server.
  const speechOk = useSyncExternalStore(noSubscribe, canSpeak, () => false);
  const checksHead = useRef<HTMLHeadingElement>(null);
  const questionHead = useRef<HTMLHeadingElement>(null);

  // Editing an existing quiz: /quizzes/new?id=…
  useEffect(() => {
    const qid = new URLSearchParams(window.location.search).get("id");
    if (!qid) return;
    getQuiz(qid)
      .then((q) => {
        setQuiz({ title: q.title, class_id: q.class_id, level: q.level, subject: q.subject, languages: q.languages, questions: q.questions });
        setId(q.id);
        setStatus(q.status);
        setCode(q.session_code);
        setAssignedTo(q.session);
      })
      .catch((e) => setMessage({ text: messageFor(e instanceof QuizError ? e.code : "failed"), error: true }));
  }, []);

  // Your classes (My classes); a new quiz starts on the first one.
  useEffect(() => {
    portal.classes().then((cs) => {
      setClasses(cs);
      setQuiz((old) => {
        if (old.class_id || !cs.length) return old;
        const c = cs[0];
        const subjects = subjectsFor(c.level as LevelId);
        return { ...old, class_id: c.id, level: c.level as LevelId, subject: subjects.includes(old.subject) ? old.subject : subjects[0] };
      });
    }).catch(() => setClasses([]));
  }, []);

  const cls = classes.find((c) => c.id === quiz.class_id);
  const primary = isPrimary(quiz.level);
  const most = maxOptions(quiz.level);
  const problems = useMemo(() => check(quiz), [quiz]);
  const q = quiz.questions[index];
  const second = quiz.languages.find((l) => l !== "en");
  const sessionLabel = sessionName(sessionDay);

  const update = (change: Partial<QuizDraft>) => {
    setQuiz((old) => ({ ...old, ...change }));
    setMessage(null);
  };
  const updateQuestion = (change: Partial<Question>) =>
    update({ questions: quiz.questions.map((x, i) => (i === index ? { ...x, ...change } : x)) });

  function chooseClass(classId: string) {
    const c = classes.find((x) => x.id === classId)!;
    const subjects = subjectsFor(c.level as LevelId);
    update({
      class_id: c.id,
      level: c.level as LevelId,
      subject: subjects.includes(quiz.subject) ? quiz.subject : subjects[0],
    });
  }

  function setOption(i: number, text: string) {
    updateQuestion({ options: q.options.map((o, j) => (j === i ? text : o)) });
  }

  function removeOption(i: number) {
    const answer = q.answer === null ? null : q.answer === i ? null : q.answer > i ? q.answer - 1 : q.answer;
    updateQuestion({ options: q.options.filter((_, j) => j !== i), answer });
  }

  function goTo(i: number) {
    setIndex(i);
    requestAnimationFrame(() => questionHead.current?.focus());
  }

  function addQuestion() {
    update({ questions: [...quiz.questions, newQuestion()] });
    goTo(quiz.questions.length);
  }

  function choosePicture(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) updateQuestion({ picture: { name: file.name, description: q.picture?.description ?? "" } });
  }

  async function save(): Promise<string | undefined> {
    setBusy(true);
    try {
      const saved = await saveQuiz(quiz, id);
      setId(saved.id);
      setStatus(saved.status);
      setCode(saved.session_code);
      if (!id) window.history.replaceState(null, "", `${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}/quizzes/new/?id=${saved.id}`);
      setMessage({
        text: savesToServer()
          ? "Draft saved."
          : "Draft saved in this browser only. Connect the portal to the Magana server to share it with learners.",
      });
      return saved.id;
    } catch (e) {
      setMessage({ text: messageFor(e instanceof QuizError ? e.code : "failed"), error: true });
      return undefined;
    } finally {
      setBusy(false);
    }
  }

  async function assign() {
    if (blocking(problems).length) {
      setMessage({ text: messageFor("quiz_not_ready"), error: true });
      checksHead.current?.focus();
      return;
    }
    const saved = await save();
    if (!saved) return;
    setBusy(true);
    try {
      const assigned = await assignQuiz(saved, sessionLabel);
      setStatus(assigned.status);
      setCode(assigned.session_code);
      setAssignedTo(sessionLabel);
      setMessage({
        text: `Assigned to ${cls?.name ?? "the class"} for ${sessionLabel}. Session code: ${assigned.session_code}.${
          savesToServer() ? "" : " (Preview: saved in this browser only.)"
        }`,
      });
    } catch (e) {
      setMessage({ text: messageFor(e instanceof QuizError ? e.code : "failed"), error: true });
      if (e instanceof QuizError && e.code === "quiz_not_ready") checksHead.current?.focus();
    } finally {
      setBusy(false);
    }
  }

  const questionProblems = (n: number) => problems.filter((p) => p.question === n);
  const has = (code: string) => problems.some((p) => p.code === code);
  const where = (code: string) =>
    problems
      .filter((p) => p.code === code && p.question)
      .map((p) => p.question)
      .join(", ");
  const wordCount = words(q.question);

  const checks: { ok: boolean; okText: string; problem: string; warn?: boolean }[] = [
    {
      ok: !has("quiz_no_questions") && !has("quiz_empty_question") && !has("quiz_empty_option"),
      okText: "Every question and option is written",
      problem: has("quiz_no_questions")
        ? messageFor("quiz_no_questions")
        : `Something is empty in question ${[...new Set([...where("quiz_empty_question").split(", "), ...where("quiz_empty_option").split(", ")].filter(Boolean))].join(", ")}`,
    },
    {
      ok: !has("quiz_no_right_answer"),
      okText: "Every question has one right answer",
      problem: `No right answer marked in question ${where("quiz_no_right_answer")}`,
    },
    {
      ok: !has("quiz_too_many_options") && !has("quiz_too_few_options"),
      okText: `Every question has 2 to ${most} options`,
      problem: `Question ${[where("quiz_too_many_options"), where("quiz_too_few_options")].filter(Boolean).join(", ")} needs 2 to ${most} options`,
    },
    {
      ok: !has("quiz_picture_needs_description"),
      okText: "No pictures without a description",
      problem: `Describe the picture in question ${where("quiz_picture_needs_description")}`,
    },
    ...(primary
      ? [
          {
            ok: !has("quiz_question_long"),
            okText: "Questions are short enough to hear",
            problem: `Question ${where("quiz_question_long")} is over ${PRIMARY_WORD_HINT} words`,
            warn: true,
          },
        ]
      : []),
    ...(second
      ? [
          {
            ok: !has("quiz_translation_unchecked"),
            okText: `${languageNames[second]} versions checked`,
            problem: `${languageNames[second]} version of question ${where("quiz_translation_unchecked")} not yet checked`,
            warn: true,
          },
        ]
      : []),
  ];
  const canAssign = blocking(problems).length === 0;
  const written = quiz.questions.filter((x, i) => !questionProblems(i + 1).some((p) => p.blocking)).length;

  return (
    <>
      <header className="page-head">
        <div>
          <Link href="/quizzes" className="back-link">‹ All quizzes</Link>
          <h1>{id ? "Edit quiz" : "Create a quiz"}</h1>
          <p>Write questions your learners hear and answer by voice or touch. Magana reads every question and option aloud.</p>
        </div>
        <div className="actions">
          <button type="button" className="btn" onClick={save} disabled={busy}>Save draft</button>
          <button type="button" className="btn btn-primary" onClick={assign} disabled={busy}>Assign to class</button>
        </div>
      </header>
      <p role="status" className={`status-msg${message?.error ? " status-error" : ""}`}>{message?.text ?? ""}</p>

      <section className="card form-grid" aria-labelledby="setup-h">
        <h2 id="setup-h">1 · Quiz details</h2>
        <div className="form-row">
          <div className="field">
            <label htmlFor="quiz-title">Quiz title</label>
            <input id="quiz-title" className="input" value={quiz.title} maxLength={120} onChange={(e) => update({ title: e.target.value })} placeholder="For example: Parts of a plant" />
          </div>
          <div className="field">
            <label htmlFor="quiz-class">Class</label>
            <select id="quiz-class" className="select" value={quiz.class_id} onChange={(e) => chooseClass(e.target.value)}>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="quiz-subject">Subject</label>
            <select id="quiz-subject" className="select" value={quiz.subject} onChange={(e) => update({ subject: e.target.value })}>
              {subjectsFor(quiz.level).map((s) => (
                <option key={s} value={s}>{subjectNames[s]}</option>
              ))}
            </select>
          </div>
        </div>
        <div className="form-row">
          <div className="field">
            <label htmlFor="quiz-langs">Questions read in</label>
            <select
              id="quiz-langs"
              className="select"
              aria-describedby="quiz-langs-hint"
              value={second ?? "en"}
              onChange={(e) => update({ languages: languageChoices.find((c) => c.id === e.target.value)!.langs })}
            >
              {languageChoices.map((c) => (
                <option key={c.id} value={c.id}>{c.label}</option>
              ))}
            </select>
            <span id="quiz-langs-hint" className="hint">Learners hear their own language when a teacher has checked that version; otherwise English.</span>
          </div>
          <div className="field">
            <span className="field-label" id="style-label">Answer style</span>
            <p className="field-fixed" aria-labelledby="style-label" aria-describedby="style-hint">
              {primary ? "2 or 3 options" : "2 to 4 options"}
            </p>
            <span id="style-hint" className="hint">
              {primary ? "Set by the class level. Primary classes use short choices." : "Set by the class level."}
            </span>
          </div>
        </div>
        {cls?.mode === "classroom" && (
          <div className="callout" role="note">
            <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" strokeWidth="2" /><path d="M12 10.5v6M12 7v.5" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /></svg>
            <p>
              <strong>{cls.name} is a Classroom mode class (under 13).</strong> This quiz only runs in a session you start. Magana uses a slower voice, short sentences and two or three options for these learners.
            </p>
          </div>
        )}
        {primary && cls?.mode !== "classroom" && (
          <div className="callout" role="note">
            <p><strong>{levelOf(quiz.level).name} is a primary class.</strong> Magana uses a slower voice, short sentences and two or three options.</p>
          </div>
        )}
      </section>

      <div className="quiz-layout">
        <section className="card form-grid" aria-labelledby="q-h">
          <div className="card-head">
            <h2 id="q-h" ref={questionHead} tabIndex={-1}>2 · Question {index + 1} of {quiz.questions.length}</h2>
            {speechOk && (
              <button type="button" className="btn" onClick={() => speak(spokenQuestion(quiz, index), { primary })}>
                <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9v6h4l5 4V5L8 9H4z" fill="currentColor" /><path d="M16 8.5a5 5 0 0 1 0 7M18.5 6a8.5 8.5 0 0 1 0 12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
                Listen as a learner
              </button>
            )}
          </div>
          <div className="field">
            <label htmlFor="q-text">Question</label>
            <textarea id="q-text" className="input textarea" rows={3} value={q.question} maxLength={500} aria-describedby="q-hint" onChange={(e) => updateQuestion({ question: e.target.value })} />
            <span id="q-hint" className={`hint${primary && wordCount > PRIMARY_WORD_HINT ? " hint-warn" : ""}`}>
              {primary
                ? `Keep it short and spoken: ${PRIMARY_WORD_HINT} words or fewer for primary classes. This one has ${wordCount}.`
                : `Keep it short and spoken. This one has ${wordCount} words.`}
            </span>
          </div>
          {second && (
            <div className="field">
              <label htmlFor="q-translation">
                {languageNames[second]} version <span className="hint">(optional, checked by a {languageNames[second]}-speaking teacher)</span>
              </label>
              <textarea
                id="q-translation"
                className="input textarea"
                rows={2}
                lang={second}
                value={q.translations[second]?.question ?? ""}
                maxLength={500}
                onChange={(e) =>
                  updateQuestion({ translations: { ...q.translations, [second]: { question: e.target.value, checked: false } } })
                }
              />
              {q.translations[second]?.question.trim() && (
                <div className="translation-check">
                  <span className={`pill ${q.translations[second]?.checked ? "pill-ready" : "pill-check"}`}>
                    {q.translations[second]?.checked ? "Checked" : "Not yet checked"}
                  </span>
                  <label className="check check-inline">
                    <input
                      type="checkbox"
                      checked={q.translations[second]?.checked ?? false}
                      onChange={(e) =>
                        updateQuestion({
                          translations: { ...q.translations, [second]: { question: q.translations[second]!.question, checked: e.target.checked } },
                        })
                      }
                    />
                    A {languageNames[second]}-speaking teacher checked it
                  </label>
                </div>
              )}
            </div>
          )}
          <fieldset className="options">
            <legend>
              Options <span className="hint">· learners say {LETTERS.slice(0, q.options.length).join(", ").replace(/, ([A-D])$/, " or $1")}, or tap</span>
            </legend>
            {q.options.map((o, i) => (
              <div key={i} role="group" aria-label={`Option ${LETTERS[i]}`} className={`option-row${q.answer === i ? " is-right" : ""}`}>
                <span className="option-letter" aria-hidden="true">{LETTERS[i]}</span>
                <input className="input option-input" aria-label={`Option ${LETTERS[i]}`} value={o} maxLength={200} onChange={(e) => setOption(i, e.target.value)} />
                {q.answer === i ? (
                  <span className="pill pill-ready right-pill">
                    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12.5l5 5L20 6.5" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" /></svg>
                    Right answer
                  </span>
                ) : (
                  <button type="button" className="btn btn-small" aria-label={`Mark as right: option ${LETTERS[i]}`} onClick={() => updateQuestion({ answer: i })}>
                    Mark as right
                  </button>
                )}
                <button type="button" className="btn btn-icon" aria-label={`Remove option ${LETTERS[i]}`} onClick={() => removeOption(i)}>
                  <span aria-hidden="true">×</span>
                </button>
              </div>
            ))}
          </fieldset>
          <button
            type="button"
            className="btn btn-dashed"
            disabled={q.options.length >= most}
            onClick={() => updateQuestion({ options: [...q.options, ""] })}
          >
            {q.options.length >= most ? `+ Add option · ${most} is the most for ${cls?.name ?? "this class"}` : "+ Add option"}
          </button>
          <div className="form-row">
            <div className="field">
              <label htmlFor="q-praise">Say this after a right answer</label>
              <input id="q-praise" className="input" value={q.praise} maxLength={300} onChange={(e) => updateQuestion({ praise: e.target.value })} placeholder="For example: Well done! Leaves make food using sunlight." />
            </div>
            <div className="field">
              {q.picture ? (
                <>
                  <span className="field-label">Picture or diagram</span>
                  <p className="field-fixed">{q.picture.name}</p>
                  <label htmlFor="q-picture-desc">Describe the picture in words (required)</label>
                  <textarea
                    id="q-picture-desc"
                    className="input textarea"
                    rows={2}
                    aria-describedby="q-picture-hint"
                    aria-invalid={!q.picture.description.trim()}
                    value={q.picture.description}
                    maxLength={600}
                    onChange={(e) => updateQuestion({ picture: { ...q.picture!, description: e.target.value } })}
                  />
                  <span id="q-picture-hint" className="hint">Magana reads the description. The picture itself isn&rsquo;t sent to learners yet.</span>
                  <button type="button" className="btn" onClick={() => updateQuestion({ picture: null })}>Remove picture</button>
                </>
              ) : (
                <>
                  <label htmlFor="q-picture">Picture or diagram?</label>
                  <input id="q-picture" className="input file-input" type="file" accept="image/*" aria-describedby="q-picture-none" onChange={choosePicture} />
                  <span id="q-picture-none" className="hint">If you add one, you must describe it in words. Magana reads the description.</span>
                </>
              )}
            </div>
          </div>
          <div className="actions question-nav">
            {index > 0 ? (
              <button type="button" className="btn" onClick={() => goTo(index - 1)}>‹ Question {index}</button>
            ) : (
              <span />
            )}
            {index + 1 < quiz.questions.length ? (
              <button type="button" className="btn btn-dark" onClick={() => goTo(index + 1)}>Question {index + 2} ›</button>
            ) : (
              <button type="button" className="btn btn-dark" onClick={addQuestion}>+ Add question {quiz.questions.length + 1}</button>
            )}
          </div>
        </section>

        <aside className="quiz-aside" aria-label="Quiz overview">
          <section className="card" aria-labelledby="list-h">
            <h2 id="list-h">Questions</h2>
            <ol className="q-list">
              {quiz.questions.map((x, i) => {
                const broken = questionProblems(i + 1).some((p) => p.blocking);
                const state = i === index ? "Editing" : broken ? "Needs work" : "Ready";
                return (
                  <li key={x.id}>
                    <button type="button" className="q-link" aria-current={i === index ? "step" : undefined} onClick={() => goTo(i)}>
                      <span className="q-num">{i + 1}</span>
                      <span className="q-text">{x.question.trim() || "(not written yet)"}</span>
                      <span className={`pill ${state === "Ready" ? "pill-ready" : "pill-check"}`}>{state}</span>
                    </button>
                  </li>
                );
              })}
            </ol>
            <p className="note">
              {written} of {quiz.questions.length} questions written · about {spokenMinutes(quiz)} minute{spokenMinutes(quiz) === 1 ? "" : "s"} when spoken
            </p>
          </section>
          <section className={`card checks-card${canAssign ? " is-ready" : ""}`} aria-labelledby="check-h">
            <h2 id="check-h" ref={checksHead} tabIndex={-1}>Before you assign</h2>
            <ul className="check-list">
              {checks.map((c) => (
                <li key={c.okText} className={c.ok ? "" : c.warn ? "check-warn" : "check-block"}>
                  {c.ok ? (
                    <>
                      {c.okText}
                      <Tick />
                    </>
                  ) : (
                    <strong>{c.warn ? "" : "Blocks assigning: "}{c.problem}</strong>
                  )}
                </li>
              ))}
            </ul>
          </section>
          <section className="card form-grid" aria-labelledby="assign-h">
            <h2 id="assign-h">Assign</h2>
            {cls ? (
              <div className="field">
                <label htmlFor="quiz-session">Class session (date)</label>
                <input id="quiz-session" type="date" className="input" value={sessionDay} min={today()}
                       onChange={(e) => setSessionDay(e.target.value || today())} aria-describedby="quiz-session-hint" />
                <span id="quiz-session-hint" className="hint">Quizzes for the same class and day share one session code.</span>
              </div>
            ) : (
              <p className="note">Add a class in My classes first: a quiz belongs to one of your classes.</p>
            )}
            {assignedTo && status === "assigned" && <p className="note">Assigned for {assignedTo}.</p>}
            {status === "assigned" && code && (
              <div className="session-code-box">
                <p>
                  <strong>Assigned.</strong> Session code: <strong className="session-code">{code}</strong>
                </p>
                <p className="note">
                  Learners only get this quiz inside your session: on each learner&rsquo;s phone, open Practice quiz → &ldquo;Teacher: open your class session&rdquo; and type the code. Learners on their own only get Magana&rsquo;s sample questions.
                </p>
              </div>
            )}
            <p className="note">Scores go to Learner progress. Marks are never taken off because Magana misheard a spoken answer.</p>
          </section>
        </aside>
      </div>
    </>
  );
}
