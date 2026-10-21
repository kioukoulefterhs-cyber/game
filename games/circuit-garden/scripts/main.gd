extends Control
## Milestone 1 host: plays a seeded 4x4 level. Replaced by the full router in milestone 3.

const GameScreen := preload("res://scripts/ui/game_screen.gd")

var hints := 3
var _level_seed := 1


func _ready() -> void:
	theme = StudioUI.make_theme()
	_play()


func _play() -> void:
	for c in get_children():
		c.queue_free()
	var gen := CGGenerator.new()
	var lv := gen.generate({"size": 4, "colors": 1}, _level_seed)
	lv.id = "m1-%d" % _level_seed
	var s := GameScreen.new()
	s.setup(self, {"level": lv})
	add_child(s)


func level_title(lv: CGLevel, _mode: String) -> String: return "Seed %d" % lv.level_seed
func tip_for(_lv: CGLevel, _mode: String) -> String: return "Tap tiles to rotate. Power every flower, leave no loose ends."
func setting(_k: String, d): return d
func track(_e: String, _p := {}) -> void: pass
func play_sfx(_n: String) -> void: pass
func hints_available() -> int: return hints
func consume_hint() -> void: hints -= 1
func rewarded_available() -> bool: return false
func offer_rewarded_hint(cb: Callable) -> void: cb.call(false)
func toast(_t: String) -> void: pass
func open_settings_overlay(_from) -> void: pass
func complete_level(_lv, _mode, _s) -> Dictionary: return {"seeds": 0, "has_next": true}
func next_level(_lv, _mode) -> void:
	_level_seed += 1
	_play()
func go_back_from_game(_mode) -> void: _play()
