#!/usr/bin/env bash
# Headless test harness for the Attimo Godot project.
#
# Usage:
#   bash attimo/tests/run.sh [filter[,filter]]         run smoke tests (optional substring filter)
#   bash attimo/tests/run.sh --tool res://tools/x.gd   run an editor-time tool script headless
#
# GODOT overrides the engine path. Default: $HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot
# Exit codes: 0 = passed, 1 = failed, 3 = wrong or missing engine binary.
set -euo pipefail

EXPECTED_VERSION="4.7.2.stable.official.ed1daf0bf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
GODOT="${GODOT:-$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot}"

# 1. Version gate. Runs before anything touches the project (a wrong engine rewrites project files).
if [ ! -x "$GODOT" ]; then
	echo "Godot binary not executable: $GODOT" >&2
	echo "Expected version: $EXPECTED_VERSION (see README.md, set GODOT)" >&2
	echo "RUN.SH: FAILED (engine binary missing)"
	exit 3
fi
ACTUAL_VERSION="$("$GODOT" --version 2>/dev/null | tail -n 1 | tr -d '\r' || true)"
if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
	echo "Wrong Godot version. Expected: $EXPECTED_VERSION  Actual: '${ACTUAL_VERSION}'  Binary: $GODOT" >&2
	echo "RUN.SH: FAILED (engine version mismatch)"
	exit 3
fi

IMPORT_LOG="$(mktemp -t attimo_import.XXXXXX)"
RUN_LOG="$(mktemp -t attimo_run.XXXXXX)"
trap 'rm -f "$IMPORT_LOG" "$RUN_LOG"' EXIT

# 2. Import (fresh clones have no .godot cache; Pitfall 7).
set +e
"$GODOT" --headless --path "$PROJECT_DIR" --import >"$IMPORT_LOG" 2>&1
IMPORT_RC=$?
set -e
if [ "$IMPORT_RC" -ne 0 ]; then
	cat "$IMPORT_LOG"
	echo "RUN.SH: FAILED (import exit code $IMPORT_RC)"
	exit 1
fi

# 3. Run.
set +e
if [ "${1:-}" = "--tool" ]; then
	if [ -z "${2:-}" ]; then
		echo "RUN.SH: FAILED (--tool needs a res:// script path)"
		exit 1
	fi
	"$GODOT" --headless --path "$PROJECT_DIR" -s "$2" 2>&1 | tee "$RUN_LOG"
	RUN_RC=${PIPESTATUS[0]}
else
	if [ -n "${1:-}" ]; then
		"$GODOT" --headless --path "$PROJECT_DIR" -s res://tests/run_smoke.gd -- "$1" 2>&1 | tee "$RUN_LOG"
	else
		"$GODOT" --headless --path "$PROJECT_DIR" -s res://tests/run_smoke.gd 2>&1 | tee "$RUN_LOG"
	fi
	RUN_RC=${PIPESTATUS[0]}
fi
set -e

# 4. Godot exits 0 on script errors (Pitfall 8): grep both logs.
PATTERN='SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource'
if grep -Eq "$PATTERN" "$IMPORT_LOG" "$RUN_LOG"; then
	echo "--- error lines ---"
	grep -Eh "$PATTERN" "$IMPORT_LOG" "$RUN_LOG" || true
	echo "RUN.SH: FAILED (script or resource errors in log)"
	exit 1
fi
if [ "$RUN_RC" -ne 0 ]; then
	echo "RUN.SH: FAILED (godot exit code $RUN_RC)"
	exit "$RUN_RC"
fi

: "$REPO_ROOT"
echo "RUN.SH: PASSED"
