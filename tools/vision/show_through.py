"""The phone's show-through rule (offline_reader.dropShowThrough, MaganaChannels.inkDepth) on
Vision's word boxes, in Python: how many words and lines it drops. Counts only.
    backend/.venv/bin/python tools/vision/show_through.py <image>"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

image = sys.argv[1]
out = subprocess.run([str(Path(__file__).with_name("run.sh")), image, "--boxes"], capture_output=True, text=True).stdout
lines = json.loads(out.strip().splitlines()[-1])
gray = np.asarray(Image.open(image).convert("L"), dtype=int)
h, w = gray.shape


def values(x0, y0, x1, y1):
    v = gray[max(0, y0):min(h, y1), max(0, x0):min(w, x1)].ravel()
    return np.sort(v)


def depth(l, t, bw, bh):
    ink, paper = values(l, t, l + bw, t + bh), values(l - bh, t - bh, l + bw + bh, t + 2 * bh)
    return 0 if not len(ink) or not len(paper) else max(0, paper[len(paper) * 9 // 10] - ink[len(ink) // 20])


d = [[depth(*b[:4]) for b in line] for line in lines]
main = sorted(x for line, ds in zip(lines, d) if len(line) >= 3 for x in ds)
print_depth = main[len(main) // 2] if len(main) >= 3 else 0
floor = 0.3 * print_depth if print_depth >= 60 else 0
kept_lines = [sum(x >= floor for x in ds) for ds in d]
print(f"print depth {print_depth}, floor {floor:.0f}; lines {len(lines)} -> {sum(k > 0 for k in kept_lines)}, "
      f"words {sum(map(len, lines))} -> {sum(kept_lines)}")
