class_name StudioUI
extends RefCounted
## Small helpers for building touch-friendly portrait UI in code.
## Sizes are in base-viewport pixels (designed for a 720x1280 canvas_items stretch).

const MIN_TOUCH := 96.0

static var text_color := Color("f2efe6")
static var dim_color := Color("a9bdb3")
static var button_color := Color("2f5446")
static var button_hover := Color("3b6a58")
static var button_pressed := Color("244236")
static var panel_color := Color("1a2c25")
static var accent := Color("7fd17f")


## Builds a project-wide theme with large type and rounded, high-contrast buttons.
static func make_theme(base_font_size: int = 30) -> Theme:
	var t := Theme.new()
	t.default_font_size = base_font_size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(22)
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		match state:
			"normal":
				sb.bg_color = button_color
			"hover":
				sb.bg_color = button_hover
			"pressed":
				sb.bg_color = button_pressed
			"disabled":
				sb.bg_color = button_color.darkened(0.45)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.draw_center = false
				sb.border_color = accent
				sb.set_border_width_all(3)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", text_color)
	t.set_color("font_pressed_color", "Button", text_color)
	t.set_color("font_disabled_color", "Button", dim_color.darkened(0.3))
	t.set_color("font_color", "Label", text_color)
	var panel := StyleBoxFlat.new()
	panel.bg_color = panel_color
	panel.set_corner_radius_all(28)
	panel.content_margin_left = 32
	panel.content_margin_right = 32
	panel.content_margin_top = 28
	panel.content_margin_bottom = 28
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


static func button(text: String, on_pressed: Callable = Callable(), min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_w, MIN_TOUCH), MIN_TOUCH)
	b.focus_mode = Control.FOCUS_NONE
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


static func label(text: String, font_size: int = 30, color: Color = text_color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func vbox(spacing: int = 20) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", spacing)
	return v


static func hbox(spacing: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", spacing)
	return h


## A full-rect margin container that respects the device safe area (notches, cutouts).
static func safe_margin(parent: Control, margin: int = 28) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var top_extra := 0
	var bottom_extra := 0
	if screen.y > 0 and safe.size.y > 0:
		var scale := 1280.0 / float(screen.y)
		top_extra = int(safe.position.y * scale)
		bottom_extra = int((screen.y - safe.end.y) * scale)
	m.add_theme_constant_override("margin_left", margin)
	m.add_theme_constant_override("margin_right", margin)
	m.add_theme_constant_override("margin_top", margin + top_extra)
	m.add_theme_constant_override("margin_bottom", margin + bottom_extra)
	parent.add_child(m)
	return m


## A dimmed full-screen overlay holding a centered panel. Returns the panel's VBox.
static func modal(parent: Control, dim: float = 0.6) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := vbox(22)
	panel.add_child(v)
	return v


static func spacer(h: float = 0.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c
