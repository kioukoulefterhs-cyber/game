extends "res://scripts/ui/screens/screen_base.gd"
## Settings: sound, motion, privacy choices, purchases and progress reset.


func _ready() -> void:
	build("Settings")
	var list := scroll_area()
	list.add_child(StudioUI.label("Sound effects", 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.settings.get_value("sfx_volume")
	vol.custom_minimum_size = Vector2(0, 72)
	vol.value_changed.connect(func(v):
		Game.settings.set_value("sfx_volume", v)
		Game.audio.play("tap"))
	list.add_child(vol)
	list.add_child(_toggle("Reduce motion", "reduce_motion"))
	list.add_child(_toggle("Show timer", "show_timer"))
	list.add_child(StudioUI.label("Privacy", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	var consent := CheckButton.new()
	consent.text = "Share anonymous gameplay stats"
	consent.custom_minimum_size.y = StudioUI.MIN_TOUCH
	consent.button_pressed = Game.settings.get_value("analytics_consent") == "granted"
	consent.toggled.connect(func(on): Game.settings.set_value("analytics_consent", "granted" if on else "denied"))
	list.add_child(consent)
	list.add_child(StudioUI.button("Privacy policy and support", func(): host.show_screen("about")))
	list.add_child(StudioUI.label("Purchases", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	list.add_child(StudioUI.button("Restore purchases", func():
		Game.billing.restore_purchases()
		host.toast("Checking the store for your purchases")))
	list.add_child(StudioUI.label("Progress", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	var reset := StudioUI.button("Reset progress", _confirm_reset)
	list.add_child(reset)


func _toggle(text: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.custom_minimum_size.y = StudioUI.MIN_TOUCH
	c.button_pressed = bool(Game.settings.get_value(key))
	c.toggled.connect(func(on): Game.settings.set_value(key, on))
	return c


func _confirm_reset() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(holder)
	var v := StudioUI.modal(holder)
	v.add_child(StudioUI.label("Reset all progress?", 36))
	v.add_child(StudioUI.label("Levels, seeds and garden will be cleared. Purchases can be restored from the store.", 26, Palette.TEXT_DIM))
	v.add_child(StudioUI.button("Reset", func():
		Game.reset_progress()
		holder.queue_free()
		host.toast("Progress reset")))
	v.add_child(StudioUI.button("Cancel", holder.queue_free))
