class_name StudioConsent
extends RefCounted
## Consent state shared by analytics and ads.
##
## Analytics consent is asked by the game itself (opt-in, default denied until granted).
## Ads consent in the EEA/UK must come from a certified CMP: with AdMob that is Google's
## User Messaging Platform (UMP), surfaced through the ads plugin. The mock ads adapter
## reports "not_required"; a real adapter must run the UMP flow before loading ads.

enum State { UNKNOWN, GRANTED, DENIED, NOT_REQUIRED }

static func from_string(s: String) -> State:
	match s:
		"granted":
			return State.GRANTED
		"denied":
			return State.DENIED
		"not_required":
			return State.NOT_REQUIRED
	return State.UNKNOWN


static func allows_collection(s: State) -> bool:
	return s == State.GRANTED
