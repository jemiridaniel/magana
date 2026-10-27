// Class levels and subjects. curriculum.json is a copy of the backend's
// (backend/app/curriculum.py); backend/tests/test_curriculum.py fails if it drifts.
import data from "./curriculum.json";

export type LevelId = "p1" | "p2" | "p3" | "p4" | "p5" | "p6" | "jss1" | "jss2" | "jss3" | "sss1" | "sss2" | "sss3";
export type BandId = "primary_1_3" | "primary_4_6" | "jss" | "sss";

export interface Level {
  id: LevelId;
  name: string;
  band: BandId;
  /** The 9-year Basic Education name: "Basic 4" is Primary 4, "Basic 7" is JSS 1. */
  basic?: string;
}

export const levels = data.levels as Level[];
export const subjectNames = data.subjects as Record<string, string>;
export const PRIMARY_WORD_HINT = data.primary_word_hint;
export const MIN_OPTIONS = data.min_options;

export const level = (id: LevelId) => levels.find((l) => l.id === id)!;
/** "Primary 4 (Basic 4)": what a teacher picks from. */
export const levelLabel = (l: Level) => (l.basic ? `${l.name} (${l.basic})` : l.name);
export const isPrimary = (id: LevelId) => level(id).band.startsWith("primary");
/** Primary 1–3: 2 or 3 options; Primary 4–6, JSS and SSS: up to 4 (A–D). */
export const maxOptions = (id: LevelId) => (data.band_max_options as Record<BandId, number>)[level(id).band];
export const subjectsFor = (id: LevelId) => (data.band_subjects as Record<BandId, string[]>)[level(id).band];
