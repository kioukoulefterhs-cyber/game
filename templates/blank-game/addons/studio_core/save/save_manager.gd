class_name StudioSave
extends Node
## Versioned JSON save with atomic writes and a backup copy.
## Game-agnostic: games store whatever dictionaries they like under their own keys.

signal loaded
signal saved

const CURRENT_VERSION := 1

var path := "user://save.json"
var data: Dictionary = {}
## Optional: func(data: Dictionary, from_version: int) -> Dictionary, for schema upgrades.
var migrate: Callable
var last_error := ""


func _ready() -> void:
	if data.is_empty():
		load_now()


func load_now() -> void:
	data = _read(path)
	if data.is_empty():
		data = _read(path + ".bak")
		if not data.is_empty():
			last_error = "main save unreadable, restored from backup"
			push_warning(last_error)
	if data.is_empty():
		data = {"version": CURRENT_VERSION}
	var v := int(data.get("version", 0))
	if v < CURRENT_VERSION and migrate.is_valid():
		data = migrate.call(data, v)
	data["version"] = CURRENT_VERSION
	loaded.emit()


func get_value(key: String, default = null):
	return data.get(key, default)


func set_value(key: String, value) -> void:
	data[key] = value


## Section helper: returns a dictionary stored under `key`, creating it if needed.
func section(key: String) -> Dictionary:
	if typeof(data.get(key)) != TYPE_DICTIONARY:
		data[key] = {}
	return data[key]


func save_now() -> bool:
	var text := JSON.stringify(data)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
		push_error(last_error)
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		last_error = "rename failed: %s" % error_string(err)
		push_error(last_error)
		return false
	saved.emit()
	return true


func wipe() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	data = {"version": CURRENT_VERSION}


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _notification(what: int) -> void:
	# Persist when Android backgrounds or closes the app.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
