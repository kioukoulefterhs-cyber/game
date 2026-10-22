class_name CGLevel
extends RefCounted
## A level: tiles, the scrambled start, the unique solution and metadata.
## JSON format is documented in docs/level-format.md.

const FORMAT := "circuit-garden-level"
const VERSION := 1

var id: String = ""
var size: int = 4
var level_seed: int = 0
var codes: String = ""
var colors := PackedInt32Array()
var start := PackedInt32Array()
var solution := PackedInt32Array()
var locked := PackedInt32Array()
var min_moves: int = 0
var par: int = 0
var difficulty: Dictionary = {}


## Builds a fresh board in the scrambled start state.
func make_board() -> CGBoard:
	var b := CGBoard.create(size)
	for i in size * size:
		b.types[i] = CGBoard.CODES[codes[i]]
		b.colors[i] = colors[i]
		b.rot[i] = start[i]
	for i in locked:
		b.locked[i] = 1
		b.rot[i] = solution[i]
	return b


func make_solved_board() -> CGBoard:
	var b := make_board()
	for i in size * size:
		b.rot[i] = solution[i]
	return b


func solution_masks() -> PackedInt32Array:
	return make_solved_board().masks()


func color_count() -> int:
	var seen := {}
	for c in colors:
		if c >= 0:
			seen[c] = true
	return seen.size()


func to_dict() -> Dictionary:
	return {
		"format": FORMAT, "version": VERSION, "id": id, "size": size, "seed": level_seed,
		"tiles": codes, "colors": Array(colors), "start": Array(start),
		"solution": Array(solution), "locked": Array(locked),
		"min_moves": min_moves, "par": par, "difficulty": difficulty,
	}


static func from_dict(d: Dictionary) -> CGLevel:
	if d.get("format", "") != FORMAT or int(d.get("version", 0)) != VERSION:
		push_error("Unsupported level format: %s v%s" % [d.get("format"), d.get("version")])
		return null
	var lv := CGLevel.new()
	lv.id = str(d.id)
	lv.size = int(d.size)
	lv.level_seed = int(d.get("seed", 0))
	lv.codes = str(d.tiles)
	lv.colors = PackedInt32Array(d.colors)
	lv.start = PackedInt32Array(d.start)
	lv.solution = PackedInt32Array(d.solution)
	lv.locked = PackedInt32Array(d.get("locked", []))
	lv.min_moves = int(d.get("min_moves", 0))
	lv.par = int(d.get("par", 0))
	lv.difficulty = d.get("difficulty", {})
	var n := lv.size * lv.size
	if lv.codes.length() != n or lv.colors.size() != n or lv.start.size() != n or lv.solution.size() != n:
		push_error("Level %s has inconsistent array sizes" % lv.id)
		return null
	return lv


static func load_pack(path: String) -> Array[CGLevel]:
	var out: Array[CGLevel] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open level pack %s" % path)
		return out
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Level pack %s is not a JSON object" % path)
		return out
	for d in data.get("levels", []):
		var lv := from_dict(d)
		if lv:
			out.append(lv)
	return out
