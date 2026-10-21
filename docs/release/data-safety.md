# Data safety checklist (Play Console)

## Current build (no ads SDK, no analytics backend, mock store in debug only)

* Does the app collect or share user data? **No.** All data stays on the device.
* Encryption in transit: not applicable (no network use).
* Account deletion: not applicable (no accounts).
* Permissions: none.

## When AdMob is enabled (re-answer the form)

* Collected/shared by the AdMob SDK: device or other IDs (advertising ID), app interactions,
  diagnostics, approximate location derived from IP. Purpose: advertising, analytics, fraud
  prevention. Check Google's current AdMob data disclosure guidance at the time of submission.
* The `com.google.android.gms.permission.AD_ID` permission is added by the ads SDK; declare it.

## When Play Billing is enabled

* Purchase history is handled by Google Play. If our verification server stores purchase tokens,
  declare "Purchase history" as collected, for app functionality.

## When an analytics backend is added

* Declare "App interactions" (and any IDs it uses), purpose analytics, optional (consent-gated).
