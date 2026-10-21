# Development environment and dependencies

## Versions used (cloud build container, 2026-10-21)

| Dependency | Version | Source | Notes |
|------------|---------|--------|-------|
| Godot Engine | 4.7.2-stable (official, `ed1daf0bf`) | github.com/godotengine/godot releases | SHA-512 checked against the release's `SHA512-SUMS.txt` |
| Godot export templates | 4.7.2-stable | same release | includes `android_debug.apk`, `android_release.apk`, `android_source.zip` |
| OpenJDK | 21.0.12 | Ubuntu 24.04 package | Godot 4.7 Android export expects JDK 17+ |
| Git | 2.43.0 | Ubuntu | |
| apksigner | 31.0.2 (Ubuntu package) | Ubuntu universe | stand-in for SDK build-tools in the container |
| adb | 34.0.4 (Ubuntu package) | Ubuntu universe | no device attached in the container |
| zipalign | 10.0.0 (Ubuntu package) | Ubuntu universe | |
| Python | 3.12 | Ubuntu | validator and sync script; standard library only |

No third-party Godot addons or Python packages are used by the game or tools.

## Android SDK

The container's network blocks `dl.google.com`, so the official Android SDK could not be
installed there. Debug APK export (no Gradle) only needs `apksigner`, so the container uses a
minimal SDK folder (`/opt/android-sdk`) linking the Ubuntu tools. This is enough for the
debug APK; it is **not** enough for:

* Gradle builds (release AAB, Android plugins such as AdMob and Play Billing),
* emulator testing.

## Recommended Windows setup (not yet inspected)

1. Godot 4.7.2 stable (Windows, standard build, not .NET) and its export templates
   (Editor > Manage Export Templates).
2. Android Studio or the command-line tools, with: platform-tools, build-tools 35.x,
   platform android-36, NDK not required. Set Editor Settings > Export > Android > Android SDK Path.
3. JDK 17 or 21 (Android Studio's bundled JBR works). Set Java SDK Path.
4. Git for Windows.
5. A phone with USB debugging, for `tools/build-scripts/device_test.sh` (Git Bash) or manual ADB.
