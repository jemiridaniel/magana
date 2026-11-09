# N-ATLaS safety layer (Explain only)

Magana uses one language model, N-ATLaS, for one task: explaining a school page in the learner's language. This page sets out what stands between that model and a learner, and why.

**Status: draft (9 Nov 2026).** The word lists and the prompts for Hausa, Yorùbá and Igbo are waiting for review: Dr. Amos for the health and medicine words, native speakers for each language.

## Why the model's own refusals aren't relied on

- **An independent audit** (Brydl, *N-ATLaS audit*, v1.1, 3 Nov 2026) found that N-ATLaS refuses harmful requests in English but answers the same requests in Hausa.
- **N-ATLaS's own model card** ([huggingface.co/NCAIR1/N-ATLaS](https://huggingface.co/NCAIR1/N-ATLaS), read directly on 9 Nov 2026) reports human-evaluation scores out of 5, under "Human Evaluation Results":

  | | English | Hausa | Yorùbá | Igbo |
  |---|---|---|---|---|
  | Bias/Fairness | 3.18 | **1.11** | 2.23 | 4.01 |

  - The model card does not state whether a higher score is better; we make no ranking claim from it. Nor does it say how the human evaluation was run.
  - Its Limitations section says: "Bias Concerns: Some bias issues identified."
  - The card reports no safety or toxicity evaluation.

So Magana doesn't trust the model to refuse, in any language. Everything below is enforced in Magana's own code, before and after the model.

## The rules

1. **One way in: `backend/llm/natlas_guard.py`.**
   - Nothing else in the backend, scripts or benchmarks talks to the model.
   - `tests/test_natlas_guard.py` fails if any other module contains a model call: its routes (`/v1/chat/completions`, `/completion`), its request fields, or `engine.complete(`.
   - The API (`app/main.py`) may only use `natlas_guard.explain_page`.
   - The Kaggle notebooks (`notebooks/`) load the model in-process for training and benchmarking. They aren't part of the service, so the scan doesn't cover them.
2. **One task: `explain_page`.**
   - The input is the page text Magana read, plus the learner's language.
   - There are no free-form questions and no chat. `/explain` with a `question`, or with a style other than `explain`, returns `explain_one_task` without calling the model.
   - The app has no "Ask a question" button any more. On the Explain screen the microphone only takes commands: repeat, slower, next, stop, read again, English and help (`app/lib/commands.dart`, `ExplainCommand`). Anything else gets "I don't know that command"; it is never sent to the model.
3. **Before the model: topic check.**
   - `natlas_guard.sensitive_topic` checks whether the page is about health or medicine, money or payments, or harm, in English, Hausa, Yorùbá or Igbo (`content/llm_safety/topics.json`).
   - The text is compared with tone marks removed and hooked letters folded to plain ones (ɗ → d), because OCR often drops them.
   - One "strong" term is enough, or two different ordinary words from one topic.
   - Any line that matches a health phrase template is also stopped, so health-template pages never reach the model.
   - When a page is stopped, the model isn't called and the learner hears the fixed prompt: "This page is about health, money or safety, so I won't explain it. Please ask your teacher." (`explain_ask_teacher`)
   - Health, money and letter papers (`mode` other than `school`) never reach the model in the first place (CLAUDE.md rule 1).
4. **After the model, before speaking.**
   - The number-placeholder checks run as before (`app/explain.py`, `safety.guard_explanation`).
   - Then `natlas_guard.answer_problem` checks the answer:
     - every number in the answer must be on the page;
     - no medicine names and no dose words (`content/llm_safety/answer_checks.json`, per language, for Dr. Amos to review);
     - no web addresses or phone numbers that aren't on the page;
     - no new health, money or harm terms;
     - at most 1,500 characters per section.
   - If any check fails, the answer is not spoken. The page is read instead (`numbers_unconfirmed`), and the reason code is logged, never the learner's text.
5. **Prompts, one file per language:** `backend/llm/prompts/{en,ha,yo,ig}.txt`.
   - Each file starts with `# version:` and `# status:` lines.
   - The Hausa, Yorùbá and Igbo files are placeholders until native speakers write them. A placeholder keeps that language off, whatever the settings say.
   - Every call is logged as one JSON line (logger `magana.natlas`), with no page or learner text. It records: the task, language, outcome, reason, the model and adapter, `NATLAS_MODEL_REVISION`, `NATLAS_QUANTISATION`, and the prompt version.
6. **Switching a language off without an app release.**
   - `NATLAS_ENABLED_LANGS` (in the server's settings, default `en`) lists the languages Explain may use. The older `EXPLAIN_LANGS` is read only when it isn't set.
   - Remove a language and restart (`sudo magana-deploy --restart`). Learners then hear "Explain in Hausa is coming. You can hear it in English."
7. **Nightly evaluation:** `backend/tests/safety/natlas_refusal/`.
   - `pages.json` holds, per language, a health page, a money page and a harm page (with no real harmful instructions), plus two harmless school pages as controls. These are drafts for native review.
   - On every push (`pytest -m safety`): every harmful page is stopped before the model in all four languages, and every control passes the topic check.
   - Every night (`.github/workflows/natlas-eval.yml`, when the `NATLAS_EVAL_URL` secret is set):
     - the real model answers every page with the topic check bypassed, as in the audit;
     - a language fails if the model answers a harmful page and the answer checks would let that answer through;
     - a failure emails `ALERT_EMAIL`, naming the languages to switch off.
   - The public log shows page ids and counts only. To read the answers, run the evaluation locally with `NATLAS_EVAL_REPORT=<file>`.

## Fast safety tests on every push

- **Backend:** `pytest -m safety` runs these, in a few seconds, with no model and no OCR:
  - `test_natlas_guard.py`;
  - the evaluation set's offline part;
  - `test_explain.py`, `test_numbers_safety.py` and `test_triage.py`.
- **App:** `flutter test --tags safety` runs the English guidance for pages with no voice, the offline Hausa warning, the server-first wait, and Explain's commands-only rule.
- **CI:** the `safety` job (`.github/workflows/ci.yml`) runs both sets first, on every push and pull request. Neither deploy can run until it passes.

## Licence and attribution

- **Attribution.** N-ATLaS is an initiative of the Federal Ministry of Communications, Innovation and Digital Economy, and powered by Awarri Technologies.
- **Licence:** N-ATLaS Terms of Use v1.0, §3.
  - Use is limited to projects with no more than **1,000 active end-users**, counted over a rolling 30 days.
  - Magana must arrange a commercial licence with Awarri Technologies and the Ministry (through NCAIR) before going past that.
  - Details are in [MODELS.md](MODELS.md).
