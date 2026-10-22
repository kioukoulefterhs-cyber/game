# Monetization

Status: the **flows** are implemented and tested against mock adapters. No real ad network or
store is connected. Release builds currently use stub adapters, so ads and purchases are off.

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

## Planned SDK plugins (to verify on the Windows machine before integrating)

Researched 2026-10-21 via the Godot Asset Library:

* Ads: **godot-sdk-integrations/godot-admob** (Android plugin listed for Godot 4.4+). Needs a
  Gradle build. Must run Google's UMP consent flow before requesting ads in the EEA/UK.
* Billing: **godot-sdk-integrations/godot-google-play-billing** v3.x (Godot 4.2+), the plugin the
  official Godot docs point to for Android in-app purchases.

Neither is downloaded or integrated. Check each plugin's latest release supports Godot 4.7 and a
current Play Billing Library before use. Development must use Google's published test ad unit ids;
live ids go in configuration with `live_enabled = true` only after explicit approval.
