#!/usr/bin/env bash
# Builds Circuit Garden for Android.
#   tools/build-scripts/build_android.sh debug     -> build/circuit-garden-debug.apk (debug keystore)
#   tools/build-scripts/build_android.sh release   -> build/circuit-garden-release.aab
# Release signing comes ONLY from environment variables (never from files in Git):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# Release AAB needs a full Android SDK and the Gradle build template (Project > Install
# Android Build Template in the editor).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
MODE="${1:-debug}"
mkdir -p "$ROOT/build"
cd "$ROOT/games/circuit-garden"
"$GODOT" --headless --import >/dev/null 2>&1 || true
if [ "$MODE" = "release" ]; then
  for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
    [ -n "${!v:-}" ] || { echo "missing $v" >&2; exit 2; }
  done
  "$GODOT" --headless --export-release "Android Release AAB" "$ROOT/build/circuit-garden-release.aab"
else
  "$GODOT" --headless --export-debug "Android" "$ROOT/build/circuit-garden-debug.apk"
  apksigner verify "$ROOT/build/circuit-garden-debug.apk" && echo "APK signature verified"
fi
