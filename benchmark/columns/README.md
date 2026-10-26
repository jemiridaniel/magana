# Two-column reading order (board 5c)

`pages.json`: 10 team-written, textbook-style two-column pages (a full-width title, then a heading
and a paragraph in each column). Team-made, so they may go in the published benchmark.

`backend/scripts/column_order_test.py` draws each page at about 300 dpi, clean and made
phone-like, reads it, and scores the reading order. It also checks that the 10 one-column pages
in `benchmark/explain/pages` are read in exactly the same order as before.

**Real photos:** put photos of real two-column textbook pages (no learner names) in a folder,
each with a `.txt` file of the same name holding the page's text in the right reading order,
one line of the page per line, and run the script with `--photos <folder>`.
