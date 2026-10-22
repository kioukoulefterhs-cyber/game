class_name CGBoardView
extends Control
## Draws a CGSession board with procedural vector graphics and animated energy flow.
## Emits cell_tapped; it never changes the session itself.

signal cell_tapped(index: int)

const Palette := preload("res://scripts/ui/palette.gd")

var session: CGSession
var reduce_motion := false

var _angle := PackedFloat32Array() ## Displayed rotation per cell, in quarter turns.
var _dist := {}
var _time := 0.0
var _win_t := -1.0
var _pop := {} ## cell -> time of last tap, for a squash animation
var _hint_flash := {}


func bind(s: CGSession) -> void:
	session = s
	_angle.resize(s.board.cell_count())
	for i in s.board.cell_count():
		_angle[i] = s.board.rot[i]
	_win_t = -1.0
	if not s.changed.is_connected(_on_changed):
		s.changed.connect(_on_changed)
		s.solved.connect(_on_solved)
	_on_changed()


func flash_hint(i: int) -> void:
	_hint_flash[i] = _time


func _on_changed() -> void:
	if session.board.cell_count() != _angle.size():
		bind(session)
		return
	# Animate single quarter turns (tap, undo); snap bigger jumps (restart, hint).
	for i in session.board.cell_count():
		var target := float(session.board.rot[i])
		var delta := fposmod(target - _angle[i], 4.0)
		if delta > 1.01 and delta < 2.99:
			_angle[i] = target
	_dist = session.board.flow_distances(session.analysis)
	queue_redraw()


func _on_solved() -> void:
	_win_t = _time


func note_tap(i: int) -> void:
	_pop[i] = _time


func _process(delta: float) -> void:
	_time += delta
	if session == null:
		return
	var speed := 14.0 if not reduce_motion else 100.0
	for i in _angle.size():
		var target := float(session.board.rot[i])
		var diff := fposmod(target - _angle[i], 4.0)
		if diff > 2.0:
			diff -= 4.0
		if absf(diff) > 0.001:
			_angle[i] += diff * minf(1.0, delta * speed)
			if absf(fposmod(target - _angle[i] + 2.0, 4.0) - 2.0) < 0.01:
				_angle[i] = target
	queue_redraw()


func board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func cell_size() -> float:
	return board_rect().size.x / maxi(1, session.board.size) if session else 0.0


func cell_center(i: int) -> Vector2:
	var cs := cell_size()
	var r := board_rect()
	var n := session.board.size
	return r.position + Vector2((i % n + 0.5) * cs, (i / n + 0.5) * cs)


func cell_at(p: Vector2) -> int:
	if session == null:
		return -1
	var r := board_rect()
	if not r.has_point(p):
		return -1
	var cs := cell_size()
	var c := int((p.x - r.position.x) / cs)
	var row := int((p.y - r.position.y) / cs)
	var n := session.board.size
	if c < 0 or row < 0 or c >= n or row >= n:
		return -1
	return row * n + c


