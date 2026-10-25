"use client";

import { useEffect } from "react";

declare global {
  interface Window {
    __mgReady?: () => void;
  }
}

/** Tells the page loader (components/loader.ts) that React has taken over the page. */
export default function Ready() {
  useEffect(() => {
    window.__mgReady?.();
  }, []);
  return null;
}
