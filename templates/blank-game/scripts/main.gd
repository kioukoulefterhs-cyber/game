extends Control
## Template main menu with a settings panel. Replace "Play" with your game.

var _content: VBoxContainer


func _ready() -> void:
	theme = StudioUI.make_theme()
	var bg := ColorRect.new()
	bg.color = Color("16202a")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := StudioUI.safe_margin(self)
	_content = StudioUI.vbox(20)
	margin.add_child(_content)
	_menu()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _menu() -> void:
	_clear()
	_content.add_child(StudioUI.spacer(0, true))
	_content.add_child(StudioUI.label(ProjectSettings.get_setting("application/config/name"), 56))
	_content.add_child(StudioUI.spacer(0, true))
	_content.add_child(StudioUI.button("Play", func():
		Studio.audio.play("click")
		Studio.analytics.track("game_start")))
	_content.add_child(StudioUI.button("Settings", _settings))


func _settings() -> void:
	_clear()
	_content.add_child(StudioUI.label("Settings", 44))
	var vol := HSlider.new()
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Studio.settings.get_value("sfx_volume")
	vol.custom_minimum_size.y = 72
	vol.value_changed.connect(func(v): Studio.settings.set_value("sfx_volume", v))
	_content.add_child(StudioUI.label("Sound", 30))
	_content.add_child(vol)
	var consent := CheckButton.new()
	consent.text = "Share anonymous gameplay stats"
	consent.button_pressed = Studio.settings.get_value("analytics_consent") == "granted"
	consent.toggled.connect(func(on): Studio.settings.set_value("analytics_consent", "granted" if on else "denied"))
	_content.add_child(consent)
	_content.add_child(StudioUI.spacer(0, true))
	_content.add_child(StudioUI.button("Back", _menu))
