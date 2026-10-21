class_name CGGame
extends Node
## Circuit Garden's game state, registered as the "Game" autoload.
## Owns the studio-core services and all progression rules. Screens call into it.

signal seeds_changed(total: int)
signal hints_changed(total: int)
signal entitlements_changed

const LEVEL_PACK := "res://puzzles/levels_v1.json"
const STARTING_HINTS := 3
const HINT_PACK_SIZE := 10
const SEEDS_FIRST_CLEAR := 5
const SEEDS_PER_STAR := 5
const SEEDS_DAILY := 20
const UNLOCK_AHEAD := 3 ## levels playable beyond the furthest completed one

const PRODUCT_REMOVE_ADS := "remove_ads"
const PRODUCT_GARDEN_PACK := "garden_pack"
const PRODUCT_HINT_PACK := "hint_pack_10"

const EVENTS := [
	"first_launch", "tutorial_start", "tutorial_complete", "level_start", "level_complete",
	"level_failed", "session_start", "session_end", "hint_requested", "hint_used",
	"rewarded_offered", "rewarded_completed", "purchase_initiated", "purchase_completed",
	"garden_unlock", "daily_complete",
]

var save := StudioSave.new()
var settings := StudioSettings.new()
var audio := StudioAudio.new()
var analytics := StudioAnalytics.new()
var ads := StudioAds.new()
var billing := StudioBilling.new()
var debug_log := StudioDebugLogAdapter.new()

var levels: Array[CGLevel] = []
var _configured := false


func _ready() -> void:
	configure()


## Separate from _ready so tests can point the services at temporary files first.
func configure(save_path := "user://cg_save.json", settings_path := "user://settings.cfg",
		ads_adapter: StudioAdsAdapter = null, billing_adapter: StudioBillingAdapter = null) -> void:
	if _configured:
		return
	_configured = true
	save.path = save_path
	settings.path = settings_path
	for n in [save, settings, audio, analytics, ads, billing]:
		add_child(n)
	save.load_now()
	settings.load_now()
	audio.settings = settings
	_register_sounds()
	analytics.configure(debug_log, PackedStringArray(EVENTS))
	analytics.set_consent(StudioConsent.from_string(settings.get_value("analytics_consent")))
	settings.changed.connect(func(k, v):
		if k == "analytics_consent":
			analytics.set_consent(StudioConsent.from_string(v)))
	levels = CGLevel.load_pack(LEVEL_PACK)
	var prog := save.section("progress")
	if not prog.has("seeds"):
		prog.merge({"seeds": 0, "hints": STARTING_HINTS, "levels": {}, "first_launch_done": false})
	billing.restore_state(save.section("billing"))
	billing.granted.connect(_on_purchase_granted)
	billing.entitlements_changed.connect(_on_entitlements_changed)
	var debug := OS.is_debug_build()
	if billing_adapter == null:
		billing_adapter = _mock_billing() if debug else StudioPlayBillingAdapter.new()
	billing.configure(billing_adapter, {
		PRODUCT_REMOVE_ADS: StudioBilling.Kind.NON_CONSUMABLE,
		PRODUCT_GARDEN_PACK: StudioBilling.Kind.NON_CONSUMABLE,
		PRODUCT_HINT_PACK: StudioBilling.Kind.CONSUMABLE,
	})
	if ads_adapter == null:
		ads_adapter = StudioMockAdsAdapter.new() if debug else StudioAdMobAdapter.new()
	ads.ads_removed = billing.is_owned(PRODUCT_REMOVE_ADS)
	ads.configure(ads_adapter, {"live_enabled": false})
	if not prog.first_launch_done:
		prog.first_launch_done = true
		analytics.track("first_launch")
	_record_active_day()
	analytics.start_session()
	save.save_now()


func _mock_billing() -> StudioMockBillingAdapter:
	var m := StudioMockBillingAdapter.new()
	m.catalog = [
		{"id": PRODUCT_REMOVE_ADS, "title": "Remove ads", "price": "TEST"},
		{"id": PRODUCT_GARDEN_PACK, "title": "Aurora garden pack", "price": "TEST"},
		{"id": PRODUCT_HINT_PACK, "title": "10 hints", "price": "TEST"},
	]
	return m


func _register_sounds() -> void:
	audio.register_tone("tap", [[660.0, 0.05]], 0.35)
	audio.register_tone("blocked", [[180.0, 0.06]], 0.3)
	audio.register_tone("hint", [[880.0, 0.06], [1320.0, 0.08]], 0.3, "soft")
	audio.register_tone("win", [[523.25, 0.1], [659.25, 0.1], [783.99, 0.1], [1046.5, 0.25]], 0.35, "soft")
	audio.register_tone("unlock", [[784.0, 0.08], [1175.0, 0.18]], 0.35, "soft")


