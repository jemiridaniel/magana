// Teacher-made quizzes. Saved to the Magana backend (/quizzes) when NEXT_PUBLIC_API_URL is
// set; otherwise kept in this browser only, as a preview. The checks mirror the backend's
// quizzes.check(), which has the last word when assigning.
import { isPrimary, maxOptions, MIN_OPTIONS, PRIMARY_WORD_HINT, type LevelId } from "./curriculum";
import { API_URL } from "./api";

export type Lang = "en" | "ha" | "yo" | "ig";
export const languageNames: Record<Lang, string> = { en: "English", ha: "Hausa", yo: "Yorùbá", ig: "Igbo" };

export interface Question {
  id: string;
  question: string;
  options: string[];
  answer: number | null;
  praise: string;
  picture: { name: string; description: string } | null;
  translations: Partial<Record<Lang, { question: string; checked: boolean }>>;
}

export interface QuizDraft {
  title: string;
  class_id: string;
  level: LevelId;
  subject: string;
  languages: Lang[];
  questions: Question[];
}

export interface Quiz extends QuizDraft {
  id: string;
  status: "draft" | "assigned";
  session: string | null;
  updated_at: string;
}

export interface Problem {
  code: string;
  question: number | null; // 1-based
  blocking: boolean;
}

/** Call from event handlers only: the id is random (rendering must stay predictable). */
export const newQuestion = (id = randomId(8)): Question => ({
  id,
  question: "",
  options: ["", ""],
  answer: null,
  praise: "",
  picture: null,
  translations: {},
});

export function randomId(hex: number): string {
  const bytes = new Uint8Array(Math.ceil(hex / 2));
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("").slice(0, hex);
}

export const words = (text: string) => (text.match(/\S+/g) ?? []).length;

export function check(quiz: QuizDraft): Problem[] {
  const out: Problem[] = [];
  if (quiz.questions.length === 0) out.push({ code: "quiz_no_questions", question: null, blocking: true });
  const most = maxOptions(quiz.level);
  const primary = isPrimary(quiz.level);
  quiz.questions.forEach((q, i) => {
    const add = (code: string, blocking = true) => out.push({ code, question: i + 1, blocking });
    if (!q.question.trim()) add("quiz_empty_question");
    if (q.options.length < MIN_OPTIONS) add("quiz_too_few_options");
    if (q.options.length > most) add("quiz_too_many_options");
    if (q.options.some((o) => !o.trim())) add("quiz_empty_option");
    if (q.answer === null || q.answer < 0 || q.answer >= q.options.length) add("quiz_no_right_answer");
    if (q.picture && !q.picture.description.trim()) add("quiz_picture_needs_description");
    if (primary && words(q.question) > PRIMARY_WORD_HINT) add("quiz_question_long", false);
    for (const lang of quiz.languages) {
      const t = q.translations[lang];
      if (lang !== "en" && t && t.question.trim() && !t.checked) add("quiz_translation_unchecked", false);
    }
  });
  return out;
}

export const blocking = (problems: Problem[]) => problems.filter((p) => p.blocking);

/** Rough spoken length: about 2.5 words a second, plus 10 seconds to answer each question. */
export function spokenMinutes(quiz: QuizDraft): number {
  const seconds = quiz.questions.reduce(
    (s, q) => s + (words(q.question) + q.options.reduce((n, o) => n + words(o) + 1, 0)) / 2.5 + 10,
    0,
  );
  return Math.max(1, Math.round(seconds / 60));
}

const LETTERS = ["A", "B", "C", "D"];

/** What the learner app says for a question (app/lib/screens/quiz.dart, English). */
export function spokenQuestion(quiz: QuizDraft, index: number): string {
  const q = quiz.questions[index];
  const letters = LETTERS.slice(0, q.options.length);
  const say = letters.length > 1 ? `${letters.slice(0, -1).join(", ")} or ${letters.at(-1)}` : letters.join("");
  return [
    `Question ${index + 1} of ${quiz.questions.length}`,
    q.question.trim(),
    q.picture?.description.trim() ? `Picture: ${q.picture.description.trim()}` : "",
    ...q.options.map((o, i) => `${LETTERS[i]}, ${o.trim()}.`),
    `Say ${say}`,
  ]
    .filter(Boolean)
    .join(" ");
}

