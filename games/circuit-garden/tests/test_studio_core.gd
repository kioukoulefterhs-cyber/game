extends RefCounted
## studio-core services in isolation: save/load, settings, analytics, ads and billing policy.

var t
const TMP := "user://test_tmp"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(TMP)
	var p := TMP.path_join(name)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(p + suffix)
	return p


func test_save_round_trip() -> void:
	var s := StudioSave.new()
	s.path = _path("save_a.json")
	s.load_now()
	s.section("progress")["seeds"] = 42
	s.set_value("name", "garden")
	t.check(s.save_now())
	var s2 := StudioSave.new()
	s2.path = s.path
	s2.load_now()
	t.eq(int(s2.section("progress").seeds), 42)
	t.eq(s2.get_value("name"), "garden")
	s.free()
	s2.free()


func test_save_recovers_from_corruption() -> void:
	var s := StudioSave.new()
	s.path = _path("save_b.json")
	s.load_now()
	s.set_value("x", 1)
	s.save_now()
	s.set_value("x", 2)
	s.save_now() # backup now holds x=1
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s2 := StudioSave.new()
	s2.path = s.path
	s2.load_now()
	t.eq(int(s2.get_value("x", -1)), 1, "falls back to the backup")
	t.check(s2.last_error != "")
	s.free()
	s2.free()


func test_save_missing_file_gives_defaults() -> void:
	var s := StudioSave.new()
	s.path = _path("save_c.json")
	s.load_now()
	t.eq(int(s.get_value("version")), StudioSave.CURRENT_VERSION)
	s.free()


func test_settings_persist() -> void:
	var a := StudioSettings.new()
	a.path = _path("settings.cfg")
	a.load_now()
	t.eq(a.get_value("reduce_motion"), false)
	a.set_value("reduce_motion", true)
	var b := StudioSettings.new()
	b.path = a.path
	b.load_now()
	t.eq(b.get_value("reduce_motion"), true)
	a.free()
	b.free()


func test_analytics_requires_consent() -> void:
	var an := StudioAnalytics.new()
	var log := StudioDebugLogAdapter.new()
	an.configure(log, PackedStringArray(["level_start"]))
	t.check(not an.track("level_start"), "dropped while consent unknown")
	an.set_consent(StudioConsent.State.DENIED)
	t.check(not an.track("level_start"), "dropped when denied")
	an.set_consent(StudioConsent.State.GRANTED)
	t.check(an.track("level_start", {"level": "cg-001"}))
	t.check(not an.track("made_up_event"), "unknown events rejected")
	t.eq(log.events.size(), 1)
	t.eq(an.dropped_without_consent, 2)
	an.free()


func test_analytics_sanitizes_params() -> void:
	var out := StudioAnalytics.sanitize({"ok": 1, "obj": Node, "arr": [1], "long": "x".repeat(100)})
	t.check(out.has("ok") and not out.has("obj") and not out.has("arr"))
	t.eq((out.long as String).length(), 40)


func _ads(outcome := "complete") -> Array:
	var ads := StudioAds.new()
	var mock := StudioMockAdsAdapter.new()
	mock.outcome = outcome
	ads.configure(mock)
	return [ads, mock]


func _rewarded(ads: StudioAds) -> Array:
	var got := []
	ads.rewarded_result.connect(func(ok, reason): got.append([ok, reason]))
	ads.show_rewarded()
	return got


func test_rewarded_grants_only_on_reward_callback() -> void:
	var pair := _ads("complete")
	t.eq(_rewarded(pair[0]), [[true, "earned"]])
	pair[0].free()


func test_rewarded_cancel_gives_nothing() -> void:
	var pair := _ads("complete")
	pair[1].outcome = "cancel"
	t.eq(_rewarded(pair[0]), [[false, "cancelled"]])
	pair[0].free()


func test_rewarded_offline_and_failed_load() -> void:
	for outcome in ["offline", "fail_load"]:
		var pair := _ads(outcome)
		t.check(not pair[0].rewarded_available())
		var got := _rewarded(pair[0])
		t.eq(got.size(), 1)
		t.eq(got[0][0], false, outcome)
		pair[0].free()


func test_interstitial_policy() -> void:
	var pair := _ads("complete")
	var ads: StudioAds = pair[0]
	ads.interstitial_min_seconds = 0.0
	t.check(not ads.on_natural_break("gameplay"), "never outside natural breaks")
	var shown := 0
	for i in 12:
		if ads.on_natural_break("level_complete"):
			shown += 1
	# 5 grace breaks, then at most one ad per 3 breaks: breaks 6, 9 and 12.
	t.eq(shown, 3)
	ads.ads_removed = true
	for i in 6:
		t.check(not ads.on_natural_break("level_complete"), "remove-ads stops interstitials")
	ads.free()


func _billing(outcome := "success") -> Array:
	var b := StudioBilling.new()
	var mock := StudioMockBillingAdapter.new()
	mock.outcome = outcome
	b.configure(mock, {"remove_ads": StudioBilling.Kind.NON_CONSUMABLE, "hints": StudioBilling.Kind.CONSUMABLE})
	var granted := []
	b.granted.connect(func(id, _p): granted.append(id))
	return [b, mock, granted]


func test_billing_non_consumable_grant_and_ack() -> void:
	var r := _billing()
	r[0].buy("remove_ads")
	t.eq(r[2], ["remove_ads"])
	t.check(r[0].is_owned("remove_ads"))
	t.eq(r[1].acks.size(), 1, "acknowledged after granting")
	r[0].buy("remove_ads")
	t.eq(r[2].size(), 1, "cannot buy an owned entitlement twice")
	r[0].free()


