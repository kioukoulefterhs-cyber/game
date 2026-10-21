#!/usr/bin/env bash
# Runs every automated check: studio-core sync, Godot headless tests, level validator.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
python3 "$ROOT/tools/build-scripts/sync_core.py" "$ROOT/games/circuit-garden" --check
python3 "$ROOT/tools/build-scripts/sync_core.py" "$ROOT/templates/blank-game" --check
"$GODOT" --headless --path "$ROOT/games/circuit-garden" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/games/circuit-garden" -s res://tests/run_tests.gd
"$GODOT" --headless --path "$ROOT/templates/blank-game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/templates/blank-game" -s res://tests/run_tests.gd
python3 -m unittest "$ROOT/tools/level-validator/test_validate.py"
python3 "$ROOT/tools/level-validator/validate.py" "$ROOT/games/circuit-garden/puzzles/levels_v1.json" --expect 100 | tail -1
