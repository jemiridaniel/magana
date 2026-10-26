"use client";

// A file drop zone (board "Uploads"): a large dashed area, "Drop a file here or choose a file",
// centred. The file input itself is the focusable control (Tab, then Enter or Space opens the
// picker), so it works by keyboard and screen reader. Once chosen: the name and size, and
// "Change file".
import { useId, useRef, useState, type DragEvent } from "react";

export function fileSize(bytes: number): string {
  return bytes < 1024 * 1024 ? `${Math.max(1, Math.round(bytes / 1024))} KB` : `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function DropZone({ label, accept, hint, file, onFile, compact = false }: {
  label: string; accept: string; hint?: string; file: File | null; onFile: (f: File | null) => void; compact?: boolean;
}) {
  const id = useId();
  const input = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);

  function drop(e: DragEvent<HTMLDivElement>) {
    e.preventDefault();
    setOver(false);
    const f = e.dataTransfer.files?.[0];
    if (f) onFile(f);
  }

  return (
    <div className={`dropzone${over ? " is-over" : ""}${compact ? " dropzone-compact" : ""}`}
         onDragOver={(e) => { e.preventDefault(); setOver(true); }} onDragLeave={() => setOver(false)} onDrop={drop}>
      <input ref={input} id={id} type="file" accept={accept} className="dropzone-input"
             aria-describedby={hint ? `${id}-hint` : undefined}
             onChange={(e) => onFile(e.target.files?.[0] ?? null)} />
      {file ? (
        <>
          <p className="dropzone-title" aria-live="polite"><span className="visually-hidden">Chosen: </span>{file.name}</p>
          <p className="dropzone-size">{fileSize(file.size)}</p>
          <label htmlFor={id} className="btn">Change file<span className="visually-hidden">: {label}</span></label>
        </>
      ) : (
        <>
          <p className="dropzone-title">Drop a file here or choose a file</p>
          <label htmlFor={id} className="btn btn-primary">Choose a file<span className="visually-hidden">: {label}</span></label>
        </>
      )}
      {hint && <p id={`${id}-hint`} className="hint">{hint}</p>}
    </div>
  );
}
