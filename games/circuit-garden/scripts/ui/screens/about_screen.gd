extends "res://scripts/ui/screens/screen_base.gd"
## Privacy, support and credits.


func _ready() -> void:
	build("Privacy and support")
	var list := scroll_area()
	list.add_child(StudioUI.label("Circuit Garden %s" % ProjectSettings.get_setting("application/config/version"), 30))
	list.add_child(StudioUI.label("Circuit Garden works fully offline and has no accounts. Progress is stored only on this device. Anonymous gameplay stats are sent only if you allow them, and the current build does not send them anywhere yet.", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	list.add_child(StudioUI.button("Privacy policy", func(): host.open_url(host.PRIVACY_URL)))
	list.add_child(StudioUI.button("Contact support", func(): host.open_url(host.SUPPORT_URL)))
	list.add_child(StudioUI.label("Credits", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	list.add_child(StudioUI.label("Made with Godot Engine (MIT license, godotengine.org/license). All art and sound are generated procedurally by the game.", 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
