// Thin client for the Magana FastAPI backend. The materials and register endpoints
// do not exist on the backend yet, so without NEXT_PUBLIC_API_URL these resolve with mock results.
import type { Learner, Version } from "./data";

export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "";
const useMock = !API_URL;
// The backend's MAGANA_API_KEY. NEXT_PUBLIC_ values ship to the browser, so this is for local
// development only; a deployed portal needs teacher sign-in and a server-side key instead.
const keyHeader: Record<string, string> = process.env.NEXT_PUBLIC_API_KEY
  ? { "X-Magana-Key": process.env.NEXT_PUBLIC_API_KEY }
  : {};

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function uploadMaterial(file: File, classId: string, versions: Version[]): Promise<{ id: string }> {
  if (useMock) {
    await wait(300);
    return { id: `local-${file.name}-${file.size}` };
  }
  const body = new FormData();
  body.append("file", file);
  body.append("class_id", classId);
  versions.forEach((v) => body.append("versions", v));
  const r = await fetch(`${API_URL}/materials`, { method: "POST", body, headers: keyHeader });
  if (!r.ok) throw new Error(`Upload failed (${r.status})`);
  return r.json();
}

/** Where a finished version can be downloaded, or null in the offline preview (no files exist yet). */
export function downloadUrl(uploadId: string, version: Version): string | null {
  if (useMock) return null;
  return `${API_URL}/materials/${encodeURIComponent(uploadId)}/${version}`;
}

export async function saveRegister(sessionId: string, learners: Pick<Learner, "id" | "mark">[]): Promise<void> {
  if (useMock) {
    await wait(300);
    return;
  }
  const r = await fetch(`${API_URL}/sessions/${encodeURIComponent(sessionId)}/register`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", ...keyHeader },
    body: JSON.stringify(learners.map(({ id, mark }) => ({ learner_id: id, mark }))),
  });
  if (!r.ok) throw new Error(`Save failed (${r.status})`);
}
