#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="$ROOT/JevRelay/Resources/AppIcon.svg"
OUT="$ROOT/JevRelay/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if [ -f "$OUT" ] && command -v sips >/dev/null 2>&1; then
  WIDTH="$(sips -g pixelWidth "$OUT" 2>/dev/null | awk '/pixelWidth/{print $2}')"
  HEIGHT="$(sips -g pixelHeight "$OUT" 2>/dev/null | awk '/pixelHeight/{print $2}')"
  if [ "$WIDTH" = "1024" ] && [ "$HEIGHT" = "1024" ]; then
    echo "Existing 1024x1024 app icon is valid: $OUT"
    exit 0
  fi
fi
if command -v qlmanage >/dev/null 2>&1; then
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  qlmanage -t -s 1024 -o "$TMP" "$SRC" >/dev/null 2>&1
  CANDIDATE="$TMP/$(basename "$SRC").png"
  [ -f "$CANDIDATE" ] || { echo "Quick Look did not render the SVG." >&2; exit 1; }
  cp "$CANDIDATE" "$OUT"
  echo "Wrote $OUT"
else
  echo "qlmanage is unavailable. Export AppIcon.svg as a 1024x1024 PNG to $OUT" >&2
  exit 1
fi
