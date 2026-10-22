#!/usr/bin/env bash
# Rebuilds the Circuit Garden campaign pack (measured difficulty curve) and validates it.
# Usage: tools/level-generator/generate.sh [godot-binary]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${1:-${GODOT:-godot}}"
PACK="$ROOT/games/circuit-garden/puzzles/levels_v1.json"
python3 "$ROOT/tools/level-generator/build_campaign.py" --godot "$GODOT"
python3 "$ROOT/tools/level-validator/validate.py" "$PACK" --expect 100 | tail -1
python3 "$ROOT/tools/level-analyzer/analyze.py" "$PACK" --csv "$ROOT/docs/difficulty/levels.csv" > /dev/null
