# Release checklist (PASS / FAIL)

Status as of 2026-10-22. **PASS** means it was checked and the evidence is linked. **FAIL** means it
is not done or not verified, and it blocks a production release. Nothing is published without the
owner's explicit approval.

## Gameplay and levels

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | 100 levels, each with exactly one solution | PASS | Godot `test_levels` and Python validator, 100/100 |
| 2 | Every level reproduces from its seed | PASS | `test_every_level_reproduces_from_its_seed` |
| 3 | Measured difficulty never drops from level to level | PASS | Effort 7 to 102, 0 dips, Spearman 1.000 ([difficulty/README.md](difficulty/README.md)) |
| 4 | Difficulty labels Easy / Medium / Hard / Expert shown in game | PASS | 18 / 25 / 33 / 24; `test_measured_difficulty_never_drops_and_is_labelled` |
| 5 | Difficulty weights confirmed by human playtesting | FAIL | The scale is a model. Needs a few real players timing levels |
| 6 | Garden economy: a reward at least every 10 levels, the full garden needs most of the campaign | PASS | `test_garden_economy` |

## Automated tests

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 7 | Game tests | PASS | 67/67 in the cloud and on the Windows PC |
| 8 | Template tests | PASS | 4/4 |
| 9 | Validator unit tests | PASS | 8/8 |
| 10 | Shipped config has ads and purchases off | PASS | `test_shipped_monetization_config_is_off` |

## Android build and device

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 11 | Package id `com.circuitgarden.puzzle`, portrait, minSdk 24, targetSdk 36 | PASS | Debug APK manifest |
| 12 | Debug APK builds and signature verifies | PASS | Linux build, `apksigner verify` |
| 13 | Release AAB builds and signs (pipeline proof with a throwaway key) | FAIL | Script ready (`build_android.ps1 -Mode release`). Waiting for owner's "yes release build" |
| 14 | 16 KB page alignment of the AAB | FAIL | Checked after item 13 |
| 15 | Real upload keystore created outside the repo and backed up | FAIL | Owner runs `tools/build-scripts/new_upload_keystore.ps1` and keeps the password |
| 16 | Runs on a physical phone (install, play, back button, pause/resume, save survives restart) | FAIL | Phone is plugged in but USB debugging is off, so adb can't see it |
| 17 | Frame rate and memory on a real phone | FAIL | Needs item 16 (`dumpsys gfxinfo` / `meminfo`) |
| 18 | Headless and desktop runs | PASS | These are **not** device tests and are not counted as such |

## Ads (AdMob)

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 19 | AdMob adapter with rewarded and interstitial ads, test ids, UMP consent, privacy options button | PASS (code) | `studio-core/ads/admob_adapter.gd`; unit tests cover the no-plugin path |
| 20 | Reward only after the ad's earned callback | PASS | Mock tests; same signal path for AdMob |
| 21 | AdMob plugin added to the project (disabled) | FAIL | Downloaded on the PC; waiting for owner's "yes plugins" |
| 22 | Test-ads build on the phone: consent form, rewarded test ad, privacy options | FAIL | Needs items 16 and 21 |
| 23 | AdMob account, app, ad units, GDPR message, `app-ads.txt` | FAIL | Owner account (external account, needs approval) |
| 24 | Real ads off until configured | PASS | `ads_mode` is `off`; `live` with empty ids falls back to test units |

## Purchases (Play Billing)

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 25 | Billing flows: grant, acknowledge, consume, pending, cancel, offline, restore, refund | PASS (mock) | `test_studio_core`, `test_progression` |
| 26 | Play Billing adapter (Library 9.1.0 plugin) | PASS (code) | `play_billing_adapter.gd`; real behaviour untested |
| 27 | Billing plugin added (disabled) | FAIL | Same approval as item 21 |
| 28 | Products created in Play Console, license testers, test purchase on phone | FAIL | Needs Play Console |
| 29 | Server-side purchase verification for remove ads and garden pack | FAIL | Not built. Recommended before selling permanent items |
| 30 | Paid products off until configured | PASS | `billing_enabled` is false |

## Store listing and policy

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 31 | Listing text | PASS (draft) | [release/store-listing.md](release/store-listing.md) |
| 32 | Screenshots 1080x1920 and feature graphic 1024x500 | PASS | `release/screenshots/`, `release/feature_graphic.png` |
| 33 | Privacy policy hosted at a public URL and set in the app | FAIL | Draft ready; `PRIVACY_URL` is a placeholder |
| 34 | Support email set in the app | FAIL | `SUPPORT_URL` is a placeholder |
| 35 | Data safety, content rating, target audience answers | PASS (prepared) | [data-safety.md](release/data-safety.md), [content-rating.md](release/content-rating.md), [compliance.md](release/compliance.md) |
| 36 | Play Console developer account (USD 25) | FAIL | Owner approval needed |
| 37 | Closed test: 12 testers for 14 consecutive days | FAIL | Needs item 36 and testers |

## Blockers, in the order they can be cleared

1. Owner replies "yes plugins" and "yes release build" (items 13, 14, 21, 27).
2. USB debugging on the phone, then the device pass and the test-ads pass (16, 17, 22).
3. Owner decisions that cost money or create accounts: Play Console (36), AdMob (23).
4. Privacy policy URL and support email (33, 34).
5. Upload keystore (15), then internal test track, then the 14-day closed test (37).
6. Before selling anything: products (28) and purchase verification (29).
7. Playtesting the difficulty (5).
