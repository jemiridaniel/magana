import type { Metadata } from "next";
import QuizEditor from "@/components/QuizEditor";

export const metadata: Metadata = { title: "Create a quiz" };

export default function CreateQuizPage() {
  return <QuizEditor />;
}
