"""Closed-set answers: which of the allowed answers did the learner say?

Free transcription of a one-syllable answer ("bí") is unreliable: Whisper hears "e?" or
makes up a sentence (docs/FINDINGS.md, quiz-answer test). For a quiz answer we know the
few things the learner may say, so instead of transcribing we score the audio against each
allowed answer's spoken forms (content/answers/closed_sets.json: the letter names in the
UI language and in English, yes/no, true/false; needs native review) and pick the best.

Each form is scored as a whole Whisper transcript, from <|startoftranscript|> to
<|endoftext|>, so a short form is not favoured just for being short. An answer's score
combines its forms (log-sum-exp), and the confidence is a softmax over the answers. Below
MIN_CONFIDENCE the result is "unclear" and Magana asks again; whatever the confidence, the
app still asks "You said B. Is that right?" before anything counts.
"""
from __future__ import annotations

import json
import math
from functools import lru_cache

from .placeholders import content_dir

KINDS = ("letters", "yes_no", "true_false")
LETTERS = "ABCD"
# Chosen before the closed-set test was run, not tuned on it (docs/FINDINGS.md).
MIN_CONFIDENCE = 0.6
# Whisper's language tokens; it has no Igbo token, so Igbo is not forced.
WHISPER_TOKEN = {"en": "<|en|>", "ha": "<|ha|>", "yo": "<|yo|>", "ig": None}


@lru_cache(maxsize=1)
def _sets() -> dict:
    return json.loads((content_dir() / "answers" / "closed_sets.json").read_text(encoding="utf-8"))


def choices(kind: str, lang: str, count: int = 4) -> dict[str, list[str]]:
    """answer -> its spoken forms, in the UI language and in English (no duplicates)."""
    if kind not in KINDS:
        raise ValueError(kind)
    sets = _sets()[kind]
    if kind == "letters":
        answers = list(LETTERS[:max(2, min(count, 4))])
    else:
        answers = list(sets["en"])
    out = {}
    for a in answers:
        forms = list(dict.fromkeys([*sets.get(lang, {}).get(a, []), *sets["en"][a]]))
        out[a] = forms
    return out


def decide(form_scores: dict[str, list[float]]) -> tuple[str | None, float, dict[str, float]]:
    """(answer or None if below MIN_CONFIDENCE, its confidence, every answer's confidence)."""
    combined = {a: _logsumexp(s) for a, s in form_scores.items()}
    top = max(combined.values())
    weights = {a: math.exp(v - top) for a, v in combined.items()}
    total = sum(weights.values())
    conf = {a: w / total for a, w in weights.items()}
    best = max(conf, key=conf.get)
    return (best if conf[best] >= MIN_CONFIDENCE else None), conf[best], conf


def _logsumexp(xs: list[float]) -> float:
    m = max(xs)
    return m + math.log(sum(math.exp(x - m) for x in xs))


def score_forms(pipe, samples, lang: str, forms: list[str]) -> list[float]:
    """Log-probability of each form as the whole transcript of [samples] (16 kHz mono)."""
    import torch

    model, fe, tok = pipe.model, pipe.feature_extractor, pipe.tokenizer
    feats = fe(samples, sampling_rate=16000, return_tensors="pt").input_features.to(model.dtype)
    prefix = [tok.convert_tokens_to_ids("<|startoftranscript|>")]
    if WHISPER_TOKEN[lang]:
        prefix.append(tok.convert_tokens_to_ids(WHISPER_TOKEN[lang]))
    prefix += [tok.convert_tokens_to_ids("<|transcribe|>"), tok.convert_tokens_to_ids("<|notimestamps|>")]
    eot = tok.eos_token_id
    # Whisper writes a leading space before the first word; try both spellings.
    variants = [(i, v) for i, f in enumerate(forms) for v in (f, " " + f)]
    seqs = [prefix + tok(v, add_special_tokens=False).input_ids + [eot] for _, v in variants]
    width = max(map(len, seqs))
    inputs = torch.tensor([s[:-1] + [eot] * (width - len(s)) for s in seqs])
    with torch.no_grad():
        enc = model.get_encoder()(feats)
        hidden = enc.last_hidden_state.expand(len(seqs), -1, -1)
        logits = model(encoder_outputs=(hidden,), decoder_input_ids=inputs).logits.float()
    logp = torch.log_softmax(logits, dim=-1)
    best = [-math.inf] * len(forms)
    for row, ((i, _), s) in enumerate(zip(variants, seqs)):
        total = sum(logp[row, pos - 1, s[pos]].item() for pos in range(len(prefix), len(s)))
        best[i] = max(best[i], total)
    return best
