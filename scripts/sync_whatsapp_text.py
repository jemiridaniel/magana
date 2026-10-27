"""Copy the app's own wording into content/whatsapp/<lang>.json ("app" section), so WhatsApp
says the Ibà fallback questions and the call-back outcomes exactly as the app does
(app/lib/l10n/app_<lang>.arb, msg_<code>). backend/tests/test_whatsapp.py fails if they drift.

    backend/.venv/bin/python scripts/sync_whatsapp_text.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CODES_FROM_APP = ("go_to_clinic_now", "nurse_call_within_2_hours", "nurse_call_working_hours", "ask_someone_to_check",
                  "callback_booked", "callback_unavailable", "missed_line")


def app_section(lang: str) -> dict:
    arb = json.loads((ROOT / "app" / "lib" / "l10n" / f"app_{lang}.arb").read_text(encoding="utf-8"))
    codes = sorted(k.removeprefix("msg_") for k in arb if k.startswith("msg_q_")) + list(CODES_FROM_APP)
    return {code: arb[f"msg_{code}"] for code in codes}


def main() -> None:
    for lang in ("en", "ha", "yo", "ig"):
        path = ROOT / "content" / "whatsapp" / f"{lang}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["app"] = app_section(lang)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(lang, len(data["app"]), "app strings")


if __name__ == "__main__":
    main()
