# Content rating and ads declarations

IARC questionnaire answers for the current build (expected outcome: Everyone / PEGI 3):

* Violence, fear, sexuality, language, drugs, gambling: **none**.
* User interaction / user-generated content / chat: **no**.
* Shares location: **no**. Digital purchases: **yes once IAP is enabled** (shown as "In-app purchases").
* Ads: declare "Contains ads" only when `ads_mode` is `test`/`live` in a build you upload. Ads are
  requested with max content rating G, so the ads themselves do not raise the rating.
* Simulated gambling or loot boxes: **none** (all store items are fixed, known contents).