# --- Progress -------------------------------------------------------------------------

func progress() -> Dictionary:
	return save.section("progress")


func seeds() -> int:
	return int(progress().seeds)


func add_seeds(n: int) -> void:
	progress().seeds = seeds() + n
	seeds_changed.emit(seeds())


func hints() -> int:
	return int(progress().hints)


func add_hints(n: int) -> void:
	progress().hints = maxi(0, hints() + n)
	hints_changed.emit(hints())
	save.save_now()


func level_record(id: String) -> Dictionary:
	return progress().levels.get(id, {})


func completed_count() -> int:
	return progress().levels.size()


func level_index(lv: CGLevel) -> int:
	for i in levels.size():
		if levels[i].id == lv.id:
			return i
	return -1


func furthest_completed() -> int:
	var best := -1
	for i in levels.size():
		if progress().levels.has(levels[i].id):
			best = i
	return best


func is_unlocked(index: int) -> bool:
	return index <= furthest_completed() + UNLOCK_AHEAD


func next_unplayed_index() -> int:
	for i in levels.size():
		if not progress().levels.has(levels[i].id):
			return i
	return levels.size() - 1


## Records a solved level and returns {seeds, stars, unlocks: [text], has_next}.
func complete_level(lv: CGLevel, mode: String, s: CGSession) -> Dictionary:
	var stars := s.stars()
	var result := {"seeds": 0, "stars": stars, "unlocks": [], "has_next": false}
	var before_count := completed_count()
	var before_themes := CGGarden.themes_unlocked(before_count)
	if mode == "daily":
		var daily := save.section("daily")
		var key := lv.id
		if not daily.has(key):
			daily[key] = {"moves": s.moves, "seconds": int(s.elapsed)}
			result.seeds += SEEDS_DAILY
			_update_streak(key)
			analytics.track("daily_complete", {"day": key, "moves": s.moves})
	else:
		var rec := level_record(lv.id)
		var old_stars := int(rec.get("stars", 0))
		if rec.is_empty():
			result.seeds += SEEDS_FIRST_CLEAR
		result.seeds += SEEDS_PER_STAR * maxi(0, stars - old_stars)
		progress().levels[lv.id] = {
			"stars": maxi(stars, old_stars),
			"best_moves": mini(int(rec.get("best_moves", 1 << 30)), s.moves),
		}
		var idx := level_index(lv)
		result.has_next = idx >= 0 and idx + 1 < levels.size()
		if mode == "tutorial":
			progress().tutorial_done = true
			analytics.track("tutorial_complete")
	for m in CGGarden.milestones_between(before_count, completed_count()):
		result.seeds += int(m.seeds)
		result.unlocks.append(m.text)
	for t in CGGarden.themes_unlocked(completed_count()):
		if not t in before_themes:
			analytics.track("garden_unlock", {"item": t, "kind": "theme"})
	add_seeds(result.seeds)
	analytics.track("level_complete", {
		"level": lv.id, "mode": mode, "moves": s.moves, "stars": stars,
		"hints": s.hints_used, "seconds": int(s.elapsed),
	})
	save.save_now()
	return result


# --- Daily challenge ------------------------------------------------------------------

const DAILY_PARAMS := [
	{"size": 5, "colors": 2, "blocked": 1, "crosses": 1, "receiver_ratio": 0.5}, # Sunday
	{"size": 4, "colors": 1, "blocked": 1, "receiver_ratio": 0.6},
	{"size": 5, "colors": 2, "blocked": 2, "receiver_ratio": 0.6},
	{"size": 5, "colors": 2, "blocked": 1, "crosses": 1, "receiver_ratio": 0.5},
	{"size": 6, "colors": 2, "blocked": 2, "crosses": 1, "receiver_ratio": 0.45},
	{"size": 6, "colors": 3, "blocked": 1, "crosses": 1, "receiver_ratio": 0.4},
	{"size": 7, "colors": 3, "blocked": 2, "crosses": 2, "receiver_ratio": 0.35}, # Saturday
]
const DAILY_TIME_LIMIT := 300.0


## Same level for every player on the same calendar day, generated offline.
static func daily_level(date: Dictionary) -> CGLevel:
	var key := "%04d-%02d-%02d" % [date.year, date.month, date.day]
	var level_seed := int(date.year) * 10000 + int(date.month) * 100 + int(date.day)
	var weekday := int(Time.get_datetime_dict_from_unix_time(
		Time.get_unix_time_from_datetime_dict({"year": date.year, "month": date.month, "day": date.day})).weekday)
	var lv := CGGenerator.new().generate(DAILY_PARAMS[weekday], level_seed)
	if lv:
		lv.id = "daily-" + key
	return lv


