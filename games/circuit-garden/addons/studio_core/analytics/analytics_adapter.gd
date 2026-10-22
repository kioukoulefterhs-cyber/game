class_name StudioAnalyticsAdapter
extends RefCounted
## Interface for analytics backends. The default does nothing (offline and development).

func name() -> String:
	return "noop"


func log_event(_event: String, _params: Dictionary) -> void:
	pass


func flush() -> void:
	pass
