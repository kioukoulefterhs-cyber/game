# Roadmap

Status key: **done** (implemented and tested), **in progress**, **planned**, **needs device** (needs the
Windows machine, a phone, or a store account).

| # | Milestone | Status |
|---|-----------|--------|
| 1 | Playable 4x4 puzzle: rules engine, solver, seeded generator, session (undo/restart/hint/moves/timer), board renderer, headless tests | done |
| 2 | Level pipeline: 100 curated levels across 4x4 to 7x7, JSON export, independent Python validator | in progress |
| 3 | Game shell: main menu, level select, save/load, settings, tutorial, daily challenge, pause, privacy/support links | planned |
| 4 | Garden progression: seeds, plants, three themes, milestones, celebration | planned |
| 5 | Monetization layer: ads and billing interfaces with mock adapters, store screen, consent | planned |
| 6 | Analytics: event schema, no-op and local debug adapters, consent gating | planned |
| 7 | Android: export presets, debug APK built in the cloud container, release AAB workflow | planned |
| 8 | Real AdMob / Play Billing plugins wired behind the adapters (test ids only) | needs device |
| 9 | Device testing via ADB, signed release AAB, Play Console internal testing | needs device |
| 10 | Second-game template proving studio-core reuse | planned |

## Implementation plan (short)

1. Keep puzzle logic in pure `RefCounted` classes (`CGBoard`, `CGSolver`, `CGGenerator`,
   `CGSession`) so everything that matters is testable headless.
2. Draw everything procedurally (`CGBoardView._draw`), no bitmap assets, so the APK stays small
   and art is original.
3. Generate levels offline with the same generator the game uses for the daily challenge;
   validate every shipped level with an independent Python solver.
4. Put cross-game services (save, settings, audio, analytics, ads, billing, consent, UI helpers)
   in `studio-core/`, vendored into each game's `addons/studio_core/` by a sync script.
5. Every external SDK sits behind an adapter with a mock. Real SDKs are only enabled by
   explicit configuration.
