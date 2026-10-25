"""Build the website's "Hear a sample" pages: three team-made pages (CC BY 4.0, Magana team),
drawn here, read by the real Magana backend (local Tesseract), and saved with exactly what the
app would show and say: an unreliable number becomes "unclear number", then the warning.

    backend/.venv/bin/python website/scripts/make_samples.py

Writes website/public/samples/*.png and website/data/samples.json. Re-run it when the reader
changes; the website itself makes no API calls.
"""
from __future__ import annotations

import io
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

FONT = ROOT / "backend" / "tests" / "fixtures" / "fonts" / "DejaVuSans.ttf"
ARB = json.loads((ROOT / "app" / "lib" / "l10n" / "app_en.arb").read_text())
NUMBER_CODES = {"unreadable_number", "low_confidence_number", "number_mismatch"}  # app/lib/api.dart


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), size)


def page(lines: list[tuple[str, int, bool]], width: int = 1400, blur: dict | None = None) -> Image.Image:
    """lines: (text, size, bold-ish). blur: {line index: (from x, to x, radius)} to smudge part of a line."""
    h = 90 + sum(s + 46 for _, s, _ in lines)
    img = Image.new("RGB", (width, h), (250, 248, 240))
    d = ImageDraw.Draw(img)
    y = 60
    tops = []
    for text, size, strong in lines:
        tops.append(y)
        d.text((70, y), text, fill=(20, 23, 26), font=font(size), stroke_width=1 if strong else 0, stroke_fill=(20, 23, 26))
        y += size + 46
    for i, (x0, x1, r) in (blur or {}).items():
        box = (x0, tops[i] - 12, x1, tops[i] + lines[i][1] + 16)
        img.paste(img.crop(box).filter(ImageFilter.GaussianBlur(r)), box[:2])
    return img


SAMPLES = [
    {
        "id": "medicine",
        "title": "Medicine label",
        "mode": "health",
        "alt": "Photo of a medicine box label. Paracetamol 500 mg tablets. Take 1 to 2 tablets every 4 to 6 hours. "
               "The next line, about the most you may take in 24 hours, has a smudged number. Then a storage line and the expiry date.",
        "lines": [("PARACETAMOL 500 mg TABLETS", 46, True), ("Take 1 to 2 tablets every 4 to 6 hours", 36, False),
                  ("Do not take more than 8 in 24 hours", 36, False), ("Keep out of the reach of children", 36, False),
                  ("Expiry 08/2027   Batch PCM2291", 36, False)],
        # The "8" on the third line, smudged (its x range for this font and size).
        "blur": {2: (484, 518, 3.0)},
    },
    {
        "id": "school",
        "title": "School question",
        "mode": "school",
        "alt": "Photo of a printed JSS 2 mathematics question: a farmer plants 24 rows of maize with 15 plants in each row. "
               "How many plants are there altogether?",
        "lines": [("JSS 2 Mathematics: Multiplication", 42, True), ("A farmer plants 24 rows of maize.", 36, False),
                  ("Each row has 15 plants.", 36, False), ("How many plants are there altogether?", 36, False)],
    },
    {
        "id": "bank",
        "title": "Bank statement",
        "mode": "money",
        "alt": "Photo of part of a sample bank statement with an opening balance, two transactions on 3 and 5 October 2026, "
               "and the closing balance.",
        "lines": [("SAMPLE BANK PLC   Account statement", 42, True), ("Opening balance 01/10/2026   NGN 0.00", 34, False),
                  ("03/10/2026   Transfer from A. Bello   NGN 15,000.00", 34, False),
                  ("05/10/2026   POS purchase   NGN -2,350.00", 34, False), ("Closing balance 31/10/2026   NGN 12,650.00", 34, False)],
    },
]


def message(code: str, line: int) -> str:
    text = ARB.get(f"msg_{code}") or ARB["msg_low_confidence"]
    return text.replace("{where}", ARB["whereLine"].replace("{number}", str(line)))


def main() -> None:
    client = TestClient(app)
    out = []
    for s in SAMPLES:
        img = page(s["lines"], blur=s.get("blur"))
        buf = io.BytesIO()
        img.save(buf, "PNG", optimize=True)
        (ROOT / "website" / "public" / "samples" / f"{s['id']}.png").write_bytes(buf.getvalue())
        body = client.post("/read", data={"mode": s["mode"]}, files={"file": ("p.png", buf.getvalue())}).json()
        codes: dict[int, list[str]] = {}
        unclear: dict[int, set[int]] = {}
        for w in body["warnings"]:
            codes.setdefault(w["block_index"], []).append(w["code"])
            if w["code"] in NUMBER_CODES and isinstance(w.get("word_index"), int):
                unclear.setdefault(w["block_index"], set()).add(w["word_index"])
        lines = []
        for i, line in enumerate(body["lines"]):
            words = [w["text"] for w in line["words"]] or line["text"].split()
            shown = " ".join("[unclear number]" if j in unclear.get(i, ()) else w for j, w in enumerate(words))
            said = " ".join(ARB["unclearNumber"] if j in unclear.get(i, ()) else w for j, w in enumerate(words))
            c = codes.get(i, [])
            code = next((x for x in c if x in NUMBER_CODES), c[0] if c else None)
            warning = message(code, i + 1) if code else None
            lines.append({"shown": shown, "said": ". ".join(x for x in (said, warning) if x), "warning": warning})
        out.append({"id": s["id"], "title": s["title"], "alt": s["alt"], "width": img.width, "height": img.height,
                    "lines": lines})
        print(s["id"], json.dumps(lines, ensure_ascii=False, indent=1))
    (ROOT / "website" / "data" / "samples.json").write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")


if __name__ == "__main__":
    main()
