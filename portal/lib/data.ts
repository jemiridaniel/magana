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

const ss2Science: Learner[] = [
  l("1", "Abdullahi Musa", "present", true, 23),
  l("3", "Amina Bello", "late", true, 20),
  l("18", "Babatunde Olatunji", "present", true, 22),
  l("2", "Chiamaka Okafor", "present", false, 22), // account locked until consent, so never "used Magana"
  l("4", "Chinedu Eze", "present", false, 21),
  l("5", "Emeka Nwosu", "present", true, 24),
  l("6", "Fatima Usman", "present", true, 22),
  l("8", "Ibrahim Sani", "present", true, 21),
  l("9", "Kelechi Obi", "absent", false, 14),
  l("10", "Maryam Lawal", "present", true, 23),
  l("11", "Ngozi Chukwu", "present", true, 22),
  l("12", "Oluwaseun Ajayi", "late", false, 20),
  l("13", "Samuel Akpan", "present", true, 21),
  l("7", "Tobi Adeyemi", "excused", false, 19),
  l("14", "Tolulope Ogunleye", "present", true, 22),
  l("15", "Uche Ibe", "present", false, 20),
  l("16", "Yetunde Bakare", "present", true, 21),
  l("17", "Zainab Garba", "present", true, 23),
];

/** Each class's register for its current session. Classes with no sessions yet have no entry. */
export const registers: Record<string, Learner[]> = { "ss2-sci": ss2Science };

export const FOLLOW_UP_BELOW = 0.65;

// ---------- classes, consent and progress (no backend yet: sample data only)

export const modeInfo: Record<Mode, { label: string; ages: string }> = {
  Standard: { label: "Standard mode", ages: "18+" },
  Guided: { label: "Guided mode", ages: "13–17" },
  Classroom: { label: "Classroom mode", ages: "under 13" },
};

/** Under-18 tiers need a guardian's consent before a learner's account opens. Classroom (under 13) has no accounts. */
export const needsConsent = (mode: Mode) => mode === "Guided";
export const hasAccounts = (mode: Mode) => mode !== "Classroom";

export type Format = "Audio" | "Braille" | "Large print";
export const formats: Format[] = ["Audio", "Braille", "Large print"];
export type Language = "English" | "Hausa" | "Yorùbá" | "Igbo";
export const languages: Language[] = ["English", "Hausa", "Yorùbá", "Igbo"];

export type ConsentStatus = "received" | "pending" | "withdrawn";
export const consentLabel: Record<ConsentStatus, string> = { received: "Received", pending: "Pending", withdrawn: "Withdrawn" };

/** What a class roster stores — only what is needed: name, class, preferred formats and language. */
export interface Pupil {
  id: string;
  classId: string;
  name: string;
  formats: Format[];
  language: Language;
}

/** A guardian's consent record. Kept in the portal; the app only carries the consent flag. */
export interface ConsentRecord {
  pupilId: string;
  learner: string;
  classId: string;
  guardian: string;
  covers: string[];
  status: ConsentStatus;
  via: "SMS link" | "WhatsApp message to guardian" | "Printed form";
  guardianLanguage: Language;
  date: string; // received, requested or withdrawn on
}

