# Magana privacy notice

> **DRAFT for Oluremi O. Balogun** (consent and safeguarding) to review before testing with learners. It follows the Nigeria Data Protection Act 2023 (NDPA) and describes what the Magana app, server and portal do today. When they change, this notice changes in the same commit. Points marked **[check]** need a decision or a legal check.

Last updated: 28 October 2026 · Contact: **support@magana.ng**

## The short version

- **Photos and PDFs of your papers are read and then deleted.** They are never saved on the server. Without internet, a photo is read on your phone and can wait there, encrypted, for a full reading when you're back online; then it is deleted. **[check]**
- **What Magana reads for you stays on your phone,** unless you save it to your library (30 days) or share it.
- **No tracking.** The app and website have no analytics, no trackers and no crash reporting.
- **Magana never asks for your bank PIN or any account password.** The one password it may ask for is a locked PDF's own, to open that one file. It is never saved.
- **On WhatsApp (adults only), your photos pass through Meta's servers** before Magana reads them.
- **You can see, correct or delete what we hold about you,** and complain to the Nigeria Data Protection Commission.

## Who we are

Magana is a reading companion for blind and low-vision people in Nigeria, built and run by the Magana team. For this notice, "we" means the Magana team. We decide how Magana handles personal data, so under the NDPA we are the **data controller**.

When a school uses the teacher portal, the school decides what it records about its learners, and we hold it for the school. **[check]** The school is then the controller for its learner records and Magana is its processor; a short agreement with each school should say so.

## What we collect, why, and our legal basis

The NDPA lets us use personal data only for a clear purpose and on a lawful basis. Health information is **sensitive personal data**, so we use it only with your explicit consent (you choose to read a health paper or take the quick check), or to protect someone's life in an emergency.

| What | Why | Legal basis | Kept |
|---|---|---|---|
| **A photo or PDF of a page** | To read it to you | Your consent: you choose to send it | **Not kept.** Read in memory on our server, then deleted. The phone deletes its copy once it is sent. Offline: see "Reading without internet" |
| **A locked PDF's password** | To open that one file | Your consent | **Not kept.** Used once, never saved or logged, never sent back |
| **The text Magana read** | So you can hear it again | Your consent | On your phone only. In your library only if you save it: 30 days |
| **Your speech** (answers, commands, questions) | To understand what you say | Your consent | **Not kept.** See "Speech recognition" |
| **Quick health check answers** | To set how soon a nurse calls you back | Explicit consent; vital interests for danger signs | **Not kept.** Never logged or stored |
| **A call-back request**: reason, phone number, language, priority | So a nurse or pharmacist can call you | Explicit consent | **30 days**, then deleted. You can cancel it |
| **Your age group and language** | To show only what your age group may use, in your language | Legitimate interests; a guardian's consent for 13 to 17 | On your phone. Every request tells our server your age group |
| **Reminders, saved questions, your Independence Score** | For you | Your consent | On your phone only, until you delete them (score: last 90 days) |
| **School, teacher and class records** | To run the teacher portal | Contract with the school; legitimate interests | See "Teachers and schools" |
| **Server logs**: time, internet address, which page of our service was asked for, errors | To keep the service working and safe | Legitimate interests | Test phase: on our server in London (Oracle Cloud), at most 100 MB of logs per server version, the oldest overwritten first; deleted with that version, usually within weeks. **[check]** |

Server logs never contain photos, page text, recordings or health-check answers.

## Reading without internet

When there is no internet, or Magana's server fails or takes more than 8 seconds, the photo is **read on your phone** by text recognition built into the app (Google ML Kit, on-device). **Nothing leaves the phone** for that reading. It is a basic reading: no tables, columns or Explain.

"Full reading when online" (on unless you switch it off): the photo **waits on your phone, encrypted** with a key kept in the phone's secure key store, and is sent for the full reading the next time Magana is online. The full reading goes to My library (kept 30 days, like any saved reading) and **the photo is deleted**. At most 20 photos wait; if there are more, the oldest is deleted and you are told. Accounts that can't keep a library (under 13) never keep a photo. **[check]** New: this is the only time a photo stays on the phone.

## Speech recognition

When you speak an answer, a command or a question, Magana tries these in order:

1. **Your phone's own recogniser,** where Android can recognise speech on the phone (usually Android 12 or later with an offline model). **The audio never leaves your phone.**
2. **Magana's own speech server** (NCAIR1's Hausa, Yorùbá, Igbo and Nigerian-English models). The short recording is sent securely, recognised in memory and deleted at once.
3. **Adults only:** the phone's usual recogniser, which may send the audio to Google or the phone maker.
4. **Otherwise, tap your answer.** Everything works by tapping.

**Learners under 18 never use step 3.**

## Children and age groups

- **18 and over:** everything, including health and money papers.
- **13 to 17:** school subjects only, after a parent or guardian agrees. No health or money papers, no WhatsApp, no open questions, no descriptions of people.
- **Under 13:** only in a session a teacher starts. Nothing from it is saved.

