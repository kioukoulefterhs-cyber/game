class_name StudioAdMobAdapter
extends StudioAdsAdapter
## Google AdMob through the godot-sdk-integrations "godot-admob" plugin (MIT, v7.0 for Godot 4.7).
## The plugin's Admob node class is looked up at runtime, so projects without the plugin (or
## with it disabled) still run: the adapter then reports every ad as unavailable.
##
## Order of events, as Google requires for the EEA, UK and Switzerland:
##   1. UMP consent: update_consent_info, then show the consent form when it is REQUIRED.
##   2. Only after consent is OBTAINED or NOT_REQUIRED: initialize the Mobile Ads SDK.
##   3. Load ads. The reward is granted only from rewarded_ad_user_earned_reward.
## config: { live_enabled, rewarded_unit, interstitial_unit, under_age_of_consent }
## Live ad units are used only when live_enabled is true; otherwise Google's test units.

const NODE_CLASS := "Admob"
const SINGLETON := "AdmobPlugin"

signal consent_changed(state: StudioConsent.State)

var _admob: Node
var _config := {}
var _consent := StudioConsent.State.UNKNOWN
var _sdk_ready := false
var _want_rewarded := false
var _want_interstitial := false
var _rewarded_id := ""
var _interstitial_id := ""
var last_error := ""


func name() -> String:
	return "admob"


static func plugin_available() -> bool:
	return _node_script() != null and Engine.has_singleton(SINGLETON)


static func _node_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c.get("class", "") == NODE_CLASS:
			return load(c.path)
	return null


func initialize(config: Dictionary) -> void:
	_config = config
	var script := _node_script()
	if script == null or not Engine.has_singleton(SINGLETON):
		last_error = "AdMob plugin not in this build"
		return
	_admob = script.new()
	_admob.set("is_real", bool(config.get("live_enabled", false)))
	if config.get("live_enabled", false):
		_admob.set("android_real_rewarded_id", str(config.get("rewarded_unit", "")))
		_admob.set("android_real_interstitial_id", str(config.get("interstitial_unit", "")))
	# The rewarded ad is removed after it is shown; keep the interstitial cache small too.
	_admob.set("remove_interstitial_ads_after_displayed", true)
	_admob.set("max_ad_content_rating", 0) # AdmobConfig.ContentRating.G: family-friendly ads only
	_admob.connect("consent_info_updated", _on_consent_info_updated)
	_admob.connect("consent_info_update_failed", func(err): _consent_failed(err))
	_admob.connect("consent_form_loaded", func(): _admob.call("show_consent_form"))
	_admob.connect("consent_form_failed_to_load", func(err): _consent_failed(err))
	_admob.connect("consent_form_dismissed", func(_err): _on_consent_info_updated())
	_admob.connect("initialization_completed", _on_sdk_ready)
	_admob.connect("rewarded_ad_loaded", func(info, _resp):
		_rewarded_id = info.get_ad_id()
		rewarded_loaded.emit())
	_admob.connect("rewarded_ad_failed_to_load", func(_info, err): rewarded_failed.emit(_describe(err)))
	_admob.connect("rewarded_ad_failed_to_show_full_screen_content", func(_info, err): rewarded_failed.emit(_describe(err)))
	_admob.connect("rewarded_ad_user_earned_reward", func(_info, _reward): reward_earned.emit())
	_admob.connect("rewarded_ad_dismissed_full_screen_content", func(_info):
		_rewarded_id = ""
		rewarded_closed.emit())
	_admob.connect("interstitial_ad_loaded", func(info, _resp):
		_interstitial_id = info.get_ad_id()
		interstitial_loaded.emit())
	_admob.connect("interstitial_ad_failed_to_load", func(_info, err): interstitial_failed.emit(_describe(err)))
	_admob.connect("interstitial_ad_failed_to_show_full_screen_content", func(_info, err): interstitial_failed.emit(_describe(err)))
	_admob.connect("interstitial_ad_dismissed_full_screen_content", func(_info):
		_interstitial_id = ""
		interstitial_closed.emit())
	_admob.ready.connect(func(): _admob.call("update_consent_info"), CONNECT_ONE_SHOT)
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_admob)


func consent_state() -> StudioConsent.State:
	return _consent


## Lets the player review or change their ad choices (Settings > Ad privacy choices).
func show_privacy_options() -> bool:
	if _admob == null:
		return false
	_admob.call("load_consent_form")
	return true


func load_rewarded() -> void:
	_want_rewarded = true
	if _sdk_ready:
		_admob.call("load_rewarded_ad")
	elif _admob == null:
		rewarded_failed.emit(last_error)


func show_rewarded() -> void:
	if _sdk_ready and _rewarded_id != "":
		_admob.call("show_rewarded_ad", _rewarded_id)
	else:
		rewarded_failed.emit("not loaded")


func load_interstitial() -> void:
	_want_interstitial = true
	if _sdk_ready:
		_admob.call("load_interstitial_ad")
	elif _admob == null:
		interstitial_failed.emit(last_error)


func show_interstitial() -> void:
	if _sdk_ready and _interstitial_id != "":
		_admob.call("show_interstitial_ad", _interstitial_id)
	else:
		interstitial_failed.emit("not loaded")


func _on_consent_info_updated() -> void:
	var status = _admob.call("get_consent_status")
	var key := "UNKNOWN"
	if status != null:
		key = status.to_status_string()
	match key:
		"REQUIRED":
			_set_consent(StudioConsent.State.UNKNOWN)
			if _admob.call("is_consent_form_available"):
				_admob.call("load_consent_form") # emits consent_form_loaded, then we show it
		"OBTAINED":
			_set_consent(StudioConsent.State.GRANTED) # the player made a choice; the SDK honours it
			_start_sdk()
		"NOT_REQUIRED":
			_set_consent(StudioConsent.State.NOT_REQUIRED)
			_start_sdk()
		_:
			_set_consent(StudioConsent.State.UNKNOWN)


func _consent_failed(err) -> void:
	# Without a consent answer we do not request ads this session.
	last_error = "consent: " + _describe(err)
	rewarded_failed.emit(last_error)


func _start_sdk() -> void:
	if not _sdk_ready:
		_admob.call("initialize")


func _on_sdk_ready(_status) -> void:
	_sdk_ready = true
	if _want_rewarded:
		_admob.call("load_rewarded_ad")
	if _want_interstitial:
		_admob.call("load_interstitial_ad")


func _set_consent(s: StudioConsent.State) -> void:
	if s != _consent:
		_consent = s
		consent_changed.emit(s)


static func _describe(err) -> String:
	if err != null and err is Object and err.has_method("get_message"):
		return "%s (%d)" % [err.get_message(), err.get_code()]
	return "unknown error"
