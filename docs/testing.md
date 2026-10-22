# Testing

Run everything: `GODOT=godot tools/build-scripts/run_tests.sh`.

## Results (last run 2026-10-22, cloud Linux container and the owner's Windows PC, Godot 4.7.2)

| Suite | Command | Result |
|-------|---------|--------|
| Circuit Garden (Godot, headless) | `godot --headless --path games/circuit-garden -s res://tests/run_tests.gd` | **67/67 passed** (cloud and PC) |
| Blank template (Godot, headless) | `godot --headless --path templates/blank-game -s res://tests/run_tests.gd` | **4/4 passed** |
| Validator unit tests (Python) | `python3 -m unittest tools/level-validator/test_validate.py` | **8/8 passed** |
| Level pack validation | `python3 tools/level-validator/validate.py games/circuit-garden/puzzles/levels_v1.json --expect 100` | **100/100 valid** |
| studio-core copies in sync | `sync_core.py <project> --check` | in sync |
| Android debug APK export | `tools/build-scripts/build_android.sh debug` | built, `apksigner verify` passed (v2+v3) |
| APK manifest check (androguard) | | package `com.circuitgarden.puzzle`, minSdk 24, targetSdk 36, portrait, **0 permissions** |
| Exported desktop build smoke run | Linux export, 400 frames under Xvfb | started, no script errors, save written |
| Screenshot tour | `tests/capture.gd` under Xvfb, 1080x1920 | all 13 screens rendered |
| Difficulty analysis | `python3 tools/level-analyzer/analyze.py` | effort rises 7 to 102, 0 dips (docs/difficulty) |

## Coverage map

| Area | Tests |
|------|-------|
| Tile rotation | `test_board`: rotate_mask, tap on fixed/locked/out-of-range |
| Connection logic | `test_board`: links, leaks, wrong colour, unpowered loops |
| Energy propagation | `test_board`: cross channel independence, shorts, flow distances |
| Win conditions | `test_board`, `test_session` |
| Undo / restart | `test_session` |
| Hints, stars, timer | `test_session` |
| Level solvability and uniqueness | `test_generator`, `test_levels`, Python validator (brute-force cross-check on small levels) |
| Puzzle generation | `test_generator`: determinism per seed, all sizes, JSON round trip, reproducing shipped levels |
| Save / load | `test_studio_core` (round trip, corruption fallback, defaults), `test_progression` (restart) |
| Difficulty curve and labels | `test_levels.test_measured_difficulty_never_drops_and_is_labelled` |
| Garden economy pacing | `test_garden_economy` |
| Refunds, offline restore, consume retry | `test_studio_core` |
| Shipped ads/billing switches off | `test_progression.test_shipped_monetization_config_is_off` |
| Progression rewards | `test_progression`: seeds, star upgrades, unlocks, milestones, themes, garden |
| Offline behaviour | `test_progression.test_offline_play_is_fully_functional`, offline ad/billing cases |
| Mock ad callbacks | `test_studio_core`: earned, cancel, failed load, offline, interstitial policy |
| Mock billing callbacks | `test_studio_core`: grant+ack, consume, duplicate token, pending, cancel/error/offline, restore |
| Analytics consent | `test_studio_core`, `test_progression` |
| studio-core reuse | `templates/blank-game/tests/test_reuse.gd` |

## Not tested yet (needs a device or the developer's machine)

* Running the APK on a real phone or emulator (no device; emulator images blocked in the container).
* Touch feel, frame rate, pause/resume on real Android lifecycle events, safe-area insets.
* Windows release build (`build_android.ps1 -Mode release`) and `new_upload_keystore.ps1`.
* Release AAB build and signing.
* Real AdMob and Play Billing. The adapters are implemented, but only their no-plugin paths are
  unit tested. They need the plugins, a Gradle build and a phone.
* Headless and desktop runs are not device tests and are never reported as such.

`tools/build-scripts/device_test.sh` installs the APK over ADB, launches it and fails on any
`SCRIPT ERROR` in logcat. It is written but has not been run.
