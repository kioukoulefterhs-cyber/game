#!/usr/bin/env bash
# Regenerates the Circuit Garden campaign pack and validates it.
# Usage: tools/level-generator/generate.sh [godot-binary]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${1:-${GODOT:-godot}}"
GAME="$ROOT/games/circuit-garden"
"$GODOT" --headless --path "$GAME" -s res://tools/generate_levels.gd -- \
  "$GAME/puzzles/curriculum.json" "$GAME/puzzles/levels_v1.json"
python3 "$ROOT/tools/level-validator/validate.py" "$GAME/puzzles/levels_v1.json" --expect 100
