import type { Metadata } from "next";
import Placeholder from "@/components/Placeholder";

export const metadata: Metadata = { title: "Help" };

export default function Page() {
  return <Placeholder title="Help" summary="Guides for teachers and how to reach the Magana team." />;
}
