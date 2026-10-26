# Hausa, Yorùbá and Igbo letters (board 5d)

`ha.json`, `yo.json`, `ig.json`: 10 extracts per language (first 1,400 characters) from Hausa,
Yorùbá and Igbo Wikipedia, chosen because they hold the special letters (ɓ ɗ ƙ ƴ; ẹ ọ ṣ and tone
marks; ị ọ ụ ṅ). Each entry keeps its article's title and link. Licence: **CC BY-SA 4.0**,
Wikipedia contributors (docs/DATA_SOURCES.md, S35). These articles are left out of the word
lists in `content/word_lists/`, so the letter check is not scored on its own sources.

`backend/scripts/letter_ocr_test.py` draws each page (clean and phone-like) and reports what
each OCR model does to each letter; `--pipeline` scores Magana's letter check end to end.
