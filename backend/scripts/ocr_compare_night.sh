#!/usr/bin/env bash
# PaddleOCR against Tesseract, part by part, gently (docs/FINDINGS.md). Lowest CPU priority, a
# memory cap per run, one result line per page in ~/magana-private-pages/ocr_compare.jsonl
# (private: the statement's totals are in it). Stop it any time: pkill -f ocr_compare
#   scripts/ocr_compare_night.sh [HH:MM to start, e.g. 23:00]   [max MB, default 3500]
set -u
cd "$(dirname "$0")/.."
if [ -n "${1:-}" ]; then
  start=$(date -j -f "%H:%M" "$1" +%s); now=$(date +%s)
  [ "$start" -le "$now" ] && start=$((start + 86400))
  echo "waiting until $1"; sleep $((start - now))
fi
cap=${2:-3500}
out=~/magana-private-pages/ocr_compare.jsonl
pdf=~/magana-private-pages/bank_a_statement.pdf
for part in benchmark misreads photo bank; do
  nice -n 19 .venv/bin/python scripts/ocr_compare.py tesseract --part "$part" --bank "$pdf" --bank-pages 2 --out "$out" >/dev/null
  MAGANA_OCR=paddle nice -n 19 .venv-paddle/bin/python scripts/ocr_compare.py paddle --part "$part" --bank "$pdf" \
    --bank-pages 2 --max-mb "$cap" --out "$out" >/dev/null 2>&1
done
echo "done: $out"
