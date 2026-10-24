import type { Metadata } from "next";
import Placeholder from "@/components/Placeholder";

export const metadata: Metadata = { title: "Learner progress" };

export default function Page() {
  return <Placeholder title="Learner progress" summary="Follow each learner's reading and quiz progress over the term." />;
}
