#!/usr/bin/env bash
# Distribute the Aptos Sigil brand logo to every app that uses it.
#
# Save the master logo once at docs/assets/aptos-sigil-logo.png, then run:
#   ./scripts/sync-logo.sh
# It copies the logo into each app's public/ (as logo.png) and as the Next.js
# app icon, so the console + all three games render the brand mark.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/docs/assets/aptos-sigil-logo.png"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: missing $SRC" >&2
  echo "Save the Aptos Sigil logo PNG there first, then re-run." >&2
  exit 1
fi

# Vite console: served from public/.
cp "$SRC" "$ROOT/sdk/typescript/examples/web-petra/public/logo.png"

# Next.js games: public/logo.png (header) + app/icon.png (favicon/app icon).
for g in arcade dungeon idle; do
  APP="$ROOT/sdk/typescript/examples/games/$g"
  cp "$SRC" "$APP/public/logo.png"
  cp "$SRC" "$APP/app/icon.png"
done

echo "Logo synced to web-petra + arcade/dungeon/idle (public/logo.png + app/icon.png)."
echo "Commit the generated PNGs so deploys include them."
