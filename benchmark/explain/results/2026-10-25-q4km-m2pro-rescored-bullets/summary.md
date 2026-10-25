# Explanation benchmark: llamacpp NCAIR1/N-ATLaS (placeholders + templates)

N-ATLaS base model, QuantFactory Q4_K_M GGUF (sha256 71de156e...), llama.cpp on an Apple M2 Pro (Metal), temperature 0.1, repeat penalty 1.12. New design: schoolwork with numbers as placeholders and the strict check; health and money pages never sent to the model (phrase templates). Team-written test pages only. Re-scored from 2026-10-24-q4km-m2pro-placeholders: markers left out are allowed when nothing numeric was added.

| Language | School pages | Blocked | Passed (numbers left out) | Block reasons | Paper pages: model calls | Paper sentences: approved / drafts would cover / total |
|---|---|---|---|---|---|---|
| en | 5 | 4 | 1 (1) | digit 2, number_word 1, placeholder_repeated 1, unit_word 2 | 0 | 37 / — / 37 |
| ha | 5 | 1 | 4 (2) | digit 1, number_word 1, unit_word 1 | 0 | 0 / 6 / 57 |
| yo | 5 | 5 | 0 (0) | digit 5, number_word 3, unit_word 2 | 0 | 0 / 6 / 57 |
| ig | 5 | 2 | 3 (1) | digit 1, number_word 2, unit_word 1 | 0 | 0 / 6 / 57 |

Unreviewed: fluency and faithfulness need native-speaker ratings (ratings_<lang>.csv).
