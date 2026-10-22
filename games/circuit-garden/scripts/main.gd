extends Control
## Screen router and the "host" API that screens call. Keeps navigation, overlays and
## toasts in one place; game rules live in the Game autoload (scripts/game/game.gd).

const Palette := preload("res://scripts/ui/palette.gd")
const SCREENS := {
	"menu": preload("res://scripts/ui/screens/menu_screen.gd"),
	"levels": preload("res://scripts/ui/screens/levels_screen.gd"),
	"game": preload("res://scripts/ui/game_screen.gd"),
	"garden": preload("res://scripts/ui/screens/garden_screen.gd"),
	"settings": preload("res://scripts/ui/screens/settings_screen.gd"),
	"store": preload("res://scripts/ui/screens/store_screen.gd"),
	"daily": preload("res://scripts/ui/screens/daily_screen.gd"),
	"about": preload("res://scripts/ui/screens/about_screen.gd"),
}
const PRIVACY_URL := "https://example.com/circuit-garden/privacy" ## TODO: real URL before release
const SUPPORT_URL := "mailto:support@example.com" ## TODO: real address before release

var _stack: Array = [] ## [name, data]
var _current: Control
var _toast: Label


func _ready() -> void:
	theme = StudioUI.make_theme()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	_toast = StudioUI.label("", 26)
	_toast.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_toast.offset_top = -200
	_toast.offset_bottom = -140
	_toast.offset_left = -320
	_toast.offset_right = 320
	_toast.modulate.a = 0.0
	_toast.z_index = 10
	add_child(_toast)
	show_screen("menu")
	if Game.settings.get_value("analytics_consent") == "unknown":
		_show_consent()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.analytics.end_session()
		Game.save.save_now()
		get_tree().quit()


func show_screen(name: String, data: Dictionary = {}, push := true) -> void:
	if push:
		if name == "menu":
			_stack.clear()
		_stack.append([name, data])
	if _current:
		_current.queue_free()
	var s: Control = SCREENS[name].new()
	if s.has_method("setup"):
		s.setup(self, data)
	_current = s
	add_child(s)
	move_child(s, 0)
	if not setting("reduce_motion", false):
		# Short fade so screens do not pop in.
		s.modulate.a = 0.0
		create_tween().tween_property(s, "modulate:a", 1.0, 0.18)


func go_back() -> void:
	if _current and _current.has_method("handle_back") and _current.handle_back():
		return
	if _stack.size() <= 1:
		get_tree().quit()
		return
	_stack.pop_back()
	var top: Array = _stack.back()
	show_screen(top[0], top[1], false)


func toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func open_url(url: String) -> void:
	OS.shell_open(url)


# --- Host API used by the game screen ---------------------------------------------------

func play_level(index: int) -> void:
	var lv := Game.levels[index]
	var mode := "tutorial" if index == 0 and not Game.progress().get("tutorial_done", false) else "campaign"
	if mode == "tutorial":
		Game.analytics.track("tutorial_start")
	_replace_game({"level": lv, "mode": mode})


func play_daily(timed: bool) -> void:
	var lv := Game.today_daily()
	if lv == null:
		toast("Could not build today's puzzle")
		return
	_replace_game({"level": lv, "mode": "daily", "time_limit": Game.DAILY_TIME_LIMIT if timed else 0.0})


func _replace_game(data: Dictionary) -> void:
	if not _stack.is_empty() and _stack.back()[0] == "game":
		_stack.pop_back()
	show_screen("game", data)


func level_title(lv: CGLevel, mode: String) -> String:
	match mode:
		"daily":
			return "Daily " + lv.id.trim_prefix("daily-")
		"tutorial":
			return "Tutorial"
	var label: String = lv.difficulty.get("label", "")
	if label.is_empty():
		return "Level %d" % (Game.level_index(lv) + 1)
	return "Level %d · %s" % [Game.level_index(lv) + 1, label]


func tip_for(lv: CGLevel, mode: String, s: CGSession = null) -> String:
	if mode == "tutorial" and s != null:
		if s.moves == 0:
			return "Tap a tile to turn it clockwise."
		if not s.analysis.leaks.is_empty():
			return "Connect the glowing source to every flower. Open ends must all join up."
		return "Nice! Every flower is lit."
	if lv.color_count() > 1:
		return "Each flower needs energy of its own color and symbol."
	if lv.codes.contains("+"):
		return "Bridges carry two separate paths. Energy goes straight across."
	return "Power every flower. Leave no loose ends."


func setting(key: String, default):
	return Game.settings.get_value(key, default)


func track(event: String, params := {}) -> void:
	Game.analytics.track(event, params)


func play_sfx(name: String) -> void:
	Game.audio.play(name)


func hints_available() -> int:
	return Game.hints()


func consume_hint() -> void:
	Game.add_hints(-1)
	Game.analytics.track("hint_used")


func rewarded_available() -> bool:
	return Game.rewarded_available()


func offer_rewarded_hint(cb: Callable) -> void:
	if Game.ads.adapter is StudioMockAdsAdapter:
		await _show_test_ad("Test rewarded ad (mock, no network)")
	Game.offer_rewarded_hint(cb)


func complete_level(lv: CGLevel, mode: String, s: CGSession) -> Dictionary:
	return Game.complete_level(lv, mode, s)


func next_level(lv: CGLevel, _mode: String) -> void:
	await _natural_break()
	var idx := Game.level_index(lv)
	if idx >= 0 and idx + 1 < Game.levels.size():
		play_level(idx + 1)


func go_back_from_game(_mode: String) -> void:
	await _natural_break()
	go_back()


func open_settings_overlay(_from: Control) -> void:
	show_screen("settings")


func _natural_break() -> void:
	if Game.ads.on_natural_break("level_complete") and Game.ads.adapter is StudioMockAdsAdapter:
		await _show_test_ad("Test interstitial (mock). Remove ads in the store.")


func _show_test_ad(text: String) -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(holder)
	var v := StudioUI.modal(holder, 0.85)
	v.add_child(StudioUI.label(text, 30))
	await get_tree().create_timer(1.2).timeout
	holder.queue_free()


func _show_consent() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(holder)
	var v := StudioUI.modal(holder)
	v.add_child(StudioUI.label("Help improve Circuit Garden?", 36))
	v.add_child(StudioUI.label("We can record anonymous gameplay events (levels started and finished, hints used) to improve puzzles. No account, no personal data. You can change this any time in Settings.", 24, Palette.TEXT_DIM))
	var choose := func(value: String):
		Game.settings.set_value("analytics_consent", value)
		holder.queue_free()
	v.add_child(StudioUI.button("Allow", choose.bind("granted")))
	v.add_child(StudioUI.button("No thanks", choose.bind("denied")))
	v.add_child(StudioUI.button("Privacy policy", func(): open_url(PRIVACY_URL)))
