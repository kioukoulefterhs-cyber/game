extends Control
## Animated title art: a small powered circuit blooming, drawn procedurally.

const Palette := preload("res://scripts/ui/palette.gd")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.42
	var w := s * 0.12
	var pts := [c + Vector2(-s, s * 0.6), c + Vector2(-s, 0), c + Vector2(0, 0), c + Vector2(0, -s * 0.7)]
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], Palette.ENERGY[0], w)
		draw_circle(pts[i + 1], w * 0.5, Palette.ENERGY[0])
	draw_line(c, c + Vector2(s, 0), Palette.ENERGY[1], w)
	draw_line(c + Vector2(s, 0), c + Vector2(s, s * 0.6), Palette.ENERGY[1], w)
	for i in pts.size() - 1:
		var f := fposmod(_t * 0.8 - i * 0.33, 1.0)
		draw_circle(pts[i].lerp(pts[i + 1], f), w * 0.3, Palette.ENERGY[0].lightened(0.6))
	draw_circle(pts[0], s * 0.2, Palette.ENERGY[0])
	draw_circle(pts[0], s * 0.08, Palette.INK)
	var head: Vector2 = pts[3]
	for p in 6:
		var a := TAU * p / 6.0 + _t * 0.5
		draw_circle(head + Vector2.from_angle(a) * s * 0.16, s * 0.12, Palette.ENERGY[0])
	draw_circle(head, s * 0.11, Palette.INK)
	var head2 := c + Vector2(s, s * 0.6)
	for p in 5:
		var a := TAU * p / 5.0 - _t * 0.4
		draw_circle(head2 + Vector2.from_angle(a) * s * 0.14, s * 0.1, Palette.ENERGY[1])
	draw_circle(head2, s * 0.09, Palette.INK)
