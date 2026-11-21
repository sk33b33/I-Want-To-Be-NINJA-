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
"$GODOT" --headless --path . -s res://tests/run_tests.gd
echo "== main scene smoke (300 frames)"
out="$("$GODOT" --headless --path . --quit-after 300 2>&1)"
if echo "$out" | grep -E "ERROR|SCRIPT ERROR"; then exit 1; fi
echo "ALL CHECKS PASSED"
