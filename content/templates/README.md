# Phrase templates for health and money papers

Health and money papers are never explained by a model. Instead, each line is matched against approved phrase templates. A template's number slots (`{a}`, `{b}` …) take the page's exact text, so the model never writes a number or a unit.

```json
{ "id": "not_more_than_in_hours",
  "en": ["Do not take more than {a} tablets in {b} hours"],
  "translations": { "ha": { "text": "Kada ka sha fiye da ƙwaya {a} cikin sa'o'i {b}.", "status": "draft" } } }
```

- **`en`:** the English forms that match (case and spacing ignored, a final full stop optional). A slot matches one number token as printed (`1`, `500`, `08/2027`, `12.5`).
- **`status`**, per translation:
  - `draft`: written, not yet checked;
  - `native_reviewed`: checked by a native speaker;
  - `clinically_approved`: health only, signed off by the clinical lead after native review (`approved_by`, `approved_on`). Reviewers' names are kept privately until they agree to be credited.
- **Which are used:**
  - **health:** only `clinically_approved`;
  - **money and letters:** `native_reviewed` or `clinically_approved`.
- **Anything without a usable template** is read in English, as printed, followed by "I can't translate this line safely. Please ask a pharmacist." (health), or "…Please ask someone at your bank." (money and letters).
- Every translation must use exactly the slots of its English forms (a test checks).

| File | Domain | Phrases | Status |
|---|---|---|---|
| `medicine_label.json` | health | 15 common medicine-label phrases | **clinically approved** 25/10/2026 (clinical lead) in Hausa and Yorùbá (15 each) and Igbo (11). Igbo #7, #9, #12, #13 are `native_reviewed` and read in English until the Igbo reviewer adds tone marks (and fixes #9's meaning) |
