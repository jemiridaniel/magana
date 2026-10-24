# Quizzes and lessons by class: the content model

Magana is for primary pupils as well as secondary students, so practice content is organised by **class level** and **subject**. The level and subject names follow the Nigerian national curriculum.

## Levels and subjects

| Band | Levels | Subjects |
|---|---|---|
| Primary 1–3 | Primary 1, 2, 3 | English, Mathematics, Basic Science, Social Studies, Hausa, Yorùbá, Igbo |
| Primary 4–6 | Primary 4, 5, 6 | the same |
| JSS 1–3 | JSS 1, 2, 3 | the same |
| SSS 1–3 | SSS 1, 2, 3 | English, Mathematics, Biology, Chemistry, Physics, Hausa, Yorùbá, Igbo |

The backend holds the list (`backend/app/curriculum.py`, `GET /curriculum`). The app (`app/assets/curriculum.json`, `app/lib/curriculum.dart`) and the portal (`portal/lib/curriculum.json`) carry copies. Tests on both sides fail if a copy drifts.

## Who chooses the class

- **18+ and 13–17:** the learner chooses their class once, in onboarding (step 3). Adults can choose "I'm not in school".
- **Under 13:** the teacher chooses the class when starting the Classroom session. Like the session, it is never saved.
- **Changing it:** Settings → My class asks "Only a teacher should change the class. Are you a teacher?" first. Until teachers sign in, the app takes their word for it, as with consent.

## Quiz content

One question format everywhere: the bundled packs, the backend's teacher quizzes and the learner app.

```json
{ "id": "q1", "question": "Which part of a plant makes food for the plant?",
  "options": ["The leaf", "The root", "The flower"], "answer": 0,
  "explanation": "Leaves make food using sunlight.",
  "picture": "A drawing of a plant…",
  "translations": { "yo": "Apá wo nínú ewéko…" } }
```

- **Sample packs** (`app/assets/quiz/<band>-<subject>.json`): 10 team-made questions per band for English, Mathematics and Basic Science (Biology for SSS). Each pack is marked `"sample": true`, and the app shows "Sample questions". They are listed in docs/DATA_SOURCES.md as team-made, to be reviewed by a teacher. They work offline.
- **Teacher-made quizzes:** written in the portal (Quizzes → Create a quiz), saved on the server, and assigned to one **class session**. Assigning gives that session a 6-character **session code**; every quiz assigned to the same class session shares it.
  - A teacher's quiz reaches **only** that session. On each learner's phone, the teacher opens Practice quiz → "Teacher: open your class session" and types the code. The app then fetches `/learner/quizzes?session_code=…` with `X-Magana-Teacher-Session`, for any age group.
  - **Learners on their own see only the sample packs.** The app doesn't ask the server, and the server refuses without a teacher-opened session.
  - Never by class level: another class at the same level, or the same session name in another class, gets a different code.
  - The code is kept for the session only, never saved. Quizzes hold no learner data.
  - This holds until class codes and teacher accounts exist.
- **Translations:** a teacher may add the question in Hausa, Yorùbá or Igbo. Learners only hear a translation after a teacher who speaks the language marks it checked; otherwise English.
- **Pictures:** a picture must be described in words before the quiz can be assigned, and Magana reads the description. The picture file itself isn't sent to learners yet.

## Primary mode (Primary 1–6)

- **Two or three options.** The portal won't let a primary question have more, and the backend refuses to assign one that does.
- **Short sentences:** 15 words or fewer. The portal shows the count, and it's a warning, not a block.
- **A slower voice:** 0.8 times the learner's own speed, put back when the quiz closes.
- **Encouraging feedback:** "Well done! You chose A." / "Good try! The answer is A, the leaf."
- **The right letters:** "Say A, B or C", never "A, B, C or D".

Under 13, every quiz, sample packs included, only runs inside a teacher-started Classroom session (the app's ProfileGate). For every age group, a teacher's quizzes need the session code, and the backend refuses `/learner/quizzes` without `X-Magana-Teacher-Session`.

## The teacher portal's checks ("Before you assign")

| Blocks assigning | Warning only |
|---|---|
| A question or option is empty | A primary question has more than 15 words |
| No right answer marked | A translation isn't checked yet |
| Fewer than 2 options, or more than the class allows (3 primary, 4 otherwise) | |
| A picture without a description | |

The same rules run in the portal (`portal/lib/quizzes.ts`) and on the server (`backend/app/quizzes.py`, which has the last word).

Quiz writes need `MAGANA_TEACHER_KEY`, because the app's API key is public. Without it, only a `MAGANA_ENV=development` server accepts quizzes.

## Lessons

Skills lessons (`app/assets/lessons/lessons.json`) are not tied to a class level yet. When school lessons are added, they take the same `band` and `subject` fields as quiz packs.
