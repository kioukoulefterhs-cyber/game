class_name CGGardenView
extends Control
## Draws the player's garden: theme sky and ground, owned plants and decorations.
## Newly added plants grow in with a short celebration.

var theme_def: Dictionary = {}
var plants: Array = [] ## plant definitions, in planting order
var decor: Array = [] ## decor ids
var _t := 0.0
var _last_draw := -1.0
var _grow := {} ## plant id -> time it was added
var reduce_motion := false


func set_garden(p_theme: Dictionary, p_plants: Array, p_decor: Array) -> void:
	theme_def = p_theme
	plants = p_plants
	decor = p_decor
	queue_redraw()


func celebrate(id: String) -> void:
	_grow[id] = _t


func _process(delta: float) -> void:
	_t += delta
	# Ambient animation: 30 redraws a second is smooth enough and saves battery.
	if _t - _last_draw >= 1.0 / 30.0:
		_last_draw = _t
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sky := Color(theme_def.get("sky", "1d3b4f"))
	var ground := Color(theme_def.get("ground", "2f5d3a"))
	draw_rect(r, sky)
	var horizon := size.y * 0.42
	if theme_def.get("id", "") == "moonlight":
		draw_circle(Vector2(size.x * 0.8, size.y * 0.14), size.x * 0.07, Color("f2efe6"))
		for i in 18:
			var p := Vector2(fmod(i * 97.0, size.x), fmod(i * 53.0, horizon))
			draw_circle(p, 1.5 + (i % 3), Color(1, 1, 1, 0.5 + 0.5 * sin(_t * 2.0 + i)))
	elif theme_def.get("id", "") == "fireflies":
		for i in 14:
			var p := Vector2(fmod(i * 131.0 + 40.0 * sin(_t * 0.5 + i), size.x), fmod(i * 71.0, size.y * 0.9))
			draw_circle(p, 3.0 + (i % 2), Color(0.95, 0.9, 0.4, 0.4 + 0.4 * sin(_t * 3.0 + i * 1.3)))
	elif theme_def.get("id", "") == "greenhouse":
		for i in 6:
			var x := size.x * (i + 0.5) / 6.0
			draw_line(Vector2(x, 0), Vector2(x, horizon), Color(1, 1, 1, 0.12), 4)
		draw_line(Vector2(0, horizon * 0.5), Vector2(size.x, horizon * 0.5), Color(1, 1, 1, 0.12), 4)
	else:
		draw_circle(Vector2(size.x * 0.82, size.y * 0.13), size.x * 0.08, Color("f0e442"))
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), ground)
	_draw_decor(horizon)
	var cols := 4
	var rows := maxi(1, ceili(plants.size() / float(cols)))
	for i in plants.size():
		var row := i / cols
		var col := i % cols
		var x := size.x * (col + 0.5 + (0.25 if row % 2 else 0.0)) / (cols + 0.25)
		var y := horizon + (size.y - horizon) * (row + 1) / (rows + 0.6)
		var scale := size.x / 720.0 * (0.85 + 0.25 * row / maxf(1, rows))
		var grow := 1.0
		var def: Dictionary = plants[i]
		if _grow.has(def.id) and not reduce_motion:
			grow = clampf((_t - _grow[def.id]) / 1.2, 0.0, 1.0)
			if grow < 1.0:
				for s in 10:
					var a := TAU * s / 10.0 + _t
					draw_circle(Vector2(x, y - 80 * scale) + Vector2.from_angle(a) * 90.0 * scale * grow, 5 * scale, Color("f0e442", 1.0 - grow))
		draw_plant(self, def, Vector2(x, y), 220.0 * scale, grow, _t)
	if plants.is_empty():
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, size.y * 0.7), "Plant your first flower below", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.7))


func _draw_decor(horizon: float) -> void:
	var s := size.x / 720.0
	if "stones" in decor:
		for i in 7:
			draw_circle(Vector2(size.x * (0.1 + i * 0.13), size.y - 30 * s - (i % 2) * 14 * s), 16 * s, Color("8a8f86"))
	if "pond" in decor:
		draw_set_transform(Vector2(size.x * 0.2, horizon + 40 * s), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 90 * s, Color("3f7fa8"))
		draw_circle(Vector2(sin(_t) * 20 * s, 0), 30 * s, Color("5aa0c8"))
		draw_set_transform(Vector2.ZERO)
	if "bench" in decor:
		var b := Vector2(size.x * 0.78, horizon + 30 * s)
		draw_rect(Rect2(b + Vector2(-60, -30) * s, Vector2(120, 14) * s), Color("8b5a2b"))
		draw_rect(Rect2(b + Vector2(-60, -6) * s, Vector2(120, 12) * s), Color("8b5a2b"))
		draw_rect(Rect2(b + Vector2(-52, 6) * s, Vector2(10, 24) * s), Color("5c3a1a"))
		draw_rect(Rect2(b + Vector2(42, 6) * s, Vector2(10, 24) * s), Color("5c3a1a"))
	if "lantern" in decor:
		var l := Vector2(size.x * 0.5, horizon - 10 * s)
		draw_line(l, l + Vector2(0, 60) * s, Color("333"), 5 * s)
		var glow := 0.6 + 0.4 * sin(_t * 3.0)
		draw_circle(l, 26 * s, Color(1.0, 0.85, 0.4, 0.25 * glow))
		draw_circle(l, 12 * s, Color(1.0, 0.85, 0.4, glow))


## Draws one plant. `grow` 0..1 scales it in; petals 0 means a leafy plant.
static func draw_plant(ci: CanvasItem, def: Dictionary, base: Vector2, height: float, grow: float, t: float) -> void:
	var h := height * float(def.get("height", 0.6)) * grow
	if h <= 1.0:
		return
	var sway := sin(t * 1.3 + base.x * 0.01) * 6.0 * grow
	var top := base + Vector2(sway, -h)
	var stem := Color("3e8e4e")
	var w := maxf(2.0, height * 0.035)
	ci.draw_line(base, top, stem, w)
	ci.draw_colored_polygon(_leaf(base.lerp(top, 0.45), Vector2(1, -0.4), height * 0.16 * grow), stem.lightened(0.1))
	ci.draw_colored_polygon(_leaf(base.lerp(top, 0.3), Vector2(-1, -0.4), height * 0.14 * grow), stem.lightened(0.1))
	var col := Color(def.get("color", "ffffff"))
	var petals := int(def.get("petals", 0))
	var r := height * 0.09 * grow
	if petals == 0:
		for k in 5:
			var a := -PI / 2 + (k - 2) * 0.45
			ci.draw_colored_polygon(_leaf(top, Vector2.from_angle(a), height * 0.2 * grow), col)
		return
	for k in petals:
		var a := TAU * k / petals + t * 0.2
		ci.draw_circle(top + Vector2.from_angle(a) * r * 1.1, r * (0.9 if petals < 8 else 0.6), col)
	ci.draw_circle(top, r * 0.75, col.darkened(0.45))
	ci.draw_circle(top, r * 0.35, Color("f0e442"))


static func _leaf(at: Vector2, dir: Vector2, length: float) -> PackedVector2Array:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	return PackedVector2Array([at, at + d * length * 0.5 + n * length * 0.22, at + d * length, at + d * length * 0.5 - n * length * 0.22])
