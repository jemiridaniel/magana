import type { Metadata } from "next";
import TeamAdmin from "@/components/TeamAdmin";

export const metadata: Metadata = { title: "Not approved" };

export default function Page() {
  return <TeamAdmin tab="rejected" />;
}