func _gui_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse events (Godot's default on Android), so handling
	# only mouse buttons avoids double taps.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := cell_at(event.position)
		if i >= 0:
			cell_tapped.emit(i)
			accept_event()


func _draw() -> void:
	if session == null:
		return
	var b := session.board
	var r := board_rect()
	var cs := cell_size()
	draw_rect(r.grow(cs * 0.08), Palette.BOARD, true)
	var win_k := 0.0
	if _win_t >= 0.0:
		win_k = clampf((_time - _win_t) / 0.9, 0.0, 1.0)
	for i in b.cell_count():
		_draw_cell(i, cs, win_k)
	if _win_t >= 0.0 and not reduce_motion:
		_draw_celebration(r, cs)


func _arm_color(i: int, world_dir: int) -> Color:
	var b := session.board
	var key := i * 2 + CGBoard.channel_of(b.types[i], world_dir)
	var net_id: int = session.analysis.node_net.get(key, -1)
	if net_id < 0:
		return Palette.VINE_OFF
	var net: Dictionary = session.analysis.networks[net_id]
	if net.shorted:
		return Palette.SHORT
	if net.color >= 0:
		return Palette.color(net.color)
	return Palette.VINE_OFF


func _draw_cell(i: int, cs: float, win_k: float) -> void:
	var b := session.board
	var t: int = b.types[i]
	var center := cell_center(i)
	var half := cs * 0.5
	var pop := 1.0
	if _pop.has(i):
		var k: float = (_time - _pop[i]) / 0.18
		pop = 1.0 - 0.08 * sin(clampf(k, 0.0, 1.0) * PI)
	if win_k > 0.0:
		var wave := clampf(win_k * 2.0 - float(i % b.size + i / b.size) / (2.0 * b.size), 0.0, 1.0)
		pop *= 1.0 + 0.06 * sin(wave * PI)
	draw_set_transform(center, 0.0, Vector2(pop, pop))
	var tile_rect := Rect2(Vector2(-half, -half) * 0.92, Vector2(cs, cs) * 0.92)
	if t == CGBoard.Tile.BLOCKED:
		_draw_rock(half)
		draw_set_transform(Vector2.ZERO)
		return
	if t == CGBoard.Tile.EMPTY:
		draw_set_transform(Vector2.ZERO)
		return
	var bg := Palette.TILE
	if b.is_rotatable(i):
		bg = Palette.TILE_ROT
	draw_rect(tile_rect, bg, true)
	if _hint_flash.has(i):
		var hk: float = (_time - _hint_flash[i]) / 1.2
		if hk < 1.0:
			draw_rect(tile_rect, Color(1, 1, 1, 0.35 * (1.0 - hk)), true)
	var width := cs * 0.16
	var base: int = CGBoard.BASE_MASK[t]
	var ang := _angle[i] * PI * 0.5
	var rot_int := b.rot[i]
	# Arms: draw unrotated base arms under the animated angle; colour by the world direction.
	var arms: Array = []
	for d in CGBoard.DIRS:
		if base & d:
			arms.append(d)
	if t == CGBoard.Tile.CROSS:
		# Vertical channel under, horizontal channel over with a bridge outline.
		var cv := _arm_color(i, CGBoard.N)
		var ch := _arm_color(i, CGBoard.E)
		draw_line(Vector2(0, -half), Vector2(0, half), cv, width)
		_draw_flow_segment(i, 0, Vector2(0, -half), Vector2(0, half), cv, width)
		draw_line(Vector2(-half, 0), Vector2(half, 0), Palette.TILE, width * 1.9)
		draw_line(Vector2(-half, 0), Vector2(half, 0), ch, width)
		_draw_flow_segment(i, 1, Vector2(-half, 0), Vector2(half, 0), ch, width)
	else:
		for d in arms:
			var world := CGBoard.rotate_mask(d, rot_int)
			var col := _arm_color(i, world)
			var dir_v := _dir_vec(d).rotated(ang)
			var end := dir_v * half
			draw_line(Vector2.ZERO, end, col, width)
			draw_circle(Vector2.ZERO, width * 0.5, col)
			_draw_flow_segment(i, 0, Vector2.ZERO, end, col, width)
	match t:
		CGBoard.Tile.SOURCE:
			var col := Palette.color(b.colors[i])
			draw_circle(Vector2.ZERO, cs * 0.30, col.darkened(0.45))
			draw_circle(Vector2.ZERO, cs * 0.25, col)
			Palette.draw_symbol(self, b.colors[i], Vector2.ZERO, cs * 0.12, Palette.INK)
		CGBoard.Tile.RECEIVER:
			_draw_flower(i, cs)
		CGBoard.Tile.CAP:
			var col := _arm_color(i, CGBoard.rotate_mask(CGBoard.N, rot_int))
			_draw_leaf(cs, col)
	if b.locked[i] and b.types[i] in [CGBoard.Tile.STRAIGHT, CGBoard.Tile.ELBOW, CGBoard.Tile.TEE, CGBoard.Tile.CAP]:
		draw_circle(Vector2(half, -half) * 0.66, cs * 0.06, Palette.PIN)
	draw_set_transform(Vector2.ZERO)


func _draw_flow_segment(i: int, ch: int, from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var key := i * 2 + ch
	if not _dist.has(key) or col == Palette.VINE_OFF or col == Palette.SHORT:
		return
	if reduce_motion:
		draw_line(from, to, col.lightened(0.35), width * 0.35)
		return
	var phase := fposmod(_time * 1.6 - float(_dist[key]) * 0.5, 1.0)
	for k in 2:
		var f := fposmod(phase + k * 0.5, 1.0)
		draw_circle(from.lerp(to, f), width * 0.32, col.lightened(0.6))


func _draw_flower(i: int, cs: float) -> void:
	var b := session.board
	var col := Palette.color(b.colors[i])
	var net_id: int = session.analysis.node_net.get(i * 2, -1)
	var lit: bool = net_id >= 0 and session.analysis.networks[net_id].color == b.colors[i]
	var petals := 6
	var open_k := 1.0 if lit else 0.35
	for p in petals:
		var a := TAU * p / petals + _time * (0.4 if lit and not reduce_motion else 0.0)
		var pos := Vector2.from_angle(a) * cs * 0.16 * (0.6 + 0.4 * open_k)
		draw_circle(pos, cs * 0.11 * open_k + cs * 0.03, col if lit else col.darkened(0.55))
	draw_circle(Vector2.ZERO, cs * 0.14, Palette.INK if lit else Palette.TILE)
	Palette.draw_symbol(self, b.colors[i], Vector2.ZERO, cs * 0.09, col if lit else col.darkened(0.2))


func _draw_leaf(cs: float, col: Color) -> void:
	draw_circle(Vector2.ZERO, cs * 0.13, col)
	draw_circle(Vector2.ZERO, cs * 0.07, Palette.TILE)


func _draw_rock(half: float) -> void:
	var pts := PackedVector2Array()
	for k in 7:
		var a := TAU * k / 7.0
		var rr := half * (0.62 + 0.12 * sin(k * 2.3))
		pts.append(Vector2.from_angle(a) * rr)
	draw_colored_polygon(pts, Palette.ROCK)


func _draw_celebration(r: Rect2, cs: float) -> void:
	var k := _time - _win_t
	if k > 2.2:
		return
	var center := r.get_center()
	for p in 28:
		var a := TAU * p / 28.0 + p * 0.37
		var dist := (0.2 + k * 0.9) * r.size.x * (0.35 + 0.15 * sin(p * 1.7))
		var alpha := clampf(1.0 - k / 2.2, 0.0, 1.0)
		var col := Palette.color(p % 4)
		col.a = alpha
		draw_circle(center + Vector2.from_angle(a) * dist, cs * 0.06 * (1.0 + sin(p)), col)


static func _dir_vec(d: int) -> Vector2:
	match d:
		CGBoard.N:
			return Vector2.UP
		CGBoard.E:
			return Vector2.RIGHT
		CGBoard.S:
			return Vector2.DOWN
	return Vector2.LEFT
