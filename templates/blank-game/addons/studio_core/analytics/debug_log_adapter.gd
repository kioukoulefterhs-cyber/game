class_name StudioDebugLogAdapter
extends StudioAnalyticsAdapter
## Keeps events in memory (and optionally prints them). Local only; nothing leaves the device.

var events: Array[Dictionary] = []
var echo := false
var max_events := 500


func name() -> String:
	return "debug_log"


func log_event(event: String, params: Dictionary) -> void:
	events.append({"event": event, "params": params})
	if events.size() > max_events:
		events.pop_front()
	if echo:
		print("[analytics] ", event, " ", params)


func count(event: String) -> int:
	return events.filter(func(e): return e.event == event).size()
