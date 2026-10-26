# Magana privacy notice (draft)

**Draft for review** by Oluremi O. Balogun (consent and safeguarding) before testing with learners. It describes what the app and the Magana server do today; when that changes, this changes in the same commit.

**Contact:** maganasupport@gmail.com

## The short version

- **Photos of your pages are read and then deleted.** They are never saved on the server or on your phone.
- **Readings, reminders and your score stay on your phone** unless you choose otherwise.
- Magana never asks for your bank PIN or any account password. The only password it asks for is a locked PDF's own, to open that one file; it is never saved (see "PDFs" below).
- Magana has no adverts, no tracking and no crash reporting.
- **On WhatsApp (adults only), your photos pass through Meta's servers** before Magana reads them. See "WhatsApp" below.

## What happens to each kind of information

| What | Where it goes | Kept? |
|---|---|---|
| **Photo of a page** | Sent over HTTPS to the Magana server, read in memory | **No.** Deleted as soon as it is read. The phone's own copy is deleted once its bytes are sent. |
| **A PDF you open with Magana** (a statement, result or letter) | Sent over HTTPS to the Magana server, read in memory, page by page | **No.** Deleted as soon as it is read, like a photo. Its reading comes back to your phone and is kept only if you save it |
| **A locked PDF's password** | Typed on the phone, sent with that PDF only, used to open it | **No.** Never saved on the phone or the server, never logged, never sent back. The field is cleared after each try |
| **The text Magana read** | Back to your phone | Only if you choose **Save to my library**: on your phone, deleted after 30 days |
| **Text you ask Magana to explain** | In tester and production builds, only to an explanation server **approved** in docs/MODELS.md. None is approved yet, so today **no page text leaves the Magana server**: the app says "Explain isn't available yet" and reads the page. When a server is approved, it gets the page text (unclear numbers already masked) and your question. | Not stored by Magana. An approved server must not keep or log it. |
| **Spoken answers and commands** | See "Speech recognition" below. In short: on the phone where possible, otherwise Magana's own server. Only adults' audio may go to Google or the phone maker, as a last resort | Magana deletes any recording at once and never stores it |
| **Quick health check answers** | Sent to the Ibà service, which works out how soon a nurse should call | **No.** Never logged or stored. Logs record only which rules answered and the priority. |
| **Call-back request** | Your reason (medicine, results, other), call language and priority go to the nurse desk once one is set up | Kept by the desk to arrange the call. Today no desk is connected and the app says so. |
| **Medicine reminders** | On your phone only | Until you delete them |
| **Questions saved for your next visit** | On your phone only | Until you remove them |
| **Independence Score and task counts** | On your phone only (what you read and when, for 90 days) | "Share my score with my teacher" sends nothing until your class is connected to the teacher portal |
| **Age group, guardian consent, language** | On your phone. Every request tells the server your age group, so it can refuse what that group may not use | Classroom (under 13) sessions are never saved |
| **Your class** (for example JSS 2) | On your phone only. It picks the sample questions | Until you or a teacher change it. In Classroom sessions it is chosen by the teacher and never saved |
| **Class session code** | When a teacher opens a class session on your phone, the app sends the code to get that session's quizzes | Never saved: it ends with the session |
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

**Consent is recorded by the class teacher in the teacher portal** (how and when the parent or guardian agreed: signed form, in person or by phone). Magana keeps no guardian name or phone number. Until a teacher records it, a learner aged 13 to 17 who joined a class is "waiting for consent": they can read schoolwork pages, and nothing else. Their class isn't linked: no quizzes, notes or progress. *(DRAFT, for Oluremi O. Balogun: before, nothing worked without consent; the design now allows reading while waiting.)* When a guardian asks for deletion, a school admin confirms it and everything about the learner is deleted within 7 days.

## The Magana server

- **Where it runs:** on Amazon Web Services in London (eu-west-2), at **api.magana.ng**. The web version is at app.magana.ng, the teacher portal at teachers.magana.ng and the website at magana.ng.
- **The website** (magana.ng) sets no cookies and has no analytics or trackers. "Hear a sample" and "Your name in Braille" run in your browser: nothing you type is sent anywhere.
- **Connections:** encrypted (HTTPS). The app proves it is Magana with a key.
- **Server logs** record requests and errors. They never contain photos, recordings, page text or health-check answers.

## WhatsApp

> **For review by Oluremi O. Balogun** (consent and safeguarding) before WhatsApp is opened to testers.

