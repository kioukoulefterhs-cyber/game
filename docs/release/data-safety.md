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
* The AdMob plugin (play-services-ads 24.9.0) adds `AD_ID`, `INTERNET` and
  `ACCESS_NETWORK_STATE`. In Play Console > App content > Advertising ID, answer **yes, uses
  advertising ID**, purpose Advertising or marketing.
* Data is encrypted in transit (the SDK uses HTTPS). Users can't request deletion from us because
  we store nothing; point to Google's controls.
* Consent: the app runs Google's UMP consent form (EEA/UK) before any ad request, and Settings
  has "Ad privacy choices" to change it later.

## When Play Billing is enabled

* The billing plugin adds `com.android.vending.BILLING`. Purchase history is handled by Google Play. If our verification server stores purchase tokens,
  declare "Purchase history" as collected, for app functionality.

## When an analytics backend is added

* Declare "App interactions" (and any IDs it uses), purpose analytics, optional (consent-gated).