func today_daily() -> CGLevel:
	return daily_level(Time.get_date_dict_from_system())


func daily_done(lv: CGLevel) -> bool:
	return save.section("daily").has(lv.id)


func daily_streak() -> int:
	return int(progress().get("daily_streak", 0))


func _update_streak(key: String) -> void:
	var p := progress()
	var today := Time.get_unix_time_from_datetime_string(key.trim_prefix("daily-"))
	var last = p.get("daily_last", "")
	if last != "":
		var prev := Time.get_unix_time_from_datetime_string(str(last).trim_prefix("daily-"))
		p.daily_streak = int(p.get("daily_streak", 0)) + 1 if today - prev == 86400 else 1
	else:
		p.daily_streak = 1
	p.daily_last = key


# --- Garden ---------------------------------------------------------------------------

func garden() -> Dictionary:
	var g := save.section("garden")
	if not g.has("owned"):
		g.merge({"owned": [], "decor": [], "theme": "meadow"})
	return g


func owns_item(id: String) -> bool:
	return id in garden().owned or id in garden().decor


## Buys a plant or decoration with seeds. Returns "" on success or a reason.
func buy_garden_item(id: String) -> String:
	if owns_item(id):
		return "already owned"
	var plant := CGGarden.find(CGGarden.PLANTS, id)
	var decor := CGGarden.find(CGGarden.DECOR, id)
	var item := plant if not plant.is_empty() else decor
	if item.is_empty():
		return "not for sale"
	if seeds() < int(item.cost):
		return "needs %d more seeds" % (int(item.cost) - seeds())
	add_seeds(-int(item.cost))
	if not plant.is_empty():
		garden().owned.append(id)
	else:
		garden().decor.append(id)
	analytics.track("garden_unlock", {"item": id, "kind": "plant" if decor.is_empty() else "decor"})
	save.save_now()
	return ""


func set_theme(id: String) -> bool:
	if not id in CGGarden.themes_unlocked(completed_count()):
		return false
	garden().theme = id
	save.save_now()
	return true


# --- Hints, ads and purchases ---------------------------------------------------------

func rewarded_available() -> bool:
	return ads.rewarded_available()


## Shows a rewarded ad and calls back with true only when the reward callback fired.
func offer_rewarded_hint(cb: Callable) -> void:
	analytics.track("rewarded_offered", {"placement": "hint"})
	var on_result := func(ok: bool, _reason: String):
		if ok:
			analytics.track("rewarded_completed", {"placement": "hint"})
			add_hints(1)
		cb.call(ok)
	ads.rewarded_result.connect(on_result, CONNECT_ONE_SHOT)
	ads.show_rewarded()


func buy_product(id: String) -> void:
	analytics.track("purchase_initiated", {"product": id})
	billing.buy(id)


func _on_purchase_granted(id: String, _purchase: Dictionary) -> void:
	match id:
		PRODUCT_HINT_PACK:
			add_hints(HINT_PACK_SIZE)
		PRODUCT_GARDEN_PACK:
			for p in CGGarden.PACK_PLANTS:
				if not p.id in garden().owned:
					garden().owned.append(p.id)
	analytics.track("purchase_completed", {"product": id})
	_persist_billing()


func _on_entitlements_changed() -> void:
	ads.ads_removed = billing.is_owned(PRODUCT_REMOVE_ADS)
	if billing.is_owned(PRODUCT_GARDEN_PACK):
		for p in CGGarden.PACK_PLANTS:
			if not p.id in garden().owned:
				garden().owned.append(p.id)
	_persist_billing()
	entitlements_changed.emit()


func _persist_billing() -> void:
	save.set_value("billing", billing.export_state())
	save.save_now()


# --- Local engagement counters (never reported as retention results) -------------------

func _record_active_day() -> void:
	var p := progress()
	var today := Time.get_date_string_from_system()
	if p.get("last_active_day", "") != today:
		p.last_active_day = today
		p.active_days = int(p.get("active_days", 0)) + 1
	p.sessions = int(p.get("sessions", 0)) + 1


func reset_progress() -> void:
	save.wipe()
	billing.processed_tokens.clear()
	billing.owned.clear()
	progress().merge({"seeds": 0, "hints": STARTING_HINTS, "levels": {}, "first_launch_done": true})
	billing.restore_purchases()
	save.save_now()
	seeds_changed.emit(0)
	hints_changed.emit(hints())
