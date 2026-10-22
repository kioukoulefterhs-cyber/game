# Monetization

Status (2026-10-22): the flows are implemented and tested against mock adapters, and real
adapters exist for AdMob (`studio-core/ads/admob_adapter.gd`) and Google Play Billing
(`studio-core/billing/play_billing_adapter.gd`). **Both are switched off** in
`games/circuit-garden/config/monetization.json`, and a test fails if the shipped config turns them
on. No AdMob or Play Console account exists yet, so there are no live ad units or products.

## Switches (`config/monetization.json`)

| Key | Values | Effect |
|-----|--------|--------|
| `ads_mode` | `off` (default) | Debug builds: mock ads. Release builds: no ads at all. |
| | `test` | AdMob with Google's public test units. Safe on any device, never pays. |
| | `live` | AdMob with the live ids below; falls back to test units if any id is empty. Needs owner approval. |
| `billing_enabled` | `false` (default) | Debug builds: pretend store. Release builds: no store, purchases unavailable. |
| | `true` | Google Play Billing. Needs products in Play Console and owner approval. |
| `admob.*` | ids | Test ids are Google's published ones; live ids stay empty until an AdMob account exists. |

The plugins are **not in the repo yet**: they are downloaded on the owner's PC and get committed to
`addons/` only after the owner approves. Once added they stay **disabled** in `project.godot`, so a normal export has no
ads SDK, no `AD_ID` permission and no billing library. Enabling ads or purchases for a build means:
enable the editor plugin(s), switch the config, and use a Gradle build. The AdMob app id for the
manifest comes from `addons/AdmobPlugin/android_export.cfg` (currently Google's test app id).

## Principles (enforced in code)

* The whole game is completable without ads or purchases. Hints are optional; seeds and all
  campaign plants are earned by play.
* Rewarded ads only when the player asks (out of hints, "Watch ad for 1 hint"). The hint is
  granted only after the adapter's `reward_earned` signal, never on close or cancel.
* Interstitials only at natural breaks the game names (`level_complete`, `return_to_menu`), never
  during a puzzle, not in a new player's first 5 breaks, then at most once per 3 breaks and
  3 minutes. The remove-ads purchase stops them.
* Failed loads, cancellation and offline mode give a clear message and no reward.

## Products

| Id | Type | Effect |
|----|------|--------|
| `remove_ads` | non-consumable | Disables interstitials (rewarded stay optional) |
| `garden_pack` | non-consumable | Four cosmetic pack plants |
| `hint_pack_10` | consumable | +10 hints |

Prices are set in Play Console (not in code). Nothing is created in Play Console yet.

## Purchase flow (`StudioBilling`)

1. Store reports a purchase. `pending` -> show "payment pending", grant nothing.
2. `purchased` and token not seen before -> verify -> grant -> record token -> acknowledge
   (non-consumable) or consume (consumable).
3. Token already processed -> no second grant. Non-consumables still restore ownership and retry a
   lost acknowledgement.
4. On connect and from Settings, `query_purchases` restores entitlements after reinstall.

### Verification: what is and is not secure

`StudioPurchaseVerifier` does client-only checks and returns `secure: false`. **Client-only
validation is not secure**: a modified APK can bypass it. For the permanent `remove_ads` and
`garden_pack` entitlements the planned strategy is:

1. Client sends `purchaseToken` + `productId` to a small server endpoint.
2. Server calls Google Play Developer API `purchases.products.get` with a service account,
   checks `purchaseState == 0` and the package name, then acknowledges server-side.
3. Server returns the verdict; the client grants only on a positive answer, and caches it.
4. Optionally subscribe to Real-time Developer Notifications for refunds and revoke.

This needs a server and a Google Cloud service account, which means creating accounts and
possibly spending money, so it has not been started. Until then the risk is limited to
cosmetics and ad removal, which we accept for a prototype but should not ship long term.

## SDK plugins (downloaded and checked 2026-10-22 on the Windows PC)

| Plugin | Version | License | Notes |
|--------|---------|---------|-------|
| godot-sdk-integrations/godot-admob (Android) | v7.0, built for Godot 4.7 | MIT | play-services-ads 24.9.0, minSdk 24, adds AD_ID, INTERNET, ACCESS_NETWORK_STATE. Includes Google's UMP consent API. |
| godot-sdk-integrations/godot-google-play-billing | 3.3.0 (Godot 4.2+) | MIT | Play Billing Library 9.1.0, minSdk 23. Skip the newer-dated 1.4.0: it is the Godot 3 line. |

## AdMob flow (`StudioAdMobAdapter`)

1. `update_consent_info` first. If Google says consent is REQUIRED (EEA, UK, Switzerland) the
   consent form is loaded and shown; ads are not requested until the answer is OBTAINED or
   NOT_REQUIRED. If the consent request fails, no ads that session.
2. Then the Mobile Ads SDK is initialised and rewarded/interstitial ads are loaded.
3. The hint is granted only on `rewarded_ad_user_earned_reward`; closing early grants nothing.
4. Ads are limited to rating G (family-friendly). Settings shows "Ad privacy choices", which
   reopens Google's consent form so players can change their answer.

## Billing flow details checked in this audit

| Requirement | Status |
|-------------|--------|
| Acknowledge non-consumables (Play refunds unacknowledged purchases after 3 days) | Done after granting; retried on every restore if it failed |
| Consume consumables (hint pack) so they can be bought again | Done after granting; **fixed:** a failed consume was never retried and blocked rebuying |
| Pending purchases (cash, slow cards) | Never granted until the state becomes PURCHASED |
| Duplicate deliveries | Each purchase token is granted once (tokens persisted) |
| Restore after reinstall / new device | `query_purchases` on connect and from Settings |
| Refunds and chargebacks | **Fixed:** restore now removes permanent entitlements the store no longer reports (it only ever added before); an offline/failed query changes nothing |
| "Item already owned" error | Triggers a restore so the entitlement appears |
| Disconnects | Adapter reconnects with backoff (2, 5, 15, 60 s) |
| Server-side verification | **Not done** (see below). Client-only, reported as insecure. |

