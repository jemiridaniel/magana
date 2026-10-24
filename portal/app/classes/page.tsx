import type { Metadata } from "next";
import Placeholder from "@/components/Placeholder";

export const metadata: Metadata = { title: "My classes" };

export default function Page() {
  return <Placeholder title="My classes" summary="See your classes, their mode and the learners in each." />;
}
