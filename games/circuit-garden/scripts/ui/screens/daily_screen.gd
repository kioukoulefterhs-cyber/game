extends "res://scripts/ui/screens/screen_base.gd"
## Daily challenge: one generated puzzle per calendar day, playable offline.


func _ready() -> void:
	build("Daily challenge")
	var lv := Game.today_daily()
	body.add_child(StudioUI.spacer(20))
	if lv == null:
		body.add_child(StudioUI.label("Today's puzzle could not be generated.", 30))
		return
	body.add_child(StudioUI.label(lv.id.trim_prefix("daily-"), 44))
	body.add_child(StudioUI.label("%dx%d board  ·  %d colors" % [lv.size, lv.size, lv.color_count()], 28, Palette.TEXT_DIM))
	body.add_child(StudioUI.label("Streak: %d day%s" % [Game.daily_streak(), "" if Game.daily_streak() == 1 else "s"], 30))
	if Game.daily_done(lv):
		body.add_child(StudioUI.label("Done for today! Come back tomorrow for a new garden.", 28, Palette.ACCENT))
	else:
		body.add_child(StudioUI.label("Finish it for +%d seeds." % Game.SEEDS_DAILY, 28, Palette.ACCENT))
	body.add_child(StudioUI.spacer(0, true))
	body.add_child(StudioUI.button("Play relaxed", func(): host.play_daily(false)))
	body.add_child(StudioUI.button("Play timed (5:00)", func(): host.play_daily(true)))
