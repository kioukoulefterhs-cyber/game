extends RefCounted
## CGGame: rewards, unlocks, garden, daily challenge, hints, purchases, persistence, offline.

var t
const DIR := "user://test_game"


func _game(fresh := true, ads_outcome := "complete", billing_outcome := "success", store_owned: Array = []) -> CGGame:
	DirAccess.make_dir_recursive_absolute(DIR)
	if fresh:
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(f))
	var ads := StudioMockAdsAdapter.new()
	ads.outcome = ads_outcome
	var bill := StudioMockBillingAdapter.new()
	bill.outcome = billing_outcome
	bill.owned = store_owned.duplicate(true) # what the player's store account already owns
	var g := CGGame.new()
	t.root.add_child(g)
	g.configure(DIR.path_join("save.json"), DIR.path_join("settings.cfg"), ads, bill)
	return g


func _solve(g: CGGame, idx: int, extra_moves := 0) -> Dictionary:
	var lv: CGLevel = g.levels[idx]
	var s := CGSession.new(lv)
	var target := lv.solution_masks()
	for i in target.size():
		while s.board.is_rotatable(i) and s.board.mask(i) != target[i]:
			s.tap(i)
	s.moves += extra_moves
	return g.complete_level(lv, "campaign", s)


func _done(g: CGGame) -> void:
	t.root.remove_child(g)
	g.free()


func test_first_clear_rewards_and_replay() -> void:
	var g := _game()
	t.eq(g.seeds(), 0)
	t.eq(g.hints(), CGGame.STARTING_HINTS)
	var r := _solve(g, 0)
	t.eq(r.stars, 3)
	t.eq(r.seeds, CGGame.SEEDS_FIRST_CLEAR + 3 * CGGame.SEEDS_PER_STAR)
	t.eq(_solve(g, 0).seeds, 0, "replaying with the same stars gives nothing")
	_done(g)


func test_improving_stars_pays_the_difference() -> void:
	var g := _game()
	var par: int = g.levels[1].par
	var r1 := _solve(g, 1, par * 3) # far over par -> 1 star
	t.eq(r1.stars, 1)
	var r2 := _solve(g, 1)
	t.eq(r2.seeds, 2 * CGGame.SEEDS_PER_STAR)
	t.eq(int(g.level_record(g.levels[1].id).stars), 3)
	_done(g)


func test_unlocking_is_progressive() -> void:
	var g := _game()
	t.check(g.is_unlocked(0) and g.is_unlocked(CGGame.UNLOCK_AHEAD - 1))
	t.check(not g.is_unlocked(CGGame.UNLOCK_AHEAD))
	_solve(g, 0)
	t.check(g.is_unlocked(CGGame.UNLOCK_AHEAD))
	t.eq(g.next_unplayed_index(), 1)
	_done(g)


func test_milestone_bonus_and_theme_unlock() -> void:
	var g := _game()
	var total := 0
	var unlock_texts := []
	for i in 5:
		var r := _solve(g, i)
		total += r.seeds
		unlock_texts += r.unlocks
	t.eq(unlock_texts.size(), 1, "5-level milestone fires once")
	t.eq(g.seeds(), total)
	t.check(not g.set_theme("greenhouse"), "greenhouse locked before 25 levels")
	for i in range(5, 25):
		_solve(g, i)
	t.check(g.set_theme("greenhouse"))
	_done(g)


func test_garden_purchase_and_persistence() -> void:
	var g := _game()
	t.eq(g.buy_garden_item("daisy"), "needs 10 more seeds")
	g.add_seeds(25)
	t.eq(g.buy_garden_item("daisy"), "")
	t.eq(g.seeds(), 15)
	t.eq(g.buy_garden_item("daisy"), "already owned")
	t.eq(g.buy_garden_item("aurora"), "not for sale", "pack plants are purchase-only")
	_done(g)
	var again := _game(false)
	t.check(again.owns_item("daisy"), "garden survives a restart")
	t.eq(again.seeds(), 15)
	_done(again)


func test_progress_survives_restart() -> void:
	var g := _game()
	_solve(g, 0)
	_solve(g, 1)
	var seeds := g.seeds()
	_done(g)
	var again := _game(false)
	t.eq(again.completed_count(), 2)
	t.eq(again.seeds(), seeds)
	_done(again)


func test_daily_is_deterministic_and_rewards_once() -> void:
	var day := {"year": 2026, "month": 10, "day": 21}
	var a := CGGame.daily_level(day)
	var b := CGGame.daily_level(day)
	var c := CGGame.daily_level({"year": 2026, "month": 10, "day": 22})
	t.eq(a.codes + str(a.start), b.codes + str(b.start), "same day, same puzzle")
	t.check(a.codes != c.codes, "next day differs")
	t.eq(CGSolver.new().count_solutions(a.make_board()), 1)
	var g := _game()
	var s := CGSession.new(a)
	for i in a.size * a.size:
		while s.board.is_rotatable(i) and s.board.rot[i] != a.solution[i]:
			s.tap(i)
	t.check(s.is_solved)
	t.eq(int(g.complete_level(a, "daily", s).seeds), CGGame.SEEDS_DAILY)
	t.eq(int(g.complete_level(a, "daily", s).seeds), 0, "daily pays once")
	t.eq(g.daily_streak(), 1)
	_done(g)