// ---------- saving

const KEY = "magana.portal.quizzes"; // the offline preview only
const teacherHeader: Record<string, string> = process.env.NEXT_PUBLIC_TEACHER_KEY
  ? { "X-Magana-Teacher-Key": process.env.NEXT_PUBLIC_TEACHER_KEY }
  : {};
const apiKeyHeader: Record<string, string> = process.env.NEXT_PUBLIC_API_KEY
  ? { "X-Magana-Key": process.env.NEXT_PUBLIC_API_KEY }
  : {};

export const savesToServer = () => Boolean(API_URL);

export class QuizError extends Error {
  constructor(
    public code: string,
    public problems: Problem[] = [],
  ) {
    super(code);
  }
}

async function call<T>(method: string, path: string, body?: unknown): Promise<T> {
  let r: Response;
  try {
    r = await fetch(`${API_URL}${path}`, {
      method,
      headers: { "Content-Type": "application/json", ...apiKeyHeader, ...teacherHeader },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new QuizError("unreachable");
  }
  const json = await r.json().catch(() => null);
  if (!r.ok) {
    const detail = json?.detail;
    throw new QuizError(typeof detail?.code === "string" ? detail.code : "failed", detail?.problems ?? []);
  }
  return json as T;
}

function local(): Quiz[] {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? "[]");
  } catch {
    return [];
  }
}
function saveLocal(all: Quiz[]) {
  try {
    localStorage.setItem(KEY, JSON.stringify(all));
  } catch {
    // Storage blocked: the quiz stays on screen until the page closes.
  }
}

type WithProblems = { quiz: Quiz; problems: Problem[] };

export async function listQuizzes(): Promise<Quiz[]> {
  if (!savesToServer()) return local();
  return (await call<WithProblems[]>("GET", "/quizzes")).map((x) => x.quiz);
}

export async function getQuiz(id: string): Promise<Quiz> {
  if (!savesToServer()) {
    const q = local().find((x) => x.id === id);
    if (!q) throw new QuizError("quiz_not_found");
    return q;
  }
  return (await call<WithProblems>("GET", `/quizzes/${encodeURIComponent(id)}`)).quiz;
}

export async function saveQuiz(draft: QuizDraft, id?: string): Promise<Quiz> {
  if (!savesToServer()) {
    const all = local();
    const old = all.find((x) => x.id === id);
    const quiz: Quiz = {
      ...draft,
      id: old?.id ?? randomId(12),
      status: old && !blocking(check(draft)).length ? old.status : "draft",
      session: old && !blocking(check(draft)).length ? old.session : null,
      updated_at: new Date().toISOString(),
    };
    saveLocal([quiz, ...all.filter((x) => x.id !== quiz.id)]);
    return quiz;
  }
  const r = id
    ? await call<WithProblems>("PUT", `/quizzes/${encodeURIComponent(id)}`, draft)
    : await call<WithProblems>("POST", "/quizzes", draft);
  return r.quiz;
}

export async function assignQuiz(id: string, session: string): Promise<Quiz> {
  if (!savesToServer()) {
    const all = local();
    const quiz = all.find((x) => x.id === id);
    if (!quiz) throw new QuizError("quiz_not_found");
    const problems = check(quiz);
    if (blocking(problems).length) throw new QuizError("quiz_not_ready", problems);
    const assigned: Quiz = { ...quiz, status: "assigned", session, updated_at: new Date().toISOString() };
    saveLocal([assigned, ...all.filter((x) => x.id !== id)]);
    return assigned;
  }
  return (await call<WithProblems>("POST", `/quizzes/${encodeURIComponent(id)}/assign`, { session })).quiz;
}
