#!/usr/bin/env bash
# Distribute the Aptos Sigil brand logo to every app that uses it.
#
# The canonical logo is docs/assets/aptos-sigil-logo.svg (a clean vector mark).
# If you instead drop a raster docs/assets/aptos-sigil-logo.png, this prefers it.
# Run:  ./scripts/sync-logo.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "$ROOT/docs/assets/aptos-sigil-logo.png" ]]; then
  SRC="$ROOT/docs/assets/aptos-sigil-logo.png"; EXT="png"
elif [[ -f "$ROOT/docs/assets/aptos-sigil-logo.svg" ]]; then
  SRC="$ROOT/docs/assets/aptos-sigil-logo.svg"; EXT="svg"
else
  echo "ERROR: no docs/assets/aptos-sigil-logo.(svg|png) found." >&2
  exit 1
fi

# Distribute a copy. For PNGs we downscale to 256px (sips, macOS) to keep the repo
# lean — the full-res master stays in docs/assets. SVGs are copied as-is.
place() {
  local dest="$1"
  if [[ "$EXT" == "png" ]] && command -v sips >/dev/null 2>&1; then
    sips -Z 256 "$SRC" --out "$dest" >/dev/null
  else
    cp "$SRC" "$dest"
  fi
}

place "$ROOT/sdk/typescript/examples/web-petra/public/logo.$EXT"
for g in arcade dungeon idle; do
  APP="$ROOT/sdk/typescript/examples/games/$g"
  place "$APP/public/logo.$EXT"
  place "$APP/app/icon.$EXT"
done

echo "Logo ($EXT) synced to web-petra + arcade/dungeon/idle (public/logo.$EXT + app/icon.$EXT)."
