# Architecture

```
games/circuit-garden/                    studio-core/ (vendored as addons/studio_core)
  scripts/puzzle/  (pure logic)            save/       StudioSave      atomic JSON + backup
    board.gd      CGBoard   rules          settings/   StudioSettings  ConfigFile
    solver.gd     CGSolver  uniqueness     audio/      StudioAudio     synthesized SFX
    generator.gd  CGGenerator seeded       analytics/  StudioAnalytics + adapters (noop, debug log)
    level.gd      CGLevel   JSON           consent/    StudioConsent
    session.gd    CGSession undo/hints     ads/        StudioAds policy + adapters (mock, AdMob stub)
  scripts/game/                            billing/    StudioBilling flow + adapters (mock, Play stub)
    game.gd       CGGame (autoload Game)                StudioPurchaseVerifier
    garden.gd     CGGarden catalog         ui/         StudioUI builders and theme
  scripts/ui/
    main.gd (router + host API), game_screen.gd, board_view.gd, garden_view.gd, screens/*
```

## Layers

1. **Puzzle logic** (`scripts/puzzle/`): `RefCounted` classes with no nodes. Everything the
   rules decide is testable headless and shared by the game, the level tool and the daily
   challenge.
2. **Game state** (`CGGame`, autoload `Game`): owns the studio-core services, progression,
   rewards, garden, daily challenge, hints and purchase entitlements. Has a `configure()` entry
   point so tests can inject temp save paths and mock adapters.
3. **UI** (`scripts/ui/`): built in code with `StudioUI` helpers. `main.gd` is a small screen
   router with a back stack and the "host" API the gameplay screen calls, so `game_screen.gd`
   never touches global state directly. All graphics are procedural `_draw()` calls.

## studio-core rules

* No reference to any game class. The `templates/blank-game` test asserts no `CG*` classes exist.
* Every external SDK sits behind an adapter interface with a mock. Real adapters are opt-in by
  build type and configuration (`OS.is_debug_build()` picks mocks; release picks the real
  adapters, which are stubs today and therefore disable ads and purchases).
* Policy lives in the service, not the adapter: interstitial frequency caps, rewards only after
  the reward callback, pending purchases never granted, one grant per purchase token.

## Data

* Levels: `puzzles/levels_v1.json` (format in `level-format.md`).
* Save: `user://cg_save.json` with sections `progress`, `garden`, `daily`, `billing`. Settings in
  `user://settings.cfg` so a progress reset keeps them.
* Nothing leaves the device in the current build.

## Performance notes

Boards are at most 49 cells; analysis is a flood fill per change. The board redraws every frame
for the flow animation, a few hundred draw calls. The level pack is 129 KB of JSON parsed at start.
On-device frame time has not been measured yet.
