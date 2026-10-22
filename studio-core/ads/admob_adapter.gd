class_name StudioAdMobAdapter
extends StudioAdsAdapter
## PLACEHOLDER. Not wired to a real SDK yet.
##
## Intended backend: the godot-sdk-integrations "godot-admob" Android plugin (see
## docs/monetization.md). It needs a Gradle Android build, which this repository cannot
## produce in the cloud container. Until it is integrated and tested on a device, this
## adapter reports itself unavailable and the game falls back to "no ads".
##
## Integration checklist for whoever wires it up:
## 1. Run the UMP consent flow before the first ad request; map its result to consent_state().
## 2. Use Google's published test ad unit ids during development; live ids only from
##    config with `live_enabled = true`, which requires explicit approval.
## 3. Emit reward_earned only from the SDK's user-earned-reward callback.

var _available := false


func name() -> String:
	return "admob"


func initialize(config: Dictionary) -> void:
	_available = false
	if config.get("live_enabled", false):
		push_warning("AdMob live ads requested but the AdMob adapter is not implemented")


func consent_state() -> StudioConsent.State:
	return StudioConsent.State.UNKNOWN
