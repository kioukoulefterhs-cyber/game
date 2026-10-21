#!/usr/bin/env bash
# Installs the debug APK on a connected device and checks it starts without script errors.
# Needs a device with USB debugging on (adb devices must list it).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APK="$ROOT/build/circuit-garden-debug.apk"
PKG="com.circuitgarden.puzzle"
adb get-state >/dev/null || { echo "no device connected" >&2; exit 2; }
adb install -r "$APK"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 8
adb logcat -d -s godot:V > "$ROOT/build/device-log.txt" || true
adb shell pidof "$PKG" >/dev/null && echo "app is running" || { echo "app is not running" >&2; exit 1; }
if grep -q "SCRIPT ERROR" "$ROOT/build/device-log.txt"; then echo "script errors found, see build/device-log.txt" >&2; exit 1; fi
echo "device smoke test passed (log: build/device-log.txt)"
