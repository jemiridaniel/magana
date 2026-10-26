// The portal's own API (backend/app/portal_api.py): sign-in, schools, staff, classes, learners.
// The session is an HttpOnly cookie on the API's domain, sent with every request (apiFetch).
import { apiFetch, ServerDown } from "./server";

const apiKeyHeader: Record<string, string> = process.env.NEXT_PUBLIC_API_KEY
  ? { "X-Magana-Key": process.env.NEXT_PUBLIC_API_KEY }
  : {};

export class PortalError extends Error {
  constructor(public code: string, public detail: Record<string, unknown> = {}) {
    super(code);
  }
}

export async function call<T>(method: string, path: string, body?: unknown): Promise<T> {
  let r: Response;
  try {
    r = await apiFetch(path, {
      method,
      headers: { "Content-Type": "application/json", ...apiKeyHeader },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (e) {
    throw new PortalError(e instanceof ServerDown && e.state === "sleeping" ? "server_sleeping" : "unreachable");
  }
  const json = await r.json().catch(() => null);
  if (!r.ok) {
    const detail = json?.detail;
    if (typeof detail?.code === "string") throw new PortalError(detail.code, detail);
    throw new PortalError(r.status === 422 ? "form_invalid" : "failed");
  }
  return json as T;
}

export type Role = "admin" | "teacher";
export type Mode = "guided" | "classroom" | "standard";
export type Consent = "pending" | "received" | "not_needed";

export interface School { id: string; name: string; status: "pending" | "approved" | "rejected"; state: string; lga: string }
export type Me =
  | { kind: "staff"; id: string; name: string; email: string; role: Role; title: string; school: School }
  | { kind: "team"; email: string; name: string };

export interface ClassInfo {
  id: string; name: string; level: string; mode: Mode; teacher_id: string | null; teacher: string | null; code: string;
  learners: number; consents_needed: number; consents_received: number; attendance: number | null;
}

export interface Learner {
  id: string; name: string; class_id: string | null; formats: string[]; language: string; under_18: boolean;
  consent: Consent; consent_at: string | null; phone_linked: boolean; status: "active" | "removed";
  removed_at: string | null; removed_reason: string | null; joined_at: string; reminder_at: string | null;
  term?: { sessions_attended: number; sessions: number; attendance: number | null; pages: number | null;
           unaided: number | null; quiz_average: number | null };
  deletion?: { id: string; status: string; due: string } | null;
  class?: { id: string; name: string; mode: Mode } | null;
}

export interface StaffMember {
  id: string; name: string; email: string; role: Role; title: string;
  status: "invited" | "active" | "removed" | "expired"; invited_at: string | null; removed_at: string | null;
  classes: { id: string; name: string }[];
}

export type Attention =
  | { kind: "consent"; count: number; learners: { id: string; name: string; class: string | null }[] }
  | { kind: "upload_check" | "upload_ready"; upload: { id: string; title: string; note: string } }
  | { kind: "low_attendance"; learner: { id: string; name: string; class: string | null }; attended: number; sessions: number; attendance: number }
  | { kind: "second_admin" }
  | { kind: "deletion"; deletion: { id: string; due: string } };

export interface HomeData {
  me: Me & { kind: "staff" };
  classes: ClassInfo[];
  attention: Attention[];
  week: { pages: number; unaided: number; quiz_average: number | null } | null;
}

export interface Place { code: string; name: string; lgas: { code: string; name: string }[] }

export interface UploadInfo {
  id: string; title: string; status: "processing" | "check" | "ready" | "shared"; note: string;
  class_id: string | null; created_at: string; approved_at: string | null; script: "printed" | "handwritten" | "mixed";
}
export interface UploadLine { text: string; handwritten: boolean; flags: string[]; page: number | null; corrected?: boolean }

/** A teacher's file goes up as a form (not JSON); Magana keeps only the text it read. */
async function sendUpload(file: File, classId: string, title: string): Promise<{ code: string; upload: UploadInfo }> {
  const body = new FormData();
  body.append("file", file);
  body.append("class_id", classId);
  body.append("title", title);
  let r: Response;
  try {
    r = await apiFetch("/portal/uploads", { method: "POST", body, headers: apiKeyHeader });
  } catch (e) {
    throw new PortalError(e instanceof ServerDown && e.state === "sleeping" ? "server_sleeping" : "unreachable");
  }
  const json = await r.json().catch(() => null);
  if (!r.ok) throw new PortalError(typeof json?.detail?.code === "string" ? json.detail.code : "failed");
  return json;
}

export const portal = {
  uploads: () => call<UploadInfo[]>("GET", "/portal/uploads"),
  upload: (id: string) => call<UploadInfo & { lines: UploadLine[] }>("GET", `/portal/uploads/${id}`),
  sendUpload,
  checkUpload: (id: string, lines: string[], approve: boolean) =>
    call<{ code: string; upload: UploadInfo & { lines: UploadLine[] } }>("PUT", `/portal/uploads/${id}`, { lines, approve }),
  me: () => call<Me>("GET", "/portal/me"),
  requestCode: (email: string) => call<{ retry_after: number; minutes: number }>("POST", "/portal/auth/request-code", { email }),
  verify: (email: string, code: string) => call<{ me: Me }>("POST", "/portal/auth/verify", { email, code }),
  signOut: () => call("POST", "/portal/auth/sign-out"),
  places: () => call<{ states: Place[] }>("GET", "/portal/places"),
  register: (body: Record<string, unknown>) => call<{ school_id: string }>("POST", "/portal/schools/register", body),
  home: () => call<HomeData>("GET", "/portal/home"),
  classes: () => call<ClassInfo[]>("GET", "/portal/classes"),
  createClass: (body: { name: string; level: string; mode: Mode; teacher_id?: string }) => call<ClassInfo>("POST", "/portal/classes", body),
  editClass: (id: string, body: { name?: string; teacher_id?: string }) => call<ClassInfo>("PATCH", `/portal/classes/${id}`, body),
  rotateClassCode: (id: string) => call<{ class_code: string }>("POST", `/portal/classes/${id}/rotate-code`),
  learners: (classId: string) => call<Learner[]>("GET", `/portal/classes/${classId}/learners`),
  learner: (id: string) => call<Learner>("GET", `/portal/learners/${id}`),
  editLearner: (id: string, body: { name?: string; formats?: string[]; language?: string }) => call<Learner>("PATCH", `/portal/learners/${id}`, body),
  recordConsent: (id: string, how: string) => call("POST", `/portal/learners/${id}/consent`, { how }),
  remind: (id: string) => call<{ class_name: string; school: string }>("POST", `/portal/learners/${id}/remind`),
  moveLearner: (id: string, classId: string) => call("POST", `/portal/learners/${id}/move`, { class_id: classId }),
  removeLearner: (id: string, reason: string) => call<{ deletion_id: string | null }>("POST", `/portal/learners/${id}/remove`, { reason }),
  deletions: () => call<{ id: string; learner_name: string | null; due: string; requested_at: string }[]>("GET", "/portal/deletions"),
  confirmDeletion: (id: string) => call("POST", `/portal/deletions/${id}/confirm`),
  teacherCode: () => call<{ teacher_code: string }>("GET", "/portal/me/teacher-code"),
  rotateTeacherCode: () => call<{ teacher_code: string }>("POST", "/portal/me/teacher-code/rotate"),
  staff: () => call<StaffMember[]>("GET", "/portal/staff"),
  invite: (body: { email: string; name: string; role: Role; title?: string; class_ids?: string[] }) => call("POST", "/portal/staff", body),
  resend: (id: string) => call("POST", `/portal/staff/${id}/resend`),
  cancelInvite: (id: string) => call("POST", `/portal/staff/${id}/cancel`),
  editStaff: (id: string, body: { role?: Role; title?: string; name?: string; class_ids?: string[] }) => call<StaffMember>("PATCH", `/portal/staff/${id}`, body),
  removeStaff: (id: string, reassign: Record<string, string>) => call("POST", `/portal/staff/${id}/remove`, { reassign }),
  attendance: (classId: string, day: string) => call<{ marks: Record<string, string> }>("GET", `/portal/classes/${classId}/attendance?day=${day}`),
  saveAttendance: (classId: string, day: string, marks: { learner_id: string; mark: string }[]) =>
    call("PUT", `/portal/classes/${classId}/attendance`, { day, marks }),
  audit: () => call<{ id: number; action: string; actor_name: string; target_name: string | null; at: string }[]>("GET", "/portal/audit"),
  pendingSchools: () => call<{ id: string; name: string; state_name: string; lga_name: string; contact_name: string;
    contact_role: string; contact_email: string; contact_phone: string; created_at: string }[]>("GET", "/portal/admin/schools"),
  decideSchool: (id: string, decision: "approve" | "reject") => call("POST", `/portal/admin/schools/${id}`, { decision }),
};

export const modeLabel: Record<Mode, string> = {
  guided: "Guided · 13–17",
  classroom: "Classroom · under 13",
  standard: "Standard · 18 and over",
};

export const reasonLabel: Record<string, string> = {
  left: "Left the school or changed class",
  mistake: "Added by mistake",
  deletion: "Guardian asked us to delete their data",
};

/** "482915" → "482 915": easier to read out to a class. */
export const spaced = (code: string) => `${code.slice(0, 3)} ${code.slice(3)}`;
