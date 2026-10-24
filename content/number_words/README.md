# Number and unit words

Used by the explanation check (`backend/app/placeholders.py`). Before a schoolwork page goes to N-ATLaS, every number on it, with its unit or currency, is replaced by a placeholder: ⟦N1⟧, ⟦N2⟧ and so on. The model must copy each placeholder exactly once. An answer is rejected if it contains:

- any digit outside a placeholder;
- any word in `words` (number words and ordinals) or `units` (time, measure and money words), in any of the four languages;
- arithmetic between placeholders (`=`, `+`, `−`, `-`, `×`, `÷` …).

Matching ignores case. Tone marks, under-dots and hooked letters are ignored too (`ɗ` = `d`, `ọ` = `o`, `méjì` = `meji`), because the model often drops them. Words in `exact_only` are the exception: they only match with their marks, because without them they are other common words (Yorùbá `ogún` "twenty" vs `ogun` "war", `ọgbọ̀n` "thirty" vs `ọgbọ́n` "wisdom", `igba` "200" vs `ìgbà` "time").

`ambiguous_not_checked` lists number words that are also everyday words (Yorùbá `kan` "one, a", Igbo `otu` "one, a, same", Hausa `ɗaya` "one, single", `wata` "month, another"). They are **not** checked, so these numbers can slip through. Native reviewers should decide whether any can be checked safely.

Some checked words also have other meanings and will cause false alarms: Hausa `tara` (nine; also "gather"), Igbo `iri` (ten; also "eat"), `afọ` (year; also "belly"). A false alarm only means the page is read instead.

**Status: draft, needs native review** for every language (`review` in each file).