// ids 1–18 match the SS2 Science register above.
const ss2: [string, string, Format[], Language, string, ConsentStatus, string[], string][] = [
  ["1", "Abdullahi Musa", ["Audio", "Braille"], "Hausa", "Malam Musa Abdullahi", "received", ["Account"], "8 Sep 2026"],
  ["3", "Amina Bello", ["Audio", "Braille"], "Hausa", "Hajiya Hadiza Bello", "received", ["Account", "User testing"], "8 Sep 2026"],
  ["18", "Babatunde Olatunji", ["Braille"], "Yorùbá", "Mr Kunle Olatunji", "received", ["Account"], "9 Sep 2026"],
  ["2", "Chiamaka Okafor", ["Large print", "Audio"], "English", "Mr Chukwudi Okafor", "pending", ["Account"], "10 Nov 2026"],
  ["4", "Chinedu Eze", ["Braille"], "Igbo", "Mrs Nkiru Eze", "received", ["Account"], "9 Sep 2026"],
  ["5", "Emeka Nwosu", ["Audio"], "Igbo", "Mr Obinna Nwosu", "received", ["Account", "User testing"], "10 Sep 2026"],
  ["6", "Fatima Usman", ["Audio", "Large print"], "Hausa", "Hajiya Zainab Usman", "received", ["Account"], "10 Sep 2026"],
  ["8", "Ibrahim Sani", ["Braille", "Audio"], "Hausa", "Malam Sani Bala", "received", ["Account"], "11 Sep 2026"],
  ["9", "Kelechi Obi", ["Audio"], "English", "Mrs Ada Obi", "received", ["Account"], "12 Sep 2026"],
  ["10", "Maryam Lawal", ["Large print"], "Hausa", "Malam Lawal Idris", "received", ["Account"], "12 Sep 2026"],
  ["11", "Ngozi Chukwu", ["Audio", "Braille"], "Igbo", "Mrs Uju Chukwu", "received", ["Account", "User testing"], "15 Sep 2026"],
  ["12", "Oluwaseun Ajayi", ["Audio"], "Yorùbá", "Mrs Folake Ajayi", "received", ["Account"], "15 Sep 2026"],
  ["13", "Samuel Akpan", ["Braille"], "English", "Mr Edet Akpan", "received", ["Account"], "16 Sep 2026"],
  ["7", "Tobi Adeyemi", ["Audio"], "Yorùbá", "Mrs Bisi Adeyemi", "received", ["Account"], "16 Sep 2026"],
  ["14", "Tolulope Ogunleye", ["Large print", "Audio"], "Yorùbá", "Mr Segun Ogunleye", "received", ["Account"], "17 Sep 2026"],
  ["15", "Uche Ibe", ["Audio"], "Igbo", "Mrs Chioma Ibe", "pending", ["Account"], "12 Nov 2026"],
  ["16", "Yetunde Bakare", ["Audio", "Braille"], "Yorùbá", "Mrs Ronke Bakare", "received", ["Account"], "18 Sep 2026"],
  ["17", "Zainab Garba", ["Audio"], "Hausa", "Malam Garba Umar", "received", ["Account"], "18 Sep 2026"],
];

const ss3: [string, string, Format[], Language, string, ConsentStatus, string[], string][] = [
  ["e1", "Blessing Etim", ["Audio"], "English", "Mrs Arit Etim", "received", ["Account"], "8 Sep 2026"],
  ["e2", "Chidi Okeke", ["Braille", "Audio"], "Igbo", "Mr Ikenna Okeke", "received", ["Account"], "8 Sep 2026"],
  ["e3", "Damilola Fashola", ["Large print"], "Yorùbá", "Mrs Yemi Fashola", "received", ["Account", "User testing"], "9 Sep 2026"],
  ["e4", "Esther Danjuma", ["Audio", "Braille"], "Hausa", "Mr Yakubu Danjuma", "received", ["Account"], "9 Sep 2026"],
  ["e5", "Femi Oladipo", ["Audio"], "Yorùbá", "Mr Tunde Oladipo", "received", ["Account"], "10 Sep 2026"],
  ["e6", "Grace Nnamdi", ["Large print", "Audio"], "English", "Mrs Ngozi Nnamdi", "received", ["Account"], "10 Sep 2026"],
  ["e7", "Halima Yusuf", ["Audio"], "Hausa", "Hajiya Amina Yusuf", "received", ["Account"], "11 Sep 2026"],
  ["e8", "Ifeoma Nwachukwu", ["Braille"], "Igbo", "Mrs Obiageli Nwachukwu", "received", ["Account"], "11 Sep 2026"],
  ["e9", "Joseph Ayuba", ["Audio", "Large print"], "English", "Mr Daniel Ayuba", "received", ["Account"], "12 Sep 2026"],
  ["e10", "Khadija Abubakar", ["Audio"], "Hausa", "Malam Abubakar Sadiq", "received", ["Account"], "12 Sep 2026"],
  ["e11", "Musa Bala", ["Braille", "Audio"], "Hausa", "Malam Bala Haruna", "received", ["Account"], "15 Sep 2026"],
  ["e12", "Nkechi Ugwu", ["Audio"], "Igbo", "Mrs Ebere Ugwu", "received", ["Account"], "15 Sep 2026"],
];

const toPupil = (classId: string) => ([id, name, f, lang]: (typeof ss2)[number]): Pupil => ({ id, classId, name, formats: f, language: lang });
const toRecord = (classId: string) => ([id, name, , lang, guardian, status, covers, date]: (typeof ss2)[number]): ConsentRecord => ({
  pupilId: id, learner: name, classId, guardian, covers, status, date,
  via: status === "pending" ? "SMS link" : "WhatsApp message to guardian",
  guardianLanguage: lang,
});