func test_billing_consumable_is_consumed() -> void:
	var r := _billing()
	r[0].buy("hints")
	r[0].buy("hints")
	t.eq(r[2], ["hints", "hints"])
	t.eq(r[1].consumes.size(), 2)
	t.check(not r[0].is_owned("hints"))
	r[0].free()


func test_billing_duplicate_delivery_grants_once() -> void:
	var r := _billing()
	r[0].buy("hints")
	var token: String = r[1].consumes[0]
	# Simulate the store re-sending the same purchase token.
	r[0]._on_purchases([{"product_id": "hints", "token": token, "state": "purchased"}])
	t.eq(r[2].size(), 1)
	r[0].free()


func test_billing_pending_then_complete() -> void:
	var r := _billing("pending")
	var pend := []
	r[0].pending.connect(func(id): pend.append(id))
	r[0].buy("remove_ads")
	t.eq(pend, ["remove_ads"])
	t.eq(r[2].size(), 0, "pending purchases are not granted")
	t.check(not r[0].is_owned("remove_ads"))
	r[1].complete_pending("mock-token-1")
	t.eq(r[2], ["remove_ads"])
	t.eq(r[1].acks.size(), 1)
	r[0].free()


func test_billing_cancel_error_offline() -> void:
	for outcome in ["cancel", "error"]:
		var r := _billing(outcome)
		var fails := []
		r[0].failed.connect(func(id, reason): fails.append(reason))
		r[0].buy("remove_ads")
		t.eq(r[2].size(), 0)
		t.eq(fails.size(), 1, outcome)
		r[0].free()
	var off := _billing("offline")
	var reasons := []
	off[0].failed.connect(func(_id, reason): reasons.append(reason))
	off[0].buy("remove_ads")
	t.eq(reasons, ["store unavailable"])
	off[0].free()


func test_billing_restore_after_reinstall() -> void:
	var r := _billing()
	r[0].buy("remove_ads")
	# New install: fresh service, no local state, same store account.
	var fresh := StudioBilling.new()
	fresh.configure(r[1], {"remove_ads": StudioBilling.Kind.NON_CONSUMABLE})
	t.check(fresh.is_owned("remove_ads"), "restored on connect")
	var fresh2 := StudioBilling.new()
	fresh2.restore_state(r[0].export_state())
	t.check(fresh2.is_owned("remove_ads"), "restored from saved state")
	r[0].free()
	fresh.free()
	fresh2.free()


func test_billing_refund_revokes_entitlement() -> void:
	var r := _billing()
	var revoked := []
	r[0].revoked.connect(func(id): revoked.append(id))
	r[0].buy("remove_ads")
	r[1].refund("mock-token-1")
	r[0].restore_purchases()
	t.check(not r[0].is_owned("remove_ads"), "refunded entitlement removed on restore")
	t.eq(revoked, ["remove_ads"])
	r[0].free()


func test_billing_offline_restore_keeps_entitlements() -> void:
	var r := _billing()
	r[0].buy("remove_ads")
	r[1].outcome = "offline"
	r[0].restore_purchases()
	t.check(r[0].is_owned("remove_ads"), "no answer from the store is not a refund")
	r[0].free()


func test_billing_failed_consume_is_retried() -> void:
	var r := _billing()
	r[0].buy("hints")
	var token: String = r[1].consumes[0]
	# Pretend the consume never reached the store: it still lists the purchase.
	r[1].owned.append({"product_id": "hints", "token": token, "state": "purchased", "acknowledged": false})
	r[0].restore_purchases()
	t.eq(r[2].size(), 1, "not granted twice")
	t.eq(r[1].consumes.size(), 2, "consume retried")
	r[0].free()


func test_admob_adapter_without_plugin_gives_no_ads() -> void:
	var a := StudioAdMobAdapter.new()
	var fails := []
	a.rewarded_failed.connect(func(r): fails.append(r))
	a.initialize({"live_enabled": false})
	a.load_rewarded()
	t.eq(fails.size(), 1, "load fails cleanly without the plugin")
	t.eq(a.consent_state(), StudioConsent.State.UNKNOWN)
	t.check(not StudioAdMobAdapter.plugin_available())
	var ads := StudioAds.new()
	ads.configure(StudioAdMobAdapter.new())
	var got := []
	ads.rewarded_result.connect(func(ok, _r): got.append(ok))
	ads.show_rewarded()
	t.eq(got, [false], "no reward without an ad")
	ads.free()


func test_play_billing_adapter_without_plugin_is_unavailable() -> void:
	var a := StudioPlayBillingAdapter.new()
	var got := []
	a.connected.connect(func(ok): got.append(ok))
	a.start_connection()
	t.eq(got, [false])
	t.check(not StudioPlayBillingAdapter.plugin_available())


func test_verifier_rejects_unknown_and_reports_insecure() -> void:
	var v := StudioPurchaseVerifier.new()
	v.known_products = PackedStringArray(["remove_ads"])
	t.check(not v.verify({"product_id": "x", "token": "a", "state": "purchased"}).ok)
	t.check(not v.verify({"product_id": "remove_ads", "token": "", "state": "purchased"}).ok)
	var ok := v.verify({"product_id": "remove_ads", "token": "a", "state": "purchased"})
	t.check(ok.ok)
	t.eq(ok.secure, false, "client-only verification never claims to be secure")
