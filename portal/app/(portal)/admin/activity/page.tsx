import type { Metadata } from "next";
import ActivityLog from "@/components/ActivityLog";
import { TeamOnly } from "@/components/TeamAdmin";

export const metadata: Metadata = { title: "Activity log" };

export default function Page() {
  return <TeamOnly roles={["owner", "reviewer"]}><ActivityLog /></TeamOnly>;
}