func test_daily_streak_counts_consecutive_days() -> void:
	var g := _game()
	g._update_streak("daily-2026-10-20")
	g._update_streak("daily-2026-10-21")
	t.eq(g.daily_streak(), 2)
	g._update_streak("daily-2026-10-23")
	t.eq(g.daily_streak(), 1)
	_done(g)


func test_rewarded_hint_flow() -> void:
	var g := _game(true, "complete")
	var results := []
	g.offer_rewarded_hint(func(ok): results.append(ok))
	t.eq(results, [true])
	t.eq(g.hints(), CGGame.STARTING_HINTS + 1)
	_done(g)
	var g2 := _game(true, "cancel")
	var r2 := []
	g2.offer_rewarded_hint(func(ok): r2.append(ok))
	t.eq(r2, [false])
	t.eq(g2.hints(), CGGame.STARTING_HINTS, "no reward without the reward callback")
	_done(g2)


func test_purchases_apply_entitlements() -> void:
	var g := _game()
	g.buy_product(CGGame.PRODUCT_HINT_PACK)
	t.eq(g.hints(), CGGame.STARTING_HINTS + CGGame.HINT_PACK_SIZE)
	t.check(not g.ads.ads_removed)
	g.buy_product(CGGame.PRODUCT_REMOVE_ADS)
	t.check(g.ads.ads_removed)
	g.buy_product(CGGame.PRODUCT_GARDEN_PACK)
	t.check(g.owns_item("aurora"))
	var account: Array = g.billing.adapter.owned
	_done(g)
	var again := _game(false, "complete", "success", account)
	t.check(again.billing.is_owned(CGGame.PRODUCT_REMOVE_ADS), "entitlement persists across launches")
	t.check(again.ads.ads_removed)
	_done(again)
	var offline := _game(false, "complete", "offline")
	t.check(offline.billing.is_owned(CGGame.PRODUCT_REMOVE_ADS), "kept when the store cannot be reached")
	_done(offline)


func test_refund_removes_paid_items() -> void:
	var g := _game()
	g.buy_product(CGGame.PRODUCT_GARDEN_PACK)
	g.buy_product(CGGame.PRODUCT_REMOVE_ADS)
	var store: StudioMockBillingAdapter = g.billing.adapter
	for p in store.owned.duplicate():
		store.refund(p.token)
	g.billing.restore_purchases()
	t.check(not g.owns_item("aurora"), "pack plants removed after a refund")
	t.check(not g.ads.ads_removed, "ads return after remove-ads is refunded")
	_done(g)


func test_offline_play_is_fully_functional() -> void:
	var g := _game(true, "offline", "offline")
	t.check(not g.rewarded_available())
	t.check(not g.billing.connected)
	var r := _solve(g, 0)
	t.check(r.seeds > 0, "progress works without network")
	var got := []
	g.offer_rewarded_hint(func(ok): got.append(ok))
	t.eq(got, [false])
	_done(g)


func test_analytics_events_recorded_with_consent() -> void:
	var g := _game()
	g.settings.set_value("analytics_consent", "granted")
	_solve(g, 0)
	t.eq(g.debug_log.count("level_complete"), 1)
	g.settings.set_value("analytics_consent", "denied")
	_solve(g, 1)
	t.eq(g.debug_log.count("level_complete"), 1, "nothing recorded after opting out")
	_done(g)


func test_shipped_monetization_config_is_off() -> void:
	# Release gate: real ads and real purchases stay off until the owner approves turning them on.
	var m := CGGame.load_monetization()
	t.eq(m.ads_mode, "off", "ads_mode in config/monetization.json")
	t.eq(m.billing_enabled, false, "billing_enabled in config/monetization.json")


func test_monetization_config_falls_back_to_off() -> void:
	var m := CGGame.load_monetization("res://does/not/exist.json")
	t.eq(m.ads_mode, "off")
	t.eq(m.billing_enabled, false)
	var g := _game()
	g.monetization = {"ads_mode": "live", "admob": {"rewarded_android": "", "android_app_id": "",
		"test_rewarded_android": "ca-app-pub-3940256099942544/5224354917"}}
	var c := g.admob_config()
	t.eq(c.live_enabled, false, "live mode without live ids stays on test ids")
	t.eq(c.rewarded_unit, "ca-app-pub-3940256099942544/5224354917")
	_done(g)
