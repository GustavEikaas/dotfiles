#!/usr/bin/env bash
set -Eeuo pipefail

SLURP_TIMEOUT=10

for dep in grim slurp magick tesseract wl-copy hyprpicker notify-send; do
  command -v "$dep" >/dev/null 2>&1 || { echo "Missing: $dep" >&2; exit 1; }
done

hyprpicker -r -z &
PICKER_PID=$!
trap 'kill "$PICKER_PID" 2>/dev/null || true' EXIT INT TERM

sleep 0.1

REGION=$(timeout "$SLURP_TIMEOUT" slurp -b "#00000080" -c "#888888ff" -w 1) \
  || { echo "No region selected" >&2; exit 1; }

TEXT=$(grim -g "$REGION" - \
  | magick - -colorspace Gray -normalize -contrast-stretch 2% -sharpen 0x1.0 -resize 200% png:- \
  | tesseract - stdout -l eng --psm 6)

echo "$TEXT" | wl-copy

CHARS=$(echo -n "$TEXT" | wc -m)
notify-send "OCR" "Copied $CHARS chars"
