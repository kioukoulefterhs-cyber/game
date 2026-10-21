extends RefCounted
## Builds boards from compact text for tests.


## rows: tile codes per row; rots: rotation digits per row; colors: dict cell -> color.
static func board(rows: Array, rots: Array, colors: Dictionary = {}) -> CGBoard:
	var n: int = rows.size()
	var b := CGBoard.create(n)
	for r in n:
		for c in n:
			var i := r * n + c
			b.types[i] = CGBoard.CODES[rows[r][c]]
			b.rot[i] = int(rots[r][c])
	for i in colors:
		b.colors[i] = colors[i]
	return b
