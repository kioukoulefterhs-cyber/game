class_name StudioPurchaseVerifier
extends RefCounted
## Decides whether a purchase is genuine before it is granted.
##
## This base class does CLIENT-ONLY checks (known product, token present, purchased state).
## Client-only checks are NOT secure: a modified client can skip them. For permanent
## entitlements in production, send the purchase token to your own server, verify it with
## the Google Play Developer API (purchases.products.get), and grant from the server's
## answer. That server does not exist yet; see docs/monetization.md.

var known_products: PackedStringArray = []


## Returns { ok: bool, secure: bool, reason: String }.
func verify(purchase: Dictionary) -> Dictionary:
	if not known_products.has(str(purchase.get("product_id", ""))):
		return {"ok": false, "secure": false, "reason": "unknown product"}
	if str(purchase.get("token", "")) == "":
		return {"ok": false, "secure": false, "reason": "missing token"}
	if purchase.get("state", "") != "purchased":
		return {"ok": false, "secure": false, "reason": "not purchased"}
	return {"ok": true, "secure": false, "reason": "client-only check"}
