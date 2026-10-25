# Magana accessibility statement

Magana is made for blind and low-vision people, so accessibility is how it works, not an extra. This statement covers the website (magana.ng), the Android app, the web version (app.magana.ng) and the teacher portal (teachers.magana.ng).

**Contact:** maganasupport@gmail.com. Tell us what you were trying to do, on which page or screen, and with which screen reader or browser. We reply within 5 working days.

## What we aim for

- **WCAG 2.2 level AA**, and stricter than AA in two places:
  - **Text contrast of at least 7:1** (AA asks for 4.5:1).
  - **Buttons and form fields at least 64 pixels tall** (AA asks for 24).
- **Screen readers first:** TalkBack on Android, VoiceOver on iPhone and Mac, NVDA and JAWS on Windows. Every page has a "Skip to main content" link, real headings and labelled landmarks.
- **One action, one voice command** in the app: everything you can tap, you can also say.
- **Atkinson Hyperlegible**, a typeface designed for low-vision readers, at 20 px or larger for body text.
- **Reduced motion:** with "Reduce motion" on, the page loader and the Braille dots appear without animation.
- **No time limits, no flashing content, no cookies or trackers.**

## How we check

Every release of the website is checked with:

- **axe** (automatic WCAG A and AA rules, plus the 7:1 contrast rule) at desktop (1280 px) and phone (390 px) widths, on every page;
- our own check that every button and form field is at least 64 px tall;
- **Lighthouse** accessibility;
- a pass with a screen reader;
- the page loader timed on a slow (3G) connection.

**Latest results (25 October 2026):** axe found no problems on any page at either width. Every button and field is at least 64 px tall. Lighthouse accessibility scores 100 on every page. On a slow 3G connection the loader appears within 2.6 to 3.7 seconds and the page is ready in about 12 seconds. A full VoiceOver pass by a person is still to come. Details are in the project's findings log (docs/FINDINGS.md).

## Known limits

- **The website is in English only for now.** Hausa, Yorùbá and Igbo translations are coming. The app itself already speaks all four languages.
- **"Hear a sample" uses your browser's own voice.** Some browsers have no Nigerian English voice, so another English voice is used.
- **Braille:** "Your name in Braille" supports the letters a to z (uncontracted Braille). Numbers, punctuation and other letters show "not yet supported".
- **The iPhone app** isn't available yet. Until then, the web version works in Safari with VoiceOver.

## If something doesn't work for you

Email **maganasupport@gmail.com**. If you can't use a part of Magana, we will help you another way, for example by reading a document to you over the phone.

*Last reviewed: 25 October 2026.*
