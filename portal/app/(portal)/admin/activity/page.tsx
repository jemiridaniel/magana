import type { Metadata } from "next";
import TeamAdmin from "@/components/TeamAdmin";

export const metadata: Metadata = { title: "Activity log" };

export default function Page() {
  return <TeamAdmin tab="activity" />;
}
