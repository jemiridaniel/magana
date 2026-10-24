# Magana privacy notice (draft)

**Draft for review** by Oluremi O. Balogun (consent and safeguarding) before testing with learners. It describes what the app and the Magana server do today; when that changes, this changes in the same commit.

**Contact:** maganasupport@gmail.com

## The short version

- **Photos of your pages are read and then deleted.** They are never saved on the server or on your phone.
- **Readings, reminders and your score stay on your phone** unless you choose otherwise.
- Magana never asks for your PIN or password.
- Magana has no adverts, no tracking and no crash reporting.

## What happens to each kind of information

| What | Where it goes | Kept? |
|---|---|---|
| **Photo of a page** | Sent over HTTPS to the Magana server, read in memory | **No.** Deleted as soon as it is read. The phone's own copy is deleted once its bytes are sent. |
| **The text Magana read** | Back to your phone | Only if you choose **Save to my library**: on your phone, deleted after 30 days |
| **Text you ask Magana to explain** | In tester and production builds, only to an explanation server **approved** in docs/MODELS.md. None is approved yet, so today **no page text leaves the Magana server**: the app says "Explain isn't available yet" and reads the page. When a server is approved, it gets the page text (unclear numbers already masked) and your question. | Not stored by Magana. An approved server must not keep or log it. |
| **Spoken answers and commands** | See "Speech recognition" below. In short: on the phone where possible, otherwise Magana's own server. Only adults' audio may go to Google or the phone maker, as a last resort | Magana deletes any recording at once and never stores it |
| **Quick health check answers** | Sent to the Ibà service, which works out how soon a nurse should call | **No.** Never logged or stored. Logs record only which rules answered and the priority. |
| **Call-back request** | Your reason (medicine, results, other), call language and priority go to the nurse desk once one is set up | Kept by the desk to arrange the call. Today no desk is connected and the app says so. |
| **Medicine reminders** | On your phone only | Until you delete them |
| **Questions saved for your next visit** | On your phone only | Until you remove them |
| **Independence Score and task counts** | On your phone only (what you read and when, for 90 days) | "Share my score with my teacher" sends nothing until your class is connected to the teacher portal |
| **Age group, guardian consent, language** | On your phone. Every request tells the server your age group, so it can refuse what that group may not use | Classroom (under 13) sessions are never saved |
| **Your class** (for example JSS 2) | On your phone. The app asks the server for your teacher's quizzes for that class level | Until you or a teacher change it. In Classroom sessions it is chosen by the teacher and never saved |
| **Quizzes you take** | On your phone only | That you finished a quiz counts toward your Independence Score. Your answers are not kept |

## Speech recognition

> **For review by Oluremi O. Balogun** (consent and safeguarding) before testing with learners.

When you answer the quiz, speak a command or ask a question, Magana tries these in order:

1. **Your phone's on-device recogniser,** where Android has one (usually Android 12 or later with an offline speech model). **The audio never leaves your phone.** Magana asks Android whether real on-device recognition is available; it does not just "prefer" offline.
2. **Magana's own speech recognition server** (NCAIR1's Hausa, Yorùbá, Igbo and Nigerian-English models). The short recording is sent over HTTPS, recognised in memory and deleted at once; it is never stored.
3. **Adults (18+) only:** the phone's usual recogniser, which may send the audio to Google or the phone maker.
4. **Otherwise: tap your answer.** Every question and button works by tapping (double tap with TalkBack).

**Learners under 18** (Guided and Classroom accounts) **never use step 3.** If neither the phone nor Magana's server can recognise their speech, the app asks them to tap instead.

## Development and testing with Kaggle

During development the team runs the explanation model on temporary Kaggle notebooks. **Only the team's own test pages are sent there**, never testers' or users' papers. A tester or production server refuses to send any page text to a host that isn't approved, and a test checks that no request is made.

## Age groups and consent

- **18 and over:** everything, including health and money papers.
- **13 to 17:** school subjects only, after a parent, guardian or teacher agrees. No health or money papers, no open questions, no descriptions of people.
- **Under 13:** only in a session a teacher starts. Nothing is saved after it.

Until learner accounts exist, consent is recorded on the phone. Real consent records belong in the teacher portal (see "Consent records"). When consent is withdrawn, the account closes and the learner's data is deleted.

## The Magana server

- **Where it runs:** on Amazon Web Services in London (eu-west-2).
- **Connections:** encrypted (HTTPS). The app proves it is Magana with a key.
- **Server logs** record requests and errors. They never contain photos, recordings, page text or health-check answers.

## Teachers

Quizzes a teacher writes in the portal are saved on the Magana server so learners in that class level can take them. They hold the teacher's questions only: no learner names, answers or scores.

Teachers see summaries only: attendance, and progress if a learner chooses to share it. They never see the pages learners photograph or the questions they ask.

## Questions, or to delete something

Email **maganasupport@gmail.com**. Everything Magana keeps is on your phone: uninstalling the app deletes it.
