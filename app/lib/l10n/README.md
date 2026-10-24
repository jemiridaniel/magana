# App strings

Every string the app shows or speaks lives here, one ARB file per language. `app_en.arb` is the template; `flutter gen-l10n` (run automatically by `flutter run` / `flutter test`) generates `app_localizations*.dart`.

| File | Status |
| --- | --- |
| `app_en.arb` | Source text |
| `app_ha.arb` | **Draft, needs native-speaker review** (Hausa) |
| `app_yo.arb` | **Draft, needs native-speaker review** (Yorùbá) |
| `app_ig.arb` | **Draft, needs native-speaker review** (Igbo) |

Each draft file carries an `@@x-review` note. Remove it only after a native speaker has checked every string.

## Notes for reviewers

- Most strings are spoken aloud as well as shown, so read them out loud. They should sound natural and be short.
- `framingGuidance` tells a blind user how to hold the phone over a page: keep the steps concrete.
- `unsureLine` / `unsureRow` are safety messages: they must clearly say "I'm not sure, please check or retake the photo", never guess.
- Keep `{placeholders}` exactly as they are. `{count, plural, …}` forms may need different wording per number.
- Language names (English, Hausa, Yorùbá, Igbo) are shown in their own language and are not translated.
- Yorùbá tone marks matter: please check every diacritic.

## Backend message codes

The backend never sends sentences: it sends codes (`too_dark`, `low_confidence_number`, `faint_region`, ...), listed with English reference wording in `backend/app/messages.py`. Each code has a string here named `msg_<code>`; a backend test fails if one is missing. Places are separate strings (`whereLine`, `whereCell`, `whereTop`, ...) so each language can order the sentence its own way.

The Ibà quick-check strings (`msg_q_*` questions, `msg_go_to_clinic_now`, `msg_nurse_call_*`) are **clinical drafts in all four languages**: Magana uses them when the Ibà service is unreachable. The question wording is copied from the Ibà service (iba-natlas `backend/app/questions.py`) so both say the same thing. Each needs Dr. Amos's clinical sign-off, and the Hausa, Yorùbá and Igbo versions a native speaker's check, before use with patients; their ARB descriptions say so.
