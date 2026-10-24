"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { level, subjectNames } from "@/lib/curriculum";
import { classes } from "@/lib/data";
import { messageFor } from "@/lib/messages";
import { blocking, check, listQuizzes, QuizError, savesToServer, type Quiz } from "@/lib/quizzes";

const className = (id: string) => classes.find((c) => c.id === id)?.name ?? id;

export default function QuizList() {
  const [quizzes, setQuizzes] = useState<Quiz[] | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    listQuizzes()
      .then(setQuizzes)
      .catch((e) => {
        setQuizzes([]);
        setError(messageFor(e instanceof QuizError ? e.code : "failed"));
      });
  }, []);

  return (
    <>
      <header className="page-head">
        <div>
          <h1>All quizzes</h1>
          <p>Quizzes you wrote for your classes. Learners hear each question and answer by voice or touch.</p>
        </div>
        <Link className="btn btn-primary" href="/quizzes/new">+ Create a quiz</Link>
      </header>
      <p role="status" className={`status-msg${error ? " status-error" : ""}`}>
        {error || (quizzes && !savesToServer() ? "Preview: quizzes are kept in this browser until the portal is connected to the Magana server." : "")}
      </p>
      {quizzes === null ? (
        <p className="note">Loading…</p>
      ) : quizzes.length === 0 ? (
        <section className="card">
          <h2>No quizzes yet</h2>
          <p className="note">Create one and assign it to a class session. Magana also has sample questions for every class.</p>
        </section>
      ) : (
        <div className="table-wrap card" role="region" aria-label="Quizzes table" tabIndex={0}>
          <table>
            <caption className="visually-hidden">Your quizzes</caption>
            <thead>
              <tr>
                <th scope="col">Quiz</th>
                <th scope="col">Class</th>
                <th scope="col">Subject</th>
                <th scope="col">Questions</th>
                <th scope="col">Status</th>
                <th scope="col"><span className="visually-hidden">Open</span></th>
              </tr>
            </thead>
            <tbody>
              {quizzes.map((q) => {
                const ready = blocking(check(q)).length === 0;
                return (
                  <tr key={q.id}>
                    <td><strong>{q.title}</strong></td>
                    <td>{className(q.class_id)}<span className="sub">{level(q.level).name}</span></td>
                    <td>{subjectNames[q.subject] ?? q.subject}</td>
                    <td>{q.questions.length}</td>
                    <td>
                      {q.status === "assigned" ? (
                        <span className="pill pill-ready pill-wrap">Assigned · {q.session}</span>
                      ) : (
                        <span className={`pill ${ready ? "pill-processing" : "pill-check"}`}>{ready ? "Draft, ready to assign" : "Draft"}</span>
                      )}
                    </td>
                    <td>
                      <Link className="link-target" href={`/quizzes/new?id=${q.id}`}>
                        Edit <span className="visually-hidden">{q.title}</span>
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