Under the NDPA, a child's data needs a parent's or guardian's consent. **The class teacher records that consent in the teacher portal**: how and when the guardian agreed (signed form, in person or by phone). We keep no guardian name or phone number. Until consent is recorded, a learner aged 13 to 17 can read schoolwork pages and nothing else. **[check, DRAFT]** Reading while waiting for consent is new.

## WhatsApp

Magana on WhatsApp is **for adults only**. If someone says they are under 18, Magana replies once, pointing them to the app with a teacher or guardian, and then reads nothing more from that number. It keeps only "under 18".

- **Your photos pass through Meta's servers.** Messages to a business on WhatsApp are delivered by Meta's WhatsApp Cloud API. Meta decides how long it keeps them to deliver them; its documentation says up to 30 days. If you don't want that, use the app, which sends photos straight to our server.
- **On our server:**
  - your photo is read in memory and never written down;
  - the text read is kept for 30 minutes, for "Read again";
  - your language and age group are kept under a coded form of your number, not the number itself, until you ask us to delete them;
  - quick-check answers are never written down;
  - a call-back request is kept for 30 days.
- Our logs never show message text or phone numbers.

## PDFs

"Read a PDF" sends a PDF to our server the same way as a photo. It is read in memory and deleted. If a bank locked the PDF, Magana asks for **that PDF's password** and says it is used only to open the file. It is never your bank PIN, app password or one-time code. The password is shown as you type it, so TalkBack can say it, so type it where no one can see or hear.

## Health and money papers

Health papers, bank statements and letters are never sent to an AI model. Magana reads them exactly as printed, numbers included, and translates only with phrases a pharmacist has approved. Magana gives no diagnosis and no financial advice. Health questions go to a nurse or pharmacist, and danger signs to a clinic or 112.

## Handwriting

Magana marks lines that look handwritten. It reads their numbers only when two separate readings agree, and never reads handwritten numbers on a health paper. Two optional readers for handwritten **schoolwork** exist:
- **TrOCR** runs on our own server.
- **Azure AI Vision Read** sends a crop of each handwritten line to Microsoft.

**Both are switched off.** Azure would be used only if we switch it on, for adults' schoolwork only, and this notice would say so first.

## Teachers and schools

| What | Kept |
|---|---|
| The school's name, state and local government area | While the school uses Magana |
| The principal's name, role, email and phone (the phone only so we can confirm the school) | While the school uses Magana |
| **Proof of school** (optional: a photo or PDF of the letterhead, Ministry approval letter or staff ID) and a Ministry approval number | The file is stored encrypted and only the Magana team can open it. **It is deleted automatically as soon as we approve the school or decide not to.** The approval number stays with the school's record |
| A school we couldn't confirm | Its details are deleted 30 days after our decision, unless the principal replies |
| Teachers' names, emails, roles and classes | While they work at the school. When removed, they are signed out at once; their name stays in the audit log |
| Sign-in codes | 10 minutes, in a form that can't be read back. At most 5 codes an hour for one email |
| An email address our mail couldn't reach (a permanent bounce) or that marked our mail as spam | Kept so we never email it again, with the date and which of the two it was. The email itself is never kept. Our email provider (Resend) keeps its own suppression list. Email support to be taken off it |
| Sign-in sessions | Until sign-out, 30 minutes without activity, or 12 hours |
| Classes and class codes | While the class exists. Codes are stored in a form that can't be read back, plus an encrypted copy for the class's teacher and the school's admins |
| A learner's class link: the name the teacher gives, formats, language, under 18 or not, consent status | While they are in the class. "Remove from class" unlinks the phone at once |
| The linked phone | A random token on the phone; we store only a coded form of it. No phone number |
| Attendance, and figures a learner chooses to share: per day, pages read and how many tasks they did on their own or with some help ("Did you need help?"). Never what they read | This term |
| Teachers’ uploads (worksheets, notes) | **Only the text Magana read, never the file.** While the school uses Magana; email us to delete one |
| The audit log (who invited, removed or changed whom, and when) | While the school uses Magana. A deleted learner is blanked in it |

A teacher sees only their own classes; a school's admins see the whole school. The Magana team sees school registrations, to confirm them, but not learners. Teachers never see the pages learners photograph or the questions they ask.

## The Magana team's own accounts

The people who run Magana sign in to their own pages with team accounts: Magana admin, School reviewer or Support (view only).
- We keep each team member's name, email, role, when they last signed in, and every action they took (the activity log). Each log entry also notes the browser and a rough place (from the device's time zone, never the internet address) the session signed in from. **Log entries can't be edited or deleted and are kept 2 years**, then deleted. They never contain learner data, sign-in codes, authenticator keys or backup codes.
- Sign-in needs an email code **and** an authenticator app code. The app's key is stored encrypted and the 8 backup codes only as keyed hashes. The QR code and key are drawn on our own server, shown once, and sent with instructions not to cache them. Team members are signed out after 15 minutes without activity, and can reset their authenticator at any time.
- **Team accounts can't see learners' names, progress or consent.** They see schools and their teachers only, and the server enforces it.
- One role per email: a team member can't also be a teacher or school admin.

