import type { Metadata } from "next";
import TeamMembers from "@/components/TeamMembers";

export const metadata: Metadata = { title: "Magana team" };

export default function Page() {
  return <TeamMembers />;
}
