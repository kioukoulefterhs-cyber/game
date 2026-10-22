extends "res://scripts/ui/screens/screen_base.gd"
## Level selection grouped by band, with stars and locks.


func _ready() -> void:
	build("Levels")
	var list := scroll_area()
	var band := ""
	var grid: GridContainer
	for i in Game.levels.size():
		var lv: CGLevel = Game.levels[i]
		var b_name: String = lv.difficulty.get("band", "")
		if b_name != band:
			band = b_name
			list.add_child(StudioUI.label("%s  ·  %dx%d  ·  %s" % [band, lv.size, lv.size, _label_range(i)], 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
			grid = GridContainer.new()
			grid.columns = 5
			grid.size_flags_horizontal = SIZE_EXPAND_FILL
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 12)
			list.add_child(grid)
		var rec := Game.level_record(lv.id)
		var stars := int(rec.get("stars", 0))
		var unlocked := Game.is_unlocked(i)
		var text := str(i + 1)
		if stars > 0:
			text += "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
		elif not unlocked:
			text += "\nlocked"
		var b := StudioUI.button(text, func(): host.play_level(i), 100)
		b.custom_minimum_size.y = 112
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.disabled = not unlocked
		grid.add_child(b)


## "Easy" or "Easy to Medium": the measured difficulty labels across the band starting at index.
func _label_range(start: int) -> String:
	var band: String = Game.levels[start].difficulty.get("band", "")
	var first: String = Game.levels[start].difficulty.get("label", "")
	var last := first
	for k in range(start, Game.levels.size()):
		if Game.levels[k].difficulty.get("band", "") != band:
			break
		last = Game.levels[k].difficulty.get("label", last)
	return first if first == last else "%s to %s" % [first, last]
