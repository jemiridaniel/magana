# Accessibility note

What we tested with people, what they told us, what we changed, and what is still to do. It follows the organisers' outline. The evidence is in [FINDINGS.md](FINDINGS.md) (newest first) and [TALKBACK_AUDIT.md](TALKBACK_AUDIT.md). Our accessibility targets (WCAG 2.2 AA, 7:1 contrast, 64 px targets) are in [ACCESSIBILITY.md](ACCESSIBILITY.md).

**Important:** no blind or low-vision person has tested Magana yet. Everything below comes from sighted team members and from emulator checks. FINDINGS says the same at the top.

_Last updated 28 October 2026._

## 1. Who tested

| Who | Background | How | Build |
| --- | --- | --- | --- |
| Nurse Oluremi O. Balogun | RN/RM/RPHN; user research and safeguarding on the team | **Sighted, testing with her eyes closed to simulate blindness**, on her Android phone with TalkBack on. About 20 hours of use. Then a voice-note review and a written review. | Android 0.1.0+7 (27 Oct 2026) |
| Dr. Oluba Amos | Clinical pharmacist; signs off health safety rules | Photographed faint print and handwriting. | 0.1.0+7 and earlier |
| The developer | | TalkBack audit of the core journey on the Android emulator (API 36, TalkBack 16), 27–28 Oct 2026. | 0.1.0+12 and the fixes after it |

A sighted person with closed eyes is not the same as a blind user. She knows where things are on a screen, and she has not spent years using a screen reader. Her findings are real problems, but they are not a measure of how blind users will do.

## 2. The tasks

The tester page, [magana.ng/test](https://magana.ng/test), gives six tasks:
1. Read an English page.
2. Read a page with two columns.
3. Read a page with a table.
4. Read a Hausa, Yorùbá or Igbo page.
5. Read a page in airplane mode.
6. Read a medicine label.

Every task can also be started by voice ("Speak a command" on each screen). Problems are sent from the app with "Report a problem".

## 3. What they said, and what we changed

### From Nurse Balogun's testing (0.1.0+7)

| What she found | What we did | Status |
| --- | --- | --- |
| "The TalkBack voice command isn't working… I could not use this app if I was blind." | A full TalkBack audit of the core journey ([TALKBACK_AUDIT.md](TALKBACK_AUDIT.md)), fixes in commit `901b6f5`: voice commands no longer hang on "Listening…" on phones without an on-device English model; the microphone and Magana's own voice wait until TalkBack is quiet; Magana stops talking when TalkBack moves to a control; focus lands on each screen's title; Android Back in onboarding goes back one step instead of closing the app; language and class choices are real radio buttons. | Checked on the emulator. **Not yet tried by her on a phone.** Recognising a real spoken command could not be tested on the emulator (no microphone sound). |
| No useful answer when a command wasn't understood | "Sorry, I didn't catch that. Say “read a page” or “help”." when nothing is heard and when the words aren't a command (`901b6f5`). Hausa, Yorùbá and Igbo wording are drafts. | Checked on the emulator |

### From Dr. Amos's photos

| What he found | What we did | Status |
| --- | --- | --- |
| Faint print and handwriting both got "unclear" | **Faint print:** darkened and read again on the server, and on the phone too from 0.1.0+8. In 0.1.0+8 the faintest small label no longer gets "Some of this page looks handwritten". On health papers the strict handwriting check still treats the faintest print as handwriting and says "ask the pharmacist". That is the safe side, so we left it until we see his own photo. | Measured on synthetic labels (FINDINGS, 28 Oct) |
| | **Handwriting:** "This looks handwritten. Read it anyway?" was built for schoolwork only, with every number held back. Measured on 26 handwritten lesson notes, at most 24% (Android) or 48% (iPhone) of the words read were dictionary words, so it is **switched off** until it is measured against typed transcripts. Offline on the iPhone, numbers on health papers are now held, because Apple Vision is confident about handwriting (73 of 89 handwritten number lines at 0.90 or more). | Built, off. The iPhone hold is a draft for Dr. Amos. |

### From her latest voice note: in build 0.1.0+13 (not yet tested by her)

| What she asked for | What is being built |
| --- | --- |
| Better voices | Hausa, Yorùbá and Igbo are never read with an English voice; the best installed voice is chosen, with a choice in Settings → Voice; recorded prompts. |
| Commands from a Bluetooth headset | Voice commands through a Bluetooth headset. |
| More time to speak | A 25-second listening limit. (In the code as of this note, a command listens for up to 10 s, with a 16 s safety stop.) |
| Knowing what to do | A 60-second guided tour, and "What can I say?" on every screen. |
| Wrong document types | Magana never announces a document type it has only guessed. |
| Team setup wording | Clearer wording in team setup. |

### From her written review: in build 0.1.0+13 (not yet tested by her)

| What she asked for | What is being done |
| --- | --- |
| It must install on older, cheaper phones | A universal Android build that includes 32-bit phones. Builds up to 0.1.0+12 published the 64-bit (arm64) APK only. |
| "Ask a Nurse" promises something we can't give yet | "Talk to a health worker" replaces "Ask a Nurse" while the AI health assistant (Ibà) is not running in the test phase. |
| Others should be able to check our work | Reproducibility docs: "Build and test it yourself" in the [README](../README.md), and [ARCHITECTURE.md](ARCHITECTURE.md). Done in this commit. |

## 4. What is still to do

- **Testing with blind and low-vision users.** This is the most important gap. The user testing table in FINDINGS is still empty.
- **Nurse Balogun on a real phone** with the 0.1.0+13 fixes and TalkBack on, including real spoken commands ("read a page", "everyday papers", "help").
- **A full VoiceOver pass by a person** on the iPhone build and the website.
- **Native-speaker review** of all Hausa, Yorùbá and Igbo text and voices: app strings, number and unit words (`content/number_words/`), and the voice choice. Four Igbo medicine-label templates are still read in English.
- **Clinical sign-off** (Dr. Amos, and Nurse Balogun where marked):
  - the number thresholds: 0.90 per number, or two agreeing readings each at 0.80 or more;
  - the iPhone offline hold on numbers on health papers;
  - the handwriting rules for health papers (`docs/review/handwriting_signoff.md`);
  - the quick check: questions, "I can't tell", the sight-based questions and the danger signs;
  - reading schoolwork while a Guided learner waits for guardian consent (Nurse Balogun).
- **Handwriting:** type 5 to 10 lesson notes as transcripts and measure word accuracy before turning it on.
- **Lessons and quizzes:** every lesson and quiz is a team-written draft. A teacher and a rehabilitation trainer are to review them ([docs/review/content-review.xlsx](review/content-review.xlsx)).
