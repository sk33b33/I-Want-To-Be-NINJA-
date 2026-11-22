#!/usr/bin/env bash
# Project checks: import/parse, Phase 0 boot scene, full test suite, main-scene smoke run.
# Usage: GODOT=/path/to/godot tools/check.sh   (defaults to `godot` on PATH)
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../project"
echo "== import / parse"
"$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error" && exit 1 || true
echo "== boot test (Phase 0 gate)"
"$GODOT" --headless --path . res://scenes/tests/boot_test.tscn 2>&1 | grep -q BOOT_OK
echo "BOOT_OK"
echo "== tests"
# A script error aborts a test function early, which would otherwise read as a pass.
log="$(mktemp)"
status=0
"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee "$log" || status=$?
if [ "$status" -ne 0 ]; then rm -f "$log"; exit "$status"; fi
if grep -q "SCRIPT ERROR" "$log"; then echo "FAIL: script error during tests"; rm -f "$log"; exit 1; fi
rm -f "$log"
echo "== main scene smoke (300 frames)"
out="$("$GODOT" --headless --path . --quit-after 300 2>&1)"
if echo "$out" | grep -E "ERROR|SCRIPT ERROR"; then exit 1; fi
echo "ALL CHECKS PASSED"
