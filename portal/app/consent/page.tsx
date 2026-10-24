import type { Metadata } from "next";
import Placeholder from "@/components/Placeholder";

export const metadata: Metadata = { title: "Consent records" };

export default function Page() {
  return <Placeholder title="Consent records" summary="Guardian consent for learners under 18, kept in one place." />;
}
