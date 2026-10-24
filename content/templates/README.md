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
  - `clinically_approved`: health only, signed off by Dr. Oluba Amos after native review.
- **Which are used:**
  - **health:** only `clinically_approved`;
  - **money and letters:** `native_reviewed` or `clinically_approved`.
- **Anything without a usable template** is read in English, as printed, followed by "I can't translate this line safely. Please ask a pharmacist." (health), or "…Please ask someone at your bank." (money and letters).
- Every translation must use exactly the slots of its English forms (a test checks).

| File | Domain | Phrases | Status |
|---|---|---|---|
| `medicine_label.json` | health | 15 common medicine-label phrases | all **draft**: on Dr. Amos's sign-off list (docs/FINDINGS.md) |
