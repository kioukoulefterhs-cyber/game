class_name StudioAds
extends Node
## Ad policy on top of an adapter.
## * Rewarded ads are always optional; the reward is granted only after reward_earned.
## * Interstitials only at natural breaks the game names explicitly, never during play,
##   with a frequency cap, and never after the remove-ads entitlement.

signal rewarded_result(granted: bool, reason: String)

const BREAK_CONTEXTS := ["level_complete", "return_to_menu"]

var adapter: StudioAdsAdapter = StudioAdsAdapter.new()
var ads_removed := false
var interstitial_every_n_breaks := 3
var interstitial_min_seconds := 180.0
var interstitial_grace_breaks := 5 ## no interstitials during the first N breaks of a new player

var _breaks := 0
var _breaks_since_ad := 0
var _last_interstitial_msec := -1_000_000_000
var _rewarded_ready := false
var _interstitial_ready := false
var _pending_reward := false
var _earned := false


func configure(p_adapter: StudioAdsAdapter, config: Dictionary = {}) -> void:
	adapter = p_adapter
	adapter.rewarded_loaded.connect(func(): _rewarded_ready = true)
	adapter.rewarded_failed.connect(_on_rewarded_failed)
	adapter.reward_earned.connect(func(): _earned = true)
	adapter.rewarded_closed.connect(_on_rewarded_closed)
	adapter.interstitial_loaded.connect(func(): _interstitial_ready = true)
	adapter.interstitial_failed.connect(func(_r): _interstitial_ready = false)
	adapter.interstitial_closed.connect(func():
		_interstitial_ready = false
		adapter.load_interstitial())
	adapter.initialize(config)
	adapter.load_rewarded()
	adapter.load_interstitial()


func rewarded_available() -> bool:
	return _rewarded_ready


## Shows a rewarded ad. Emits rewarded_result(granted, reason) exactly once.
func show_rewarded() -> void:
	if _pending_reward:
		return
	if not _rewarded_ready:
		adapter.load_rewarded()
		rewarded_result.emit(false, "not_loaded")
		return
	_pending_reward = true
	_earned = false
	_rewarded_ready = false
	adapter.show_rewarded()


func _on_rewarded_failed(reason: String) -> void:
	_rewarded_ready = false
	if _pending_reward:
		_pending_reward = false
		rewarded_result.emit(false, reason)


func _on_rewarded_closed() -> void:
	if not _pending_reward:
		return
	_pending_reward = false
	rewarded_result.emit(_earned, "earned" if _earned else "cancelled")
	_earned = false
	adapter.load_rewarded()


## Call at a natural break. Returns true if an interstitial was shown.
func on_natural_break(context: String) -> bool:
	if not context in BREAK_CONTEXTS:
		push_warning("interstitial refused outside a natural break: %s" % context)
		return false
	_breaks += 1
	_breaks_since_ad += 1
	if not can_show_interstitial():
		return false
	_breaks_since_ad = 0
	_last_interstitial_msec = Time.get_ticks_msec()
	_interstitial_ready = false
	adapter.show_interstitial()
	return true


func can_show_interstitial() -> bool:
	if ads_removed or not _interstitial_ready:
		return false
	if _breaks <= interstitial_grace_breaks:
		return false
	if _breaks_since_ad < interstitial_every_n_breaks:
		return false
	return (Time.get_ticks_msec() - _last_interstitial_msec) / 1000.0 >= interstitial_min_seconds
