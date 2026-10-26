import type { Metadata } from "next";
import ReportsList from "@/components/ReportsList";
import { TeamOnly } from "@/components/TeamAdmin";

export const metadata: Metadata = { title: "Reports" };

export default function Page() {
  return <TeamOnly roles={["owner", "reviewer", "support"]}><ReportsList /></TeamOnly>;
}
