import type { Metadata } from "next";
import TeamAdmin from "@/components/TeamAdmin";

export const metadata: Metadata = { title: "Approved schools" };

export default function Page() {
  return <TeamAdmin tab="approved" />;
}