## Problem reports

"Report a problem" in the app sends the Magana team:
- what went wrong, chosen from a list;
- the app version, the phone's maker and model, the app language and the screen you were on;
- **for adults only**, a voice note of up to 60 seconds, if you record one. Under-18s have no recording option.
- **the page's text, only if you switch "Include this page's text" on.** It is off by default. Never in a Classroom session. A photo is never sent.

Reports are kept 180 days, then deleted. Only the Magana team can see them. The email that tells our support team about a new report says what went wrong and where, never the page text or the voice note. Playing a voice note is logged.

## Who else handles your data

We use a few service providers. They handle data only to provide their service to us:

| Provider | What for | What they see |
|---|---|---|
| **Oracle Cloud** (London, UK), **test phase** | Runs our server: reads photos and PDFs, in memory only, and answers the app and portal | Everything our server handles while it handles it, encrypted on the way. Its disk holds only our server's logs (above) |
| **GitHub** (United States), **test phase** | Keeps our daily database backups, in a private repository | The database's contents, **encrypted before they leave our backup job**: GitHub can't read them. Kept 30 days, and one a month for 12 months |
| **Neon** (London, UK), **test phase** | Our database: schools, teachers, classes, learners as the school records them, consent, attendance, the audit log, quizzes | What the table below lists, encrypted on the way and at rest |
| **Resend** (its sending runs in Ireland, EU) | Sending sign-in codes, invitations and school registration emails | The recipient's email address and the email's content |
| **Cloudflare** | Our domain names, hosting the website, web app and portal, and the gateway in front of our server (api.magana.ng) | Visitors' internet addresses, and every request to our server as it passes, encrypted on the way |
| **Meta (WhatsApp)** | Delivering WhatsApp messages | WhatsApp messages and photos |
| **The Ibà service** | Working out call-back priority from the quick check | The answers, never stored |
| **Google or the phone maker** | Speech recognition, adults only, as a last resort | That short recording |
| **Microsoft (Azure)** | Handwriting, **only if we switch it on** | Crops of handwritten schoolwork lines |

During development the team also runs the explanation model on temporary Kaggle notebooks, **with the team's own test pages only**, never users' papers.

## Data stored outside Nigeria

**During the test phase** (until free hosting is replaced; docs/INFRA.md):
- **Our database is in London, United Kingdom** (Neon). Everything we keep is there.
- **Our server runs in London, United Kingdom** (Oracle Cloud). It processes requests there and holds photos and PDFs in memory only while reading them.
- **Our database backups are kept by GitHub** (United States), encrypted so that only we can open them.
- **Emails are sent from Ireland** (Resend).

Sending personal data outside Nigeria is allowed under the NDPA when it stays adequately protected. We protect it the same way wherever it is: encrypted connections, no photos kept, little data held. **[check]** Confirm the basis for these transfers (the UK, the US and the EU) with the NDPC's guidance (adequacy, or the safeguards the NDPA accepts), and whether testing with learners' data should wait for hosting in Nigeria or the UK only.

## How we keep data safe

- Every connection is encrypted (HTTPS).
- The app proves it is Magana with a key. Requests are limited per device and per address.
- We keep as little as we can. Photos, PDFs, recordings and health-check answers are never stored.
- Codes and phone links are stored in forms that can't be read back. Only the teachers who need class codes can see them.
- Teachers sign in with a one-time code by email: no passwords to steal.
- The server is updated by an automatic process with checks. Only the team's own computer can log in to it directly.

If a breach puts people's data at risk, we will tell the NDPC **within 72 hours** of finding out, as the NDPA requires, and tell the people affected as soon as we can when the risk to them is high.

## Requests from the police or government

We share personal data with the police, a court or a government body only when Nigerian law requires it, and only what the request lawfully asks for. Where the law allows, we tell the person first. Because we keep so little, there is often nothing to give: no photos, page text, recordings or health-check answers exist.

## Your rights

Under the NDPA you can:
- **see** the personal data we hold about you, and get a copy;
- **correct** it if it's wrong;
- **delete** it ("erasure");
- **object** to how we use it, or ask us to use it less;
- **withdraw your consent** at any time; this doesn't undo what was done before;
- **complain** to the **Nigeria Data Protection Commission (NDPC)**, at ndpc.gov.ng.

**How:**
- Email **support@magana.ng**. We answer within 30 days.
- Most of what Magana keeps is on your phone: uninstalling the app deletes it.
- For a learner in a class, the teacher or school admin can remove the learner and, when a guardian asks, delete everything about them. A school admin confirms, and it is all deleted within 7 days.

## Changes to this notice

When Magana changes what it does with personal data, we update this notice and the date at the top. Big changes are announced in the app, on WhatsApp and to schools before they take effect.

## Contact

**support@magana.ng** · Magana team, Nigeria