export const pupils: Pupil[] = [...ss2.map(toPupil("ss2-sci")), ...ss3.map(toPupil("ss3-eng"))];

export const consentRecords: ConsentRecord[] = [
  ...ss2.map(toRecord("ss2-sci")),
  ...ss3.map(toRecord("ss3-eng")),
  // Withdrawn: the account is closed and the learner's data deleted, so they are on no roster. Only this record stays.
  {
    pupilId: "w1", learner: "Ibrahim Musa", classId: "ss3-eng", guardian: "Malam Musa Ibrahim", covers: ["Account"],
    status: "withdrawn", via: "Printed form", guardianLanguage: "Hausa", date: "3 Nov 2026",
  },
];

// ---------- progress (summaries only: never the pages learners photograph or the questions they ask)

export type Period = "week" | "term";
export const periods: { id: Period; label: string }[] = [
  { id: "week", label: "This week" },
  { id: "term", label: "This term (6 weeks)" },
];

export type Suggestion = "on-track" | "camera-tips" | "check-in";
export const suggestionLabel: Record<Suggestion, string> = {
  "on-track": "On track",
  "camera-tips": "Many unclear photos — show camera tips",
  "check-in": "Few reading sessions — check in with them",
};

/** [reading sessions, % of tasks done without sighted help, quiz average %]. */
type Stat = [number, number, number];
export interface PupilProgress {
  pupilId: string;
  week: Stat;
  term: Stat;
  suggestion: Suggestion;
}

export interface ClassProgress {
  /** Weeks 1–5 of the class-wide share of tasks done without help; week 6 is this week, worked out from the learners. */
  earlierWeeks: number[];
  /** Pages read by the class in each of the six weeks. */
  pages: number[];
  learners: PupilProgress[];
}

const pp = (pupilId: string, week: Stat, term: Stat, suggestion: Suggestion = "on-track"): PupilProgress => ({ pupilId, week, term, suggestion });

/** Only learners with an open account have progress. Locked accounts (consent pending) have none. */
export const progress: Record<string, ClassProgress> = {
  "ss2-sci": {
    earlierWeeks: [38, 47, 55, 61, 66],
    pages: [181, 214, 239, 268, 291, 312],
    learners: [
      pp("1", [13, 78, 74], [64, 61, 70]),
      pp("3", [14, 82, 76], [71, 66, 72]),
      pp("18", [12, 76, 79], [60, 58, 74]),
      pp("4", [10, 70, 72], [52, 55, 68]),
      pp("5", [15, 85, 84], [78, 70, 80]),
      pp("6", [12, 72, 70], [61, 57, 67]),
      pp("8", [11, 68, 71], [55, 52, 69]),
      pp("9", [4, 45, 58], [27, 36, 55], "camera-tips"),
      pp("10", [13, 74, 75], [66, 60, 71]),
      pp("11", [14, 80, 78], [69, 64, 75]),
      pp("12", [5, 52, 61], [31, 41, 60], "check-in"),
      pp("13", [12, 73, 69], [58, 59, 66]),
      pp("7", [11, 74, 81], [57, 60, 77]),
      pp("14", [10, 66, 70], [53, 51, 68]),
      pp("16", [12, 71, 66], [62, 56, 65]),
      pp("17", [13, 70, 68], [64, 55, 66]),
    ],
  },
  "ss3-eng": {
    earlierWeeks: [44, 50, 57, 60, 64],
    pages: [152, 171, 190, 204, 221, 236],
    learners: [
      pp("e1", [11, 70, 74], [58, 58, 71]),
      pp("e2", [12, 72, 77], [61, 60, 74]),
      pp("e3", [9, 61, 69], [49, 52, 66]),
      pp("e4", [13, 75, 80], [66, 63, 77]),
      pp("e5", [10, 66, 71], [55, 55, 69]),
      pp("e6", [3, 40, 62], [24, 38, 60], "camera-tips"),
      pp("e7", [12, 71, 76], [63, 59, 73]),
      pp("e8", [11, 69, 73], [57, 57, 70]),
      pp("e9", [10, 67, 70], [54, 55, 68]),
      pp("e10", [12, 73, 78], [62, 61, 75]),
      pp("e11", [11, 70, 72], [59, 58, 70]),
      pp("e12", [10, 68, 74], [56, 56, 71]),
    ],
  },
};
