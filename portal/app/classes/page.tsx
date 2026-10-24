import type { Metadata } from "next";
import ClassesView from "@/components/ClassesView";

export const metadata: Metadata = { title: "My classes" };

export default function ClassesPage() {
  return <ClassesView />;
}