Magana on WhatsApp is **for adults (18 and over)** only.
- **Under 18:** Magana gets the answer "under 18", sends one reply pointing to the app with a teacher or guardian, and one goodbye. After that **nothing they send is read or answered**, and their photos are never fetched. Magana keeps only "under 18" for that number.
- **Photos pass through Meta's servers.** WhatsApp messages to a business are delivered through Meta's WhatsApp Cloud API. Meta, not Magana, decides how long they stay on its servers to deliver them; its documentation says up to 30 days. This is the main difference from the app, where photos go straight to the Magana server. People who don't want that should use the app.
- **On the Magana server:**

  | What | Kept? |
  |---|---|
  | **Your photo** | **No.** Read in memory and deleted at once. Never written to disk. |
  | **The text Magana read** | In memory for 30 minutes, for "Read again". Then gone. |
  | **Your language and age group** ("adult" or "under 18") | Yes, under a coded form of your number (a keyed hash), not the number itself |
  | **Quick health check answers** | **No.** In memory only until the check ends. Never written down or logged. |
  | **A call-back request** | Reference, phone number (the nurse needs it to call you), language, priority, time and status. **Deleted after 30 days.** You can cancel it or change the number. |
  | **Message text and phone numbers in the server logs** | **Never.** Logs show only the kind of message and a short coded id. |
- **Messages are counted per month** (a number only) to stay within the free WhatsApp allowance.

## Teachers and schools

> **For review by Oluremi O. Balogun** (consent and safeguarding) before schools use the portal.

Schools register in the teacher portal (teachers.magana.ng). A school goes live only after the Magana team has called the principal to confirm it.

| What | Who it's about | Kept? |
|---|---|---|
| **The school**: name, state and local government area (as codes) | the school | while the school uses Magana |
| **The principal's contact**: name, role, email, phone number | the person who registered the school | while the school uses Magana; the phone number is only for the Magana team to confirm the school |
| **Teacher accounts**: name, email, role (teacher or school admin), the classes they teach | each teacher | while they work at the school; when removed, they're signed out at once and their name stays in the audit log |
| **Sign-in codes** | each teacher | 10 minutes, stored only in a form that can't be read back (a keyed hash) |
| **Sign-in sessions** | each teacher | until sign-out, 30 minutes without activity, or 12 hours |
| **Classes**: name, level, mode, the class code | the school | while the class exists. Codes are stored as a keyed hash, plus an encrypted copy only that class's teacher and the school's admins can see |
| **Learner–class links**: the name the teacher gives, preferred formats, language, whether under 18, consent status (how and when, no guardian details) | each learner who joined a class | while they're in the class; "Remove from class" unlinks the phone at once and keeps the term's records for the school |
| **The linked phone** | each learner | a random token the app keeps; the server stores only its hash. No phone number, no name from the phone |
| **Attendance marks, and figures a learner chooses to share** (pages read, help, quiz scores) | each learner | this term |
| **Audit log**: who invited, removed or changed whom, and when | teachers and learners | while the school uses Magana; mentions of a deleted learner are blanked |

- **Who sees what:** a teacher sees only their own classes and learners; a school's admins see the whole school; the Magana team sees school registrations (to confirm them), not learners. Teachers never see the pages learners photograph or the questions they ask.
- **Quizzes** a teacher writes are saved on the Magana server and reach only that teacher's class sessions. They hold the teacher's questions only: no learner names, answers or scores.
- **Deleting a learner's data:** a guardian asks the teacher; the teacher records it with "Remove from class"; a school admin confirms; everything about the learner is deleted at once (always within 7 days), and the audit log keeps only that "a learner's data was deleted".
- **Emails** (sign-in codes, invitations) are sent through Amazon SES from no-reply@magana.ng.

## PDFs

> **For Nurse Balogun to review:** Magana now asks for one kind of password, a locked PDF's own.

- **Read a PDF** (Everyday papers, or "Open with Magana" and Share from WhatsApp, Gmail or Files) sends the PDF to the Magana server, the same way a photo is sent. It is read in memory and deleted at once.
- A page with its own text (most bank PDFs) is read from the file's characters, so no picture of it is made. A scanned page is made into a picture in memory, read like a photo, and deleted.
- Many banks lock statement PDFs. Magana then asks for **that PDF's password**, says it is used only to open the file, and never stores it. It is never the bank PIN, the banking app's password or a one-time code. The screen says so: "Magana never asks for your bank PIN or app password."
- The password is shown as it's typed, so TalkBack can say it and a low-vision user can check it. "Read back" says it character by character, so say it only when no one is listening.
- Health, money and letter PDFs follow the same rules as photos: no model, numbers read exactly as printed.

## Handwriting

> **For Nurse Balogun to review:** the optional Azure reader would send crops of handwritten lines to Microsoft.

- Magana marks lines that look handwritten. Their numbers are read only when two separate readings agree. On a health paper, handwritten numbers are never read; Magana asks you to have the pharmacist or nurse read them.
- Two optional readers for handwritten **schoolwork** exist in the code. Both are **off**:
  - **TrOCR** runs on Magana's own server, so nothing leaves it.
  - **Azure AI Vision Read** sends a crop of each handwritten line to Microsoft. It would be for adults (18+) only, never for health, money or letters, never for under-18s, and only after this note is approved. It also costs money per page, so it stays off until the team decides.
- Teachers' handwritten uploads: the portal keeps the **text** Magana read (never the photo) and marks it "Check" until the teacher corrects and approves it. Learners get only approved text.

## Questions, or to delete something

Email **maganasupport@gmail.com**. For a learner in a class, the class teacher or school admin can delete everything (above). Everything else Magana keeps is on your phone: uninstalling the app deletes it.
