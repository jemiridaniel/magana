# Handwriting: rules waiting for clinical sign-off

**For Dr. Amos (health rules) and Nurse Balogun (wording, privacy).** These are DRAFT. They are in the code
(`backend/app/handwriting.py`, `safety.py`) and tested on synthetic lines only. No real handwritten pages have
been measured yet (docs/FINDINGS.md).

| # | Rule | Where | Sign-off |
|---|---|---|---|
| 1 | A line is "handwritten" when the OCR's median word confidence is below 0.50, or below 0.70 while word heights or baselines vary by 18% or more. It errs towards "handwritten". | `handwriting.is_handwritten` | Thresholds to tune on 15–20 real pages |
| 2 | Every number on a handwritten line needs two agreeing independent readings, each at least 0.80. One confident reading is never enough. | `safety.number_warnings` | Dr. Amos |
| 3 | On a health paper, no number on a handwritten line is ever read: each is said as "unclear number" with "a handwritten number. I won't guess it: please ask the pharmacist or nurse." | `safety.handwritten_health` | **Dr. Amos** |
| 4 | A health paper with any handwriting starts with: "This looks like handwriting on a health paper. I won't read handwritten medicines or doses. Please ask the pharmacist or nurse to read it to you." | `messages.py` `handwritten_prescription` | **Dr. Amos**, Nurse Balogun (wording) |
| 5 | Handwritten or mixed pages say so first ("This page looks handwritten…", "Some of this page looks handwritten…"). | `handwritten_page`, `mixed_page` | Nurse Balogun (wording) |
| 6 | The optional handwriting readers (TrOCR on Magana's server; Azure Read at Microsoft) are for schoolwork only, never health, money or letters. Azure is for adults (18+) only. Both are off by default. | `main.handwriting_reader` | Nurse Balogun (privacy, PRIVACY.md) |
| 7 | A teacher's handwritten upload stays at "Check" until the teacher corrects and approves its text. Learners get only approved text. | portal Uploads, Check | Nurse Balogun |

Questions for Dr. Amos:
- Should rule 3 also cover printed labels with a handwritten dose added by hand (a common pharmacy practice)? Today
  only the handwritten line's numbers are withheld; the printed numbers are still read.
- Is "ask the pharmacist or nurse" the right hand-off, or should it name the prescriber?
