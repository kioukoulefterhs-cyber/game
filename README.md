# Android Puzzle Studio

A small studio repo for portrait Android puzzle games built with **Godot 4.7.2 (stable)** and
GDScript. The first game is **Circuit Garden**: rotate vine tiles to carry each colour of energy
from its source to its matching flowers, with no loose ends.

## What is in here

| Path | What it is | State |
|------|------------|-------|
| `games/circuit-garden/` | The game (Godot project) | Playable: 100 levels, tutorial, daily challenge, garden, store (mock), settings |
| `studio-core/` | Reusable services: save, settings, audio, analytics, consent, ads, billing, UI helpers | Working with mock adapters; AdMob and Play Billing adapters written, untested on a device, switched off |
| `templates/blank-game/` | Second-game starter that reuses studio-core | Builds, tests pass, exports an APK |
| `tools/level-generator/` | Regenerates the level pack from `puzzles/curriculum.json` | Working, byte-reproducible |
| `tools/level-validator/` | Independent Python validator for level packs | Working, all 100 levels pass |
| `tools/build-scripts/` | Test runner, Android build, device smoke test, studio-core sync | Debug APK build verified in Linux; Windows scripts written but not yet run |
| `docs/` | Rules, architecture, roadmap, monetization, testing, release prep | Kept in step with the code |

## Quick start

```
# Run every automated check (Godot tests, template tests, validator)
GODOT=godot tools/build-scripts/run_tests.sh

# Play in the editor: open games/circuit-garden/project.godot in Godot 4.7.2

# Build a debug APK (needs Android SDK path + debug keystore set in Editor Settings)
tools/build-scripts/build_android.sh debug
```

On Windows use the `.ps1` scripts in `tools/build-scripts/` and `tools/level-generator/`.

`studio-core/` is the source of truth. Each Godot project keeps a committed copy in
`addons/studio_core/`; after editing studio-core run
`python3 tools/build-scripts/sync_core.py games/circuit-garden` (and for the template).
The test runner fails if a copy is out of date.

## Working vs placeholder

* **Working and tested:** puzzle rules, solver, generator, 100 validated levels, gameplay
  (rotate, undo, restart, hints, moves, timer, stars), tutorial, daily challenge, garden
  progression, save/load, settings, analytics with consent gating (local debug adapter only),
  ad and purchase *flows* against mock adapters, Android debug APK export.
* **Written but not yet run on a device:** `StudioAdMobAdapter` (test ids, UMP consent) and
  `StudioPlayBillingAdapter`. Both are off in `config/monetization.json`.
* **Placeholder:** privacy and support URLs in `scripts/main.gd`; server-side purchase verification.
* **Not yet done:** testing on a real Android device, signed release AAB, Play Console setup.
  These need the developer's machine and accounts. See the PASS/FAIL list in `docs/release-checklist.md`.

## Rules for this repo

Never commit signing keys, passwords or tokens (see `.gitignore`). No live ads or purchases
without explicit configuration and approval. Report only tests that actually ran.
