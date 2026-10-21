class_name StudioMockAdsAdapter
extends StudioAdsAdapter
## Development/test ads backend. Never contacts a network.
## `outcome` scripts what the next ad does: complete | cancel | fail_load | offline.

var outcome := "complete"
var loads := 0
var shows := 0


func name() -> String:
	return "mock"


func consent_state() -> StudioConsent.State:
	return StudioConsent.State.NOT_REQUIRED


func load_rewarded() -> void:
	loads += 1
	if outcome in ["fail_load", "offline"]:
		rewarded_failed.emit(outcome)
	else:
		rewarded_loaded.emit()


func show_rewarded() -> void:
	shows += 1
	match outcome:
		"complete":
			reward_earned.emit()
			rewarded_closed.emit()
		"cancel":
			rewarded_closed.emit() # closed early: no reward callback
		_:
			rewarded_failed.emit(outcome)


func load_interstitial() -> void:
	loads += 1
	if outcome in ["fail_load", "offline"]:
		interstitial_failed.emit(outcome)
	else:
		interstitial_loaded.emit()


func show_interstitial() -> void:
	shows += 1
	if outcome in ["fail_load", "offline"]:
		interstitial_failed.emit(outcome)
	else:
		interstitial_closed.emit()
