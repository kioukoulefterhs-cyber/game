extends RefCounted
## Colors and colorblind-safe symbols. Energy colors follow the Okabe-Ito palette,
## and every color is paired with a distinct shape so color is never the only cue.

const BG := Color("12201b")
const BOARD := Color("1a2c25")
const TILE := Color("223830")
const TILE_ROT := Color("29443a")
const VINE_OFF := Color("4f6b5e")
const SHORT := Color("ffffff")
const ROCK := Color("5b5f66")
const PIN := Color("f2efe6")
const INK := Color("0e1714")
const TEXT := Color("f2efe6")
const TEXT_DIM := Color("a9bdb3")
const ACCENT := Color("7fd17f")

const ENERGY := [
	Color("e69f00"), # orange, circle
	Color("56b4e9"), # sky blue, square
	Color("cc79a7"), # reddish purple, triangle
	Color("f0e442"), # yellow, diamond
	Color("009e73"), # bluish green, hexagon
	Color("d55e00"), # vermillion, star
]
const SYMBOL_NAMES := ["circle", "square", "triangle", "diamond", "hexagon", "star"]


static func color(i: int) -> Color:
	if i < 0:
		return VINE_OFF
	return ENERGY[i % ENERGY.size()]


static func draw_symbol(ci: CanvasItem, i: int, at: Vector2, r: float, col: Color) -> void:
	match i % 6:
		0:
			ci.draw_circle(at, r, col)
		1:
			ci.draw_rect(Rect2(at - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), col, true)
		2:
			ci.draw_colored_polygon(_ngon(at, r * 1.15, 3, -PI / 2), col)
		3:
			ci.draw_colored_polygon(_ngon(at, r * 1.15, 4, 0.0), col)
		4:
			ci.draw_colored_polygon(_ngon(at, r, 6, 0.0), col)
		5:
			var pts := PackedVector2Array()
			for k in 10:
				var rr := r * (1.2 if k % 2 == 0 else 0.5)
				pts.append(at + Vector2.from_angle(-PI / 2 + TAU * k / 10.0) * rr)
			ci.draw_colored_polygon(pts, col)


static func _ngon(at: Vector2, r: float, sides: int, offset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in sides:
		pts.append(at + Vector2.from_angle(offset + TAU * k / sides) * r)
	return pts
