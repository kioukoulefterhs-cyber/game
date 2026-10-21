class_name StudioAdsAdapter
extends RefCounted
## Interface every ads backend implements. Results are reported through signals so the
## service can react to real asynchronous SDK callbacks.

signal rewarded_loaded
signal rewarded_failed(reason: String)
signal reward_earned ## Emitted only when the SDK confirms the reward (e.g. AdMob onUserEarnedReward).
signal rewarded_closed
signal interstitial_loaded
signal interstitial_failed(reason: String)
signal interstitial_closed


func name() -> String:
	return "none"


func initialize(_config: Dictionary) -> void:
	pass


func consent_state() -> StudioConsent.State:
	return StudioConsent.State.UNKNOWN


func load_rewarded() -> void:
	rewarded_failed.emit("no ads backend")


func show_rewarded() -> void:
	rewarded_failed.emit("no ads backend")


func load_interstitial() -> void:
	interstitial_failed.emit("no ads backend")


func show_interstitial() -> void:
	interstitial_failed.emit("no ads backend")
