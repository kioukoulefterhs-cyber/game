# Google Play compliance notes (checked 2026-10-22)

Requirements that apply to a new personal developer account publishing Circuit Garden.
Re-check Google's pages before submission; these rules change.

| Requirement | What Play asks | Our state |
|-------------|----------------|-----------|
| Target API level | New apps and updates must target API 36 from 31 Aug 2026 (extension possible to 1 Nov 2026) | Godot 4.7.2 template targets 36. Verified in the debug APK manifest. |
| 16 KB memory pages | Apps with native code must support 16 KB page sizes on Android 15+ devices | Godot 4.7 ships 16 KB aligned engine libraries. **Not yet verified on our AAB** (needs the release build, then `zipalign -c -P 16 -v 4` on the extracted APKs). The AdMob/Billing AARs are Java only. |
| App bundle | New apps upload an AAB signed with an upload key; Play App Signing holds the app key | `build_android.ps1 -Mode release` makes the AAB. Not yet run (owner approval). Upload key never goes in Git. |
| Developer account | One-time USD 25 fee, identity verification | Not created. Needs owner approval (money and an external account). |
| Testing before production | Personal accounts created after 13 Nov 2023 need a closed test with at least 12 testers opted in for 14 days in a row before applying for production | Not started. Owner needs 12 testers (friends and family work). |
| Privacy policy | Required, public URL, also linked in the app | Draft in `privacy-policy-draft.md`. `PRIVACY_URL` and `SUPPORT_URL` in `scripts/main.gd` are placeholders. |
| Data safety form | Required for every app | Answers prepared in `data-safety.md` for each build variant. |
| Advertising ID declaration | Required when the manifest has `AD_ID` | Only the ads build has it. Answer "yes, advertising" then. |
| Ads declaration | "Contains ads" must match the build | No ads in a build with `ads_mode` off. |
| Content rating (IARC) | Questionnaire | Answers in `content-rating.md`. Expected Everyone / PEGI 3. |
| Target audience | Choosing under-13 ages puts the app under the Families policy (certified ad SDK settings, no AD_ID for kids, teacher-approved rules) | Recommend 13+ only. Ads already request rating G. Revisit if you want children as an audience. |
| Consent (EEA/UK) | Google requires a certified CMP for personalised ads in the EEA/UK | Google UMP flow implemented in `StudioAdMobAdapter`. Needs a GDPR message created in the AdMob console, then a real-device check. |
| Billing | Digital goods must use Play Billing; Billing Library 7+ required for new apps | Plugin uses Billing Library 9.1.0. Products not created; `billing_enabled` is false. |
| Account deletion | Only if the app has accounts | No accounts, not applicable. |
| Permissions | Only those needed, declared | Base build: none. Ads build: `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID`. Billing build: `BILLING`. |
