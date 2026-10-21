extends Node
## Wires studio-core services for a new game. Copy this project, rename it, and build the
## game in scripts/. Nothing here depends on Circuit Garden.

const PRODUCTS := {
	"remove_ads": StudioBilling.Kind.NON_CONSUMABLE,
}

var save := StudioSave.new()
var settings := StudioSettings.new()
var audio := StudioAudio.new()
var analytics := StudioAnalytics.new()
var ads := StudioAds.new()
var billing := StudioBilling.new()
var _configured := false


func _ready() -> void:
	configure()


func configure(save_path := "user://save.json", settings_path := "user://settings.cfg") -> void:
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
	audio.register_tone("click", [[700.0, 0.05]], 0.3)
	analytics.configure(StudioDebugLogAdapter.new(), PackedStringArray(["session_start", "session_end", "game_start"]))
	analytics.set_consent(StudioConsent.from_string(settings.get_value("analytics_consent")))
	var debug := OS.is_debug_build()
	billing.restore_state(save.section("billing"))
	billing.configure(StudioMockBillingAdapter.new() if debug else StudioPlayBillingAdapter.new(), PRODUCTS)
	ads.ads_removed = billing.is_owned("remove_ads")
	ads.configure(StudioMockAdsAdapter.new() if debug else StudioAdMobAdapter.new())
	analytics.start_session()
