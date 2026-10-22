class_name StudioAnalytics
extends Node
## Privacy-conscious event tracking.
## * Events go to one adapter (no-op by default) and only after the player grants consent.
## * Parameters are limited to small, non-personal values; no device ids, no free text.
## * Local counters (sessions, active days) stay on the device and are never reported as
##   retention results; real retention needs a backend we have not added.

const MAX_PARAMS := 10
const ALLOWED_TYPES := [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING]

var adapter: StudioAnalyticsAdapter = StudioAnalyticsAdapter.new()
var consent: StudioConsent.State = StudioConsent.State.UNKNOWN
## Event names a game declares; unknown names are rejected to keep the schema tidy.
var schema: PackedStringArray = []
var dropped_without_consent := 0
var session_started_msec := 0


func configure(p_adapter: StudioAnalyticsAdapter, p_schema: PackedStringArray) -> void:
	adapter = p_adapter
	schema = p_schema


func set_consent(state: StudioConsent.State) -> void:
	consent = state


func track(event: String, params: Dictionary = {}) -> bool:
	if not schema.is_empty() and not schema.has(event):
		push_warning("analytics: unknown event '%s'" % event)
		return false
	if not StudioConsent.allows_collection(consent):
		dropped_without_consent += 1
		return false
	adapter.log_event(event, sanitize(params))
	return true


static func sanitize(params: Dictionary) -> Dictionary:
	var out := {}
	for k in params:
		if out.size() >= MAX_PARAMS:
			break
		var v = params[k]
		if typeof(v) in ALLOWED_TYPES:
			if typeof(v) == TYPE_STRING:
				v = (v as String).substr(0, 40)
			out[str(k).substr(0, 32)] = v
	return out


func start_session() -> void:
	session_started_msec = Time.get_ticks_msec()
	track("session_start")


func end_session() -> void:
	if session_started_msec == 0:
		return
	track("session_end", {"seconds": (Time.get_ticks_msec() - session_started_msec) / 1000})
	session_started_msec = 0
	adapter.flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		end_session()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		start_session()
