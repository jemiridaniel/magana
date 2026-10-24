"""Drive the Magana app on the Android emulator the way a TalkBack user does.

Touches go through the emulator console (`event mouse`), which TalkBack sees as a real
finger: a single touch moves TalkBack focus, a fast double tap activates the focused item,
a one-finger swipe moves to the next item. (adb `input tap` does not drive TalkBack
reliably.) Controls are found by their accessibility label via `uiautomator dump`.

Two pitfalls, measured on the emulator (see docs/FINDINGS.md, 2026-10-24):
- Right after a `uiautomator dump`, a touch can reach the app as a plain click. `tb()`
  therefore waits 2.5 s between finding a control and touching it.
- Dumping the screen cuts off the app's speech. Don't poll `labels()` while checking
  continuous reading; wait, then look once.

Usage:
    python3 tools/talkback/talkback.py talkback on|off
    python3 tools/talkback/talkback.py labels
    python3 tools/talkback/talkback.py tb "Practice quiz"
    python3 tools/talkback/talkback.py next
    python3 tools/talkback/talkback.py shot home.png
"""
import os
import re
import socket
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ADB = os.environ.get("ADB", os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"))
CONSOLE_PORT = int(os.environ.get("EMULATOR_CONSOLE_PORT", "5554"))
PACKAGE = "com.magana.app"
TALKBACK = "com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService"


def sh(*args, binary=False):
    out = subprocess.run([ADB, *args], capture_output=True, timeout=60)
    return out.stdout if binary else out.stdout.decode(errors="replace")


# ---------- reading the screen

def nodes():
    """Every node on screen: label (content-desc or text), bounds, package."""
    raw = ""
    for _ in range(5):
        sh("shell", "uiautomator", "dump", "/sdcard/ui.xml")
        raw = sh("exec-out", "cat", "/sdcard/ui.xml")
        if raw.strip().startswith("<?xml"):
            break
        time.sleep(1)
    out = []
    for n in ET.fromstring(raw).iter("node"):
        b = [int(v) for v in re.findall(r"\d+", n.get("bounds", "[0,0][0,0]"))]
        out.append({"label": n.get("content-desc") or n.get("text") or "", "bounds": b,
                    "pkg": n.get("package"), "checked": n.get("checked") == "true"})
    return out


def labels():
    """The app's labelled nodes, in screen order."""
    return [(n["label"], n["bounds"]) for n in nodes() if n["label"] and n["pkg"] == PACKAGE]


def find(label, timeout=15):
    """The first node whose label is `label` (or starts with it, then a new line)."""
    end = time.time() + timeout
    while time.time() < end:
        for n in nodes():
            if n["label"] == label or n["label"].startswith(label + "\n"):
                return n
        time.sleep(1)
    raise SystemExit(f"NOT FOUND: {label!r}\nlabels: {[n['label'] for n in nodes() if n['label']]}")


def center(n):
    x1, y1, x2, y2 = n["bounds"]
    return (x1 + x2) // 2, (y1 + y2) // 2


def screen_size():
    m = re.search(r"(\d+)x(\d+)", sh("shell", "wm", "size"))
    return (int(m[1]), int(m[2])) if m else (1080, 2400)


def shot(path):
    with open(path, "wb") as f:
        f.write(sh("exec-out", "screencap", "-p", binary=True))


# ---------- touching it like a finger

def _console():
    s = socket.create_connection(("127.0.0.1", CONSOLE_PORT))
    s.settimeout(2)
    token = open(os.path.expanduser("~/.emulator_console_auth_token")).read().strip()
    time.sleep(0.2)
    s.recv(4096)
    s.sendall(f"auth {token}\n".encode())
    time.sleep(0.2)
    s.recv(4096)
    return s


def touch(x, y):
    """One touch: with TalkBack on, moves focus to what is under the finger."""
    s = _console()
    s.sendall(f"event mouse {x} {y} 0 1\n".encode())
    time.sleep(0.05)
    s.sendall(f"event mouse {x} {y} 0 0\n".encode())
    time.sleep(0.2)
    s.close()


def double_tap(x, y):
    """Both taps within ~120 ms over one connection: activates the focused item."""
    s = _console()
    for state in (1, 0, 1, 0):
        s.sendall(f"event mouse {x} {y} 0 {state}\n".encode())
        time.sleep(0.03)
    time.sleep(0.2)
    s.close()


def swipe(x1, y1, x2, y2, steps=8, ms=160):
    s = _console()
    s.sendall(f"event mouse {x1} {y1} 0 1\n".encode())
    for i in range(1, steps + 1):
        time.sleep(ms / 1000 / steps)
        s.sendall(f"event mouse {x1 + (x2 - x1) * i // steps} {y1 + (y2 - y1) * i // steps} 0 1\n".encode())
    s.sendall(f"event mouse {x2} {y2} 0 0\n".encode())
    time.sleep(0.2)
    s.close()


def tb(label, settle=1.0):
    """A TalkBack user: touch the control to focus it, then double tap to activate it."""
    time.sleep(settle)
    x, y = center(find(label))
    time.sleep(2.5)  # see the module docstring: a touch right after a dump is a plain click
    touch(x, y)
    time.sleep(1.2)
    double_tap(x, y)


def tb_at(x, y):
    """Like tb(), for a control found some other way (e.g. a system dialog's button)."""
    time.sleep(2.5)
    touch(x, y)
    time.sleep(1.2)
    double_tap(x, y)


def tb_next():
    """Swipe right: TalkBack moves to the next item (and scrolls to it)."""
    w, h = screen_size()
    swipe(w * 28 // 100, h // 2, w * 74 // 100, h // 2 + 10)


def scroll_to(label, tries=4, swipes=3):
    """Bring a control below the fold on screen, as a TalkBack user would: focus the lowest
    item in the scrolling body, then swipe right a few times (TalkBack scrolls to keep focus
    visible). Don't dump the screen between swipes: a dump resets TalkBack focus."""
    _, h = screen_size()
    for _ in range(tries):
        here = [n for n in nodes() if n["label"] and n["pkg"] == PACKAGE]
        if any(n["label"] == label or n["label"].startswith(label + "\n") for n in here):
            return
        body = [n for n in here if n["bounds"][3] < h * 0.7]  # above the pinned buttons
        x, y = center(max(body, key=lambda n: n["bounds"][3]))
        time.sleep(2.5)
        touch(x, y)
        for _ in range(swipes):
            time.sleep(1.5)
            tb_next()
        time.sleep(1)
    raise SystemExit(f"could not scroll to {label!r}")


def tb_activate_focused():
    w, h = screen_size()
    double_tap(w // 2, h // 2)


def talkback(on):
    sh("shell", "settings", "put", "secure", "enabled_accessibility_services", TALKBACK if on else '""')
    sh("shell", "settings", "put", "secure", "accessibility_enabled", "1" if on else "0")


if __name__ == "__main__":
    cmd, *rest = sys.argv[1:] or ["labels"]
    if cmd == "labels":
        for label, b in labels():
            print(f"{b[2] - b[0]}x{b[3] - b[1]}  {label!r}")
    elif cmd == "tb":
        tb(rest[0])
    elif cmd == "next":
        tb_next()
    elif cmd == "shot":
        shot(rest[0])
    elif cmd == "talkback":
        talkback(rest[0] == "on")
    else:
        raise SystemExit(__doc__)
