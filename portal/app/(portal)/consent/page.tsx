import type { Metadata } from "next";
import ConsentView from "@/components/ConsentView";

export const metadata: Metadata = { title: "Consent records" };

export default function ConsentPage() {
  return <ConsentView />;
}
