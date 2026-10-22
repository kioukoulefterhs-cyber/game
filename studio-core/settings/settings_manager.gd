class_name StudioSettings
extends Node
## Player settings stored in a ConfigFile, separate from progress so a reset keeps them.

signal changed(key: String, value)

const DEFAULTS := {
	"sfx_volume": 0.8,
	"music_volume": 0.5,
	"reduce_motion": false,
	"show_timer": true,
	"analytics_consent": "unknown", ## unknown | granted | denied
	"ads_personalized": false,
}

var path := "user://settings.cfg"
var _values := {}


func _ready() -> void:
	load_now()


func load_now() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for k in DEFAULTS:
			_values[k] = cfg.get_value("settings", k, DEFAULTS[k])


func get_value(key: String, default = null):
	return _values.get(key, DEFAULTS.get(key, default))


func set_value(key: String, value) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	save_now()
	changed.emit(key, value)


func save_now() -> void:
	var cfg := ConfigFile.new()
	for k in _values:
		cfg.set_value("settings", k, _values[k])
	cfg.save(path)
