import type { Metadata } from "next";
import TeamAdmin from "@/components/TeamAdmin";

export const metadata: Metadata = { title: "Schools to approve" };

export default function AdminPage() {
  return <TeamAdmin tab="pending" />;
}
