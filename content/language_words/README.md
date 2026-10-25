# Language check word lists (DRAFT, needs native review)

Used by `backend/app/language.py` to refuse an explanation that isn't in the language the
learner asked for (for example the English-only Magana LoRA answering a Hausa request in
English). One word per line, lower case, `#` starts a comment. Each list holds very common
function words, with and without tone marks. A word that appears in two lists counts for
neither. `letters:` lines list characters only that language uses; `prefix:` lines, word beginnings (Igbo `na-`).

Reviewers: please add common words that are missing, and remove any that are also everyday
words in another of the four languages.
