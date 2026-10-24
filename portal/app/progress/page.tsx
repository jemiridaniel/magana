import type { Metadata } from "next";
import ProgressView from "@/components/ProgressView";

export const metadata: Metadata = { title: "Learner progress" };

export default function ProgressPage() {
  return <ProgressView />;
}
