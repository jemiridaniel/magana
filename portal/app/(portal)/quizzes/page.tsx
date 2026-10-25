import type { Metadata } from "next";
import QuizList from "@/components/QuizList";

export const metadata: Metadata = { title: "All quizzes" };

export default function QuizzesPage() {
  return <QuizList />;
}
