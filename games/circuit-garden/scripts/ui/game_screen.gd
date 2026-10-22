extends Control
## Puzzle gameplay screen: top bar, board, undo/restart/hint, pause and win overlays.
## It talks to the rest of the game only through the `host` passed to setup().

const Palette := preload("res://scripts/ui/palette.gd")

signal exited

var host ## Object providing the GameHost API used below (see main.gd).
var level: CGLevel
var session: CGSession
var mode := "campaign" ## campaign | daily | tutorial
var board_view: CGBoardView

var _moves_label: Label
var _timer_label: Label
var _hint_button: Button
var _undo_button: Button
var _overlay: Control
var _tip: Label
var _paused := false


func setup(p_host, data: Dictionary) -> void:
	host = p_host
	level = data.level
	mode = data.get("mode", "campaign")
	session = CGSession.new(level)
	session.time_limit = data.get("time_limit", 0.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := StudioUI.safe_margin(self)
	var col := StudioUI.vbox(18)
	margin.add_child(col)
	var top := StudioUI.hbox(12)
	col.add_child(top)
	top.add_child(StudioUI.button("II", _pause))
	var title := StudioUI.label(host.level_title(level, mode), 34)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(title)
	var stats := StudioUI.vbox(0)
	top.add_child(stats)
	_moves_label = StudioUI.label("", 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label = StudioUI.label("", 26, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	stats.add_child(_moves_label)
	stats.add_child(_timer_label)
	_timer_label.custom_minimum_size.x = 150
	board_view = CGBoardView.new()
	board_view.size_flags_vertical = SIZE_EXPAND_FILL
	board_view.reduce_motion = host.setting("reduce_motion", false)
	board_view.custom_minimum_size = Vector2(300, 300)
	col.add_child(board_view)
	_tip = StudioUI.label("", 26, Palette.TEXT_DIM)
	_tip.custom_minimum_size.y = 72
	col.add_child(_tip)
	var bottom := StudioUI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)
	_undo_button = StudioUI.button("Undo", _undo, 180)
	bottom.add_child(_undo_button)
	bottom.add_child(StudioUI.button("Restart", _restart, 180))
	_hint_button = StudioUI.button("Hint", _hint, 180)
	bottom.add_child(_hint_button)
	board_view.bind(session)
	board_view.cell_tapped.connect(_on_cell_tapped)
	session.changed.connect(_update_labels)
	session.solved.connect(_on_solved)
	_update_labels()
	host.track("level_start", {"level": level.id, "mode": mode, "size": level.size})


func _process(delta: float) -> void:
	if _paused or session.is_solved:
		return
	session.tick(delta)
	_update_timer()
	if session.is_time_up() and _overlay == null:
		_show_time_up()


func _notification(what: int) -> void:
	# Pause on app background so the timer never runs while the player is away.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and not session.is_solved and _overlay == null:
			_pause()


func _on_cell_tapped(i: int) -> void:
	if _paused or _overlay != null:
		return
	if session.tap(i):
		board_view.note_tap(i)
		host.play_sfx("tap")
	else:
		host.play_sfx("blocked")


func _undo() -> void:
	if _overlay == null and session.undo():
		host.play_sfx("tap")


func _restart() -> void:
	if _overlay != null:
		_close_overlay()
	session.restart()
	board_view.bind(session)
	_paused = false


func _hint() -> void:
	if _overlay != null or session.is_solved:
		return
	host.track("hint_requested", {"level": level.id})
	if host.hints_available() > 0:
		_apply_hint()
	else:
		_show_hint_offer()


func _apply_hint() -> void:
	var i: int = session.hint()
	if i >= 0:
		host.consume_hint()
		board_view.flash_hint(i)
		host.play_sfx("hint")
	_update_labels()


func _update_labels() -> void:
	_moves_label.text = "Moves %d" % session.moves
	_tip.text = host.tip_for(level, mode, session)
	_undo_button.disabled = not session.can_undo()
	_hint_button.text = "Hint (%d)" % host.hints_available()
	_update_timer()


func _update_timer() -> void:
	var t := session.elapsed
	if session.time_limit > 0.0:
		t = maxf(0.0, session.time_limit - session.elapsed)
	_timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]


func _on_solved() -> void:
	host.play_sfx("win")
	var result: Dictionary = host.complete_level(level, mode, session)
	await get_tree().create_timer(1.1 if not board_view.reduce_motion else 0.2).timeout
	if not is_inside_tree():
		return
	var v := _open_overlay()
	v.add_child(StudioUI.label("Garden powered!", 44, Palette.ACCENT))
	var stars := session.stars()
	v.add_child(StudioUI.label("★".repeat(stars) + "☆".repeat(3 - stars), 64, Color("f0e442")))
	v.add_child(StudioUI.label("%d moves  ·  par %d" % [session.moves, level.par], 28, Palette.TEXT_DIM))
	if result.get("seeds", 0) > 0:
		v.add_child(StudioUI.label("+%d seeds" % result.seeds, 34))
	for line in result.get("unlocks", []):
		v.add_child(StudioUI.label(line, 28, Palette.ACCENT))
	if result.get("has_next", false):
		v.add_child(StudioUI.button("Next level", func(): host.next_level(level, mode)))
	v.add_child(StudioUI.button("Replay", _restart))
	v.add_child(StudioUI.button("Menu", _quit))


func _show_time_up() -> void:
	host.track("level_failed", {"level": level.id, "mode": mode, "reason": "time"})
	var v := _open_overlay()
	v.add_child(StudioUI.label("Time is up", 44))
	v.add_child(StudioUI.label("The challenge timer ran out. Try again?", 28, Palette.TEXT_DIM))
	v.add_child(StudioUI.button("Try again", _restart))
	v.add_child(StudioUI.button("Menu", _quit))


func _show_hint_offer() -> void:
	var v := _open_overlay()
	v.add_child(StudioUI.label("Out of hints", 40))
	v.add_child(StudioUI.label("Hints are optional. You can earn one by watching a short ad, or get a hint pack in the store.", 26, Palette.TEXT_DIM))
	var ad := StudioUI.button("Watch ad for 1 hint", func():
		_close_overlay()
		host.offer_rewarded_hint(func(granted: bool):
			if granted:
				_apply_hint()
			else:
				host.toast("No hint this time. The ad did not finish.")
			_update_labels()))
	ad.disabled = not host.rewarded_available()
	v.add_child(ad)
	v.add_child(StudioUI.button("Keep solving", _close_overlay))


func _pause() -> void:
	if _overlay != null or session.is_solved:
		return
	_paused = true
	var v := _open_overlay()
	v.add_child(StudioUI.label("Paused", 44))
	v.add_child(StudioUI.button("Resume", func():
		_close_overlay()
		_paused = false))
	v.add_child(StudioUI.button("Restart", _restart))
	v.add_child(StudioUI.button("Settings", func(): host.open_settings_overlay(self)))
	v.add_child(StudioUI.button("Quit to menu", _quit))


## Android back button: open/close the pause menu instead of leaving mid-puzzle.
func handle_back() -> bool:
	if session.is_solved:
		return false
	if _overlay != null:
		_close_overlay()
		_paused = false
	else:
		_pause()
	return true


func _quit() -> void:
	if not session.is_solved:
		host.track("level_failed", {"level": level.id, "mode": mode, "reason": "quit", "moves": session.moves})
	exited.emit()
	set_process(false)
	host.go_back_from_game(mode)


func _open_overlay() -> VBoxContainer:
	_close_overlay()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(holder)
	_overlay = holder
	return StudioUI.modal(holder)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
