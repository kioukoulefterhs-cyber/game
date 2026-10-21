extends Control
## Shared layout for menu-style screens: background, safe-area margins, header with back.

const Palette := preload("res://scripts/ui/palette.gd")

var host
var data: Dictionary
var body: VBoxContainer


func setup(p_host, p_data: Dictionary) -> void:
	host = p_host
	data = p_data


func build(title: String, with_back := true) -> VBoxContainer:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := StudioUI.safe_margin(self)
	var col := StudioUI.vbox(20)
	margin.add_child(col)
	if title != "":
		var head := StudioUI.hbox(12)
		col.add_child(head)
		if with_back:
			head.add_child(StudioUI.button("<", func(): host.go_back()))
		var l := StudioUI.label(title, 40)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		head.add_child(l)
		if with_back:
			head.add_child(StudioUI.spacer())
			head.get_child(head.get_child_count() - 1).custom_minimum_size.x = StudioUI.MIN_TOUCH
	body = col
	return col


## A vertical scroll area that expands to fill the rest of the screen.
func scroll_area() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v := StudioUI.vbox(16)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	sc.add_child(v)
	return v
