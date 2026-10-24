# Data sources tracker

Every piece of content Magana ships, tests with or benchmarks on. CLAUDE.md "Data rules": only open-licence (CC BY / CC BY-SA), team-made, or written-permission material goes in the published benchmark. No scraped past-question sites. Credit every source.

When you add content, add a row in the same commit.

| What | Where | Source | Licence | Review status |
|---|---|---|---|---|
| **Quiz sample packs, Primary 1–3**: English, Mathematics, Basic Science (10 questions each) | `app/assets/quiz/primary_1_3-*.json` | Team-made, our own wording. Not past questions | CC BY 4.0 | **Sample, to be reviewed by a teacher** of each subject |
| **Quiz sample packs, Primary 4–6**: English, Mathematics, Basic Science | `app/assets/quiz/primary_4_6-*.json` | Team-made, our own wording | CC BY 4.0 | **Sample, to be reviewed by a teacher** |
| **Quiz sample packs, JSS 1–3**: English, Mathematics, Basic Science | `app/assets/quiz/jss-*.json` | Team-made, our own wording | CC BY 4.0 | **Sample, to be reviewed by a teacher** |
| **Quiz sample packs, SSS 1–3**: English, Mathematics, Biology | `app/assets/quiz/sss-*.json` | Team-made. Biology is written in the style of WAEC SSCE Biology; not past questions | CC BY 4.0 | **Sample, to be reviewed by a teacher** |
| Skills lessons | `app/assets/lessons/lessons.json` | Team-made | CC BY 4.0 | Draft, to be reviewed by rehabilitation trainers |
| Explanation benchmark pages (10) | `benchmark/explain/pages/` | Team-made | CC BY 4.0 | Ratings by native speakers pending |
| ASR benchmark audio | Streamed from `google/fleurs`, cached outside the repo | FLEURS (Conneau et al., 2022) | CC BY 4.0 | Transcripts await native-speaker review |
| Misread regression photos | `backend/tests/fixtures/misreads/` | Photos taken by the team | Team-owned; check before publishing in the benchmark | — |
| Curriculum level and subject names | `backend/app/curriculum.py` | Nigerian national curriculum subject names (NERDC) | Names only, no curriculum text | — |
| Teacher-made quizzes | The server (`MAGANA_DATA_DIR`), never the repo | Written by each teacher in the portal | The teacher's own; used only for their classes | Teachers check their own; translations marked checked by a speaker of the language |

Not yet used and not to be added without a row here: past-question sites, textbook scans and any other material without a licence or written permission.
