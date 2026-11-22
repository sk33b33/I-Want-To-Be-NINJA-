#!/usr/bin/env bash
# Release build pipeline (Phase 12).
#   GODOT=/path/to/godot tools/build.sh [--skip-checks]
# 1. Runs every check (tools/check.sh) unless --skip-checks.
# 2. Exports the game data pack for each preset (Android, Windows Desktop, Linux) — this needs no
#    export templates and proves every resource exports — and boots the Linux pack headless.
# 3. Builds the installable APK / EXE / binary when the prerequisites exist, and otherwise says
#    exactly which one is missing (see docs/RELEASE_CHECKLIST.md "Build prerequisites").
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build"
cd "$ROOT"
if [ "${1:-}" != "--skip-checks" ]; then
  echo "== checks"
  GODOT="$GODOT" tools/check.sh
fi
VERSION="$(grep -m1 '^config/version=' project/project.godot | cut -d'"' -f2)"
echo "== version $VERSION"
mkdir -p "$OUT"/{android,windows,linux,packs}
for preset in "Android" "Windows Desktop" "Linux"; do
  slug="$(echo "$preset" | tr ' A-Z' '_a-z')"
  echo "== data pack: $preset"
  "$GODOT" --headless --path project --export-pack "$preset" "$OUT/packs/$slug.pck" > "$OUT/packs/$slug.log" 2>&1 \
    || { echo "FAIL: pack export for $preset (see build/packs/$slug.log)"; exit 1; }
done
echo "== boot the exported Linux pack"
if "$GODOT" --headless --main-pack "$OUT/packs/linux.pck" --quit-after 120 2>&1 | grep -E "SCRIPT ERROR|ERROR: Failed"; then
  echo "FAIL: the exported pack does not boot cleanly"; exit 1
fi
echo "BOOT_OK"

GODOT_VER="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+).*/\1.\3/')"
TEMPLATES="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/$GODOT_VER}"
missing=()
[ -d "$TEMPLATES" ] || missing+=("export templates for $GODOT_VER (expected in $TEMPLATES)")
if [ ${#missing[@]} -eq 0 ]; then
  for pair in "Linux:linux/i_want_to_be_ninja.x86_64" "Windows Desktop:windows/I want to be NINJA.exe"; do
    preset="${pair%%:*}"; path="${pair#*:}"
    echo "== export $preset"
    "$GODOT" --headless --path project --export-release "$preset" "$OUT/$path"
  done
  android_missing=()
  [ -n "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ] || android_missing+=("Android SDK (set ANDROID_HOME)")
  command -v java >/dev/null || android_missing+=("Java 17 JDK")
  [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] || android_missing+=("release keystore (GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD)")
  if [ ${#android_missing[@]} -eq 0 ]; then
    echo "== export Android"
    "$GODOT" --headless --path project --export-release "Android" "$OUT/android/i_want_to_be_ninja.apk"
  else
    missing+=("${android_missing[@]}")
  fi
fi
if [ ${#missing[@]} -gt 0 ]; then
  echo "== installable builds skipped — missing:"
  printf '   - %s\n' "${missing[@]}"
  echo "Data packs are in build/packs/ and verified. See docs/RELEASE_CHECKLIST.md."
else
  echo "== all builds in build/"
fi
