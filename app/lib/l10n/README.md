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

Backend messages (capture tips like "It's quite dark") are still English and will move into these files when the backend returns codes instead of sentences.
