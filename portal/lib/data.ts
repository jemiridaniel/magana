// Mock data for the hackathon portal. Replace with API calls in lib/api.ts.

export type Mode = "Standard" | "Guided" | "Classroom";

export interface SchoolClass {
  id: string;
  name: string;
  mode: Mode; // policy tier: Guided 13–17, Classroom under 13 (teacher-run sessions only)
  seats: number;
}

export const classes: SchoolClass[] = [
  { id: "ss2-sci", name: "SS2 Science", mode: "Guided", seats: 20 },
  { id: "ss3-eng", name: "SS3 English", mode: "Guided", seats: 20 },
  { id: "pri5", name: "Primary 5", mode: "Classroom", seats: 30 },
];

export type Version = "en-audio" | "brf" | "large-print" | "ha-audio" | "yo-audio" | "ig-audio";

export const versions: { id: Version; label: string; defaultOn: boolean }[] = [
  { id: "en-audio", label: "English audio", defaultOn: true },
  { id: "brf", label: "Braille (BRF)", defaultOn: true },
  { id: "large-print", label: "Large print", defaultOn: true },
  { id: "ha-audio", label: "Hausa audio", defaultOn: true },
  { id: "yo-audio", label: "Yorùbá audio", defaultOn: false },
  { id: "ig-audio", label: "Igbo audio", defaultOn: false },
];

export const versionLabel = (v: Version) => versions.find((x) => x.id === v)?.label ?? v;

export type UploadStatus =
  | { kind: "ready" }
  | { kind: "check"; detail: string } // parts Magana was unsure about, e.g. "Check 2 formulas"
  | { kind: "processing" };

export interface Upload {
  id: string;
  name: string;
  classId: string;
  versions: Version[];
  status: UploadStatus;
}

export const recentUploads: Upload[] = [
  {
    id: "u1",
    name: "Food tests — practical notes.pdf",
    classId: "ss2-sci",
    versions: ["en-audio", "brf", "large-print", "ha-audio"],
    status: { kind: "ready" },
  },
  {
    id: "u2",
    name: "Simple equations test.docx",
    classId: "ss2-sci",
    versions: ["en-audio", "brf", "large-print"],
    status: { kind: "check", detail: "Check 2 formulas" },
  },
  {
    id: "u3",
    name: "Comprehension passage p. 42.jpg",
    classId: "ss3-eng",
    versions: ["en-audio", "brf", "yo-audio"],
    status: { kind: "processing" },
  },
];

export type Mark = "present" | "late" | "absent" | "excused";

export const marks: { id: Mark; label: string; key: string }[] = [
  { id: "present", label: "Present", key: "p" },
  { id: "late", label: "Late", key: "l" },
  { id: "absent", label: "Absent", key: "a" },
  { id: "excused", label: "Excused", key: "e" },
];

export interface Learner {
  id: string;
  name: string;
  mark: Mark;
  usedMagana: boolean; // filled in automatically for remote sessions
  termAttended: number;
  termSessions: number;
}

export interface Session {
  id: string;
  classId: string;
  label: string;
}

export const sessions: Session[] = [
  { id: "s-2026-11-18", classId: "ss2-sci", label: "Tue 18 Nov 2026 · Biology · Food tests" },
  { id: "s-2026-11-13", classId: "ss2-sci", label: "Thu 13 Nov 2026 · Chemistry · Separating mixtures" },
];

const l = (id: string, name: string, mark: Mark, usedMagana: boolean, termAttended: number, termSessions = 24): Learner => ({
  id, name, mark, usedMagana, termAttended, termSessions,
});

export const register: Learner[] = [
  l("1", "Abdullahi Musa", "present", true, 23),
  l("2", "Adaeze Okafor", "present", true, 22),
  l("3", "Aisha Bello", "late", true, 20),
  l("4", "Chinedu Eze", "present", false, 21),
  l("5", "Emeka Nwosu", "present", true, 24),
  l("6", "Fatima Usman", "present", true, 22),
  l("7", "Funmilayo Adeyemi", "excused", false, 19),
  l("8", "Ibrahim Sani", "present", true, 21),
  l("9", "Kelechi Obi", "absent", false, 14),
  l("10", "Maryam Lawal", "present", true, 23),
  l("11", "Ngozi Chukwu", "present", true, 22),
  l("12", "Oluwaseun Ajayi", "late", false, 20),
  l("13", "Samuel Akpan", "present", true, 21),
  l("14", "Tolulope Ogunleye", "present", true, 22),
  l("15", "Uche Ibe", "present", false, 20),
  l("16", "Yetunde Bakare", "present", true, 21),
  l("17", "Zainab Garba", "present", true, 23),
  l("18", "Babatunde Olatunji", "present", true, 22),
];

export const FOLLOW_UP_BELOW = 0.65;
