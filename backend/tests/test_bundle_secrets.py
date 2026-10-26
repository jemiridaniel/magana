"""scripts/check_bundle_secrets.py: what a shared APK, IPA or PWA may and may not carry."""
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[2] / "scripts"))
import check_bundle_secrets as c  # noqa: E402


def bundle(tmp_path, text: bytes) -> Path:
    p = tmp_path / "App.ipa"
    with zipfile.ZipFile(p, "w") as z:
        z.writestr("Payload/Runner.app/Frameworks/App.framework/App", b"\x00\xfe" + text + b"\x00")
    return p


def test_the_public_app_key_and_the_server_address_are_allowed(tmp_path):
    env = tmp_path / "app.env"
    env.write_text("MAGANA_API=https://api.magana.ng\nMAGANA_API_KEY=public-app-identifier-123\n")
    p = bundle(tmp_path, b"https://api.magana.ng public-app-identifier-123")
    assert c.check(p, c.known_secrets([env])) == []


def test_real_secrets_are_refused(tmp_path):
    env = tmp_path / "server.env"
    env.write_text("IBA_API_KEY=iba-very-secret-value\nMAGANA_API_KEY=public-app-identifier-123\n")
    cases = {
        b"AKIAABCDEFGHIJKLMNOP": "AWS access key",
        b"-----BEGIN PRIVATE KEY-----": "private key",
        b"hf_" + b"a" * 34: "Hugging Face token",
        b"EAA" + b"B" * 120: "Meta access token",
        b"iba-very-secret-value": "server.env IBA_API_KEY",
        b"EXPLAIN_API_KEY": "the name EXPLAIN_API_KEY",
    }
    for text, label in cases.items():
        problems = c.check(bundle(tmp_path, text), c.known_secrets([env]))
        assert any(label in p for p in problems), (text, problems)
    # The report names the problem, never the value.
    problems = c.check(bundle(tmp_path, b"iba-very-secret-value"), c.known_secrets([env]))
    assert not any("iba-very-secret-value" in p for p in problems)


def test_a_pwa_folder_is_checked_file_by_file(tmp_path):
    web = tmp_path / "web"
    (web / "assets").mkdir(parents=True)
    (web / "main.dart.js").write_text("const k='public-app-identifier-123';")
    (web / "assets" / "x.json").write_text("ASIAABCDEFGHIJKLMNOP")
    assert c.check(web, {}) == ["AWS access key in assets/x.json"]
