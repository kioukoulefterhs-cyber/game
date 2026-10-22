extends "res://scripts/ui/screens/screen_base.gd"
## Main menu.


func _ready() -> void:
	build("", false)
	body.add_child(StudioUI.spacer(40))
	var logo := preload("res://scripts/ui/logo_view.gd").new()
	logo.custom_minimum_size = Vector2(0, 360)
	body.add_child(logo)
	body.add_child(StudioUI.label("Circuit Garden", 64, Palette.TEXT))
	body.add_child(StudioUI.label("Rotate the vines. Power the flowers.", 28, Palette.TEXT_DIM))
	body.add_child(StudioUI.spacer(0, true))
	var done := Game.completed_count()
	var play_text := "Play" if done == 0 else "Continue: Level %d" % (Game.next_unplayed_index() + 1)
	body.add_child(StudioUI.button(play_text, func(): host.play_level(Game.next_unplayed_index())))
	body.add_child(StudioUI.button("Levels", func(): host.show_screen("levels")))
	body.add_child(StudioUI.button("Daily challenge", func(): host.show_screen("daily")))
	var row := StudioUI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for item in [["Garden", "garden"], ["Store", "store"], ["Settings", "settings"]]:
		var b := StudioUI.button(item[0], func(): host.show_screen(item[1]))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b)
	body.add_child(StudioUI.label("%d seeds  ·  %d / %d levels" % [Game.seeds(), done, Game.levels.size()], 26, Palette.TEXT_DIM))
