class_name CGGenerator
extends RefCounted
## Deterministic, seeded level generator. Same (params, seed) gives the same level
## on every platform: only RandomNumberGenerator (PCG32) is used, never the global RNG.
##
## Pipeline: carve a solved board as a spanning forest (one tree per source color),
## scramble the rotatable tiles, then lock tiles until the exhaustive solver proves a
## unique solution. See docs/level-generation.md.

const MAX_ATTEMPTS := 200

var rng := RandomNumberGenerator.new()
var last_error: String = ""


## params: { size, colors, blocked, crosses, receiver_ratio, min_scramble }
func generate(params: Dictionary, level_seed: int) -> CGLevel:
	rng.seed = level_seed
	var size: int = params.get("size", 4)
	for attempt in MAX_ATTEMPTS:
		var solved := _carve(size, params)
		if solved == null:
			continue
		var lv := _finish(solved, params, level_seed)
		if lv != null:
			lv.difficulty["attempts"] = attempt + 1
			return lv
	last_error = "no valid level after %d attempts" % MAX_ATTEMPTS
	return null


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _carve(size: int, params: Dictionary) -> CGBoard:
	var n := size * size
	var b := CGBoard.create(size)
	var colors: int = params.get("colors", 1)
	var blocked_count: int = params.get("blocked", 0)
	var cross_count: int = params.get("crosses", 0)
	for i in n:
		b.types[i] = CGBoard.Tile.STRAIGHT # placeholder, replaced below
	var cells: Array = range(n)
	_shuffle(cells)
	var blocked := {}
	for i in cells:
		if blocked.size() >= blocked_count:
			break
		blocked[i] = true
		if not _open_cells_connected(b, blocked):
			blocked.erase(i)
	var crosses := {}
	_shuffle(cells)
	for i in cells:
		if crosses.size() >= cross_count:
			break
		var r: int = i / size
		var c: int = i % size
		if r == 0 or c == 0 or r == size - 1 or c == size - 1 or blocked.has(i):
			continue
		var ok := true
		for d in CGBoard.DIRS:
			var j := b.neighbor(i, d)
			if blocked.has(j) or crosses.has(j):
				ok = false
		if ok:
			crosses[i] = true
	var sources := {}
	_shuffle(cells)
	for i in cells:
		if sources.size() >= colors:
			break
		if blocked.has(i) or crosses.has(i) or _near(b, i, crosses) or _near(b, i, sources):
			continue
		sources[i] = sources.size()
	if sources.size() < colors:
		return null
	# Union-find over (cell, channel) nodes.
	var parent := {}
	var has_source := {}
	var deg := {}
	for i in n:
		if blocked.has(i):
			continue
		var chans := 2 if crosses.has(i) else 1
		for ch in chans:
			var k := i * 2 + ch
			parent[k] = k
			deg[k] = 0
			has_source[k] = sources.has(i)
	var edges_mask := PackedInt32Array()
	edges_mask.resize(n)
	var cross_t := CGBoard.Tile.CROSS
	var forced: Array = []
	var edges: Array = []
	for i in n:
		if blocked.has(i):
			continue
		for d in [CGBoard.E, CGBoard.S]:
			var j := b.neighbor(i, d)
			if j < 0 or blocked.has(j):
				continue
			var e := [i, d, j]
			if crosses.has(i) or crosses.has(j):
				forced.append(e)
			else:
				edges.append(e)
	_shuffle(edges)
	for e in forced + edges:
		var i: int = e[0]
		var d: int = e[1]
		var j: int = e[2]
		var ka := i * 2 + (CGBoard.channel_of(cross_t, d) if crosses.has(i) else 0)
		var kb := j * 2 + (CGBoard.channel_of(cross_t, CGBoard.OPPOSITE[d]) if crosses.has(j) else 0)
		var ra := _find(parent, ka)
		var rb := _find(parent, kb)
		var is_forced := crosses.has(i) or crosses.has(j)
		if ra == rb:
			if is_forced:
				return null
			continue
		if has_source[ra] and has_source[rb]:
			if is_forced:
				return null
			continue
		if not is_forced:
			if (sources.has(i) and deg[ka] >= 1) or (sources.has(j) and deg[kb] >= 1):
				continue
			if deg[ka] >= 3 or deg[kb] >= 3:
				continue
		parent[ra] = rb
		has_source[rb] = has_source[ra] or has_source[rb]
		deg[ka] += 1
		deg[kb] += 1
		edges_mask[i] |= d
		edges_mask[j] |= CGBoard.OPPOSITE[d]
	for k in parent:
		if deg[k] == 0 or not has_source[_find(parent, k)]:
			return null
	# Component colors, keyed by root.
	var root_color := {}
	for i in sources:
		root_color[_find(parent, i * 2)] = sources[i]
	var ratio: float = params.get("receiver_ratio", 0.6)
	var leaves_by_root := {}
	for i in n:
		if blocked.has(i):
			b.types[i] = CGBoard.Tile.BLOCKED
			b.rot[i] = 0
			continue
		if crosses.has(i):
			b.types[i] = CGBoard.Tile.CROSS
			b.rot[i] = 0
			continue
		var m := edges_mask[i]
		var t := _type_for_mask(m)
		if sources.has(i):
			t = CGBoard.Tile.SOURCE
			b.colors[i] = sources[i]
		b.types[i] = t
		b.rot[i] = _rot_for(t, m)
		if t == CGBoard.Tile.CAP:
			var root := _find(parent, i * 2)
			if not leaves_by_root.has(root):
				leaves_by_root[root] = []
			leaves_by_root[root].append(i)
	for root in root_color:
		var leaves: Array = leaves_by_root.get(root, [])
		if leaves.is_empty():
			return null
		_shuffle(leaves)
		var want := maxi(1, roundi(leaves.size() * ratio))
		for idx in want:
			var li: int = leaves[idx]
			b.types[li] = CGBoard.Tile.RECEIVER
			b.colors[li] = root_color[root]
	if not b.is_solved():
		push_error("generator produced an unsolved carve")
		return null
	return b


func _near(b: CGBoard, i: int, cells: Dictionary) -> bool:
	for d in CGBoard.DIRS:
		if cells.has(b.neighbor(i, d)):
			return true
	return false


func _find(parent: Dictionary, k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k


func _open_cells_connected(b: CGBoard, blocked: Dictionary) -> bool:
	var n := b.cell_count()
	var start := -1
	for i in n:
		if not blocked.has(i):
			start = i
			break
	if start < 0:
		return false
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for d in CGBoard.DIRS:
			var j := b.neighbor(i, d)
			if j >= 0 and not blocked.has(j) and not seen.has(j):
				seen[j] = true
				stack.append(j)
	return seen.size() == n - blocked.size()


static func _type_for_mask(m: int) -> int:
	var bits := 0
	for d in CGBoard.DIRS:
		if m & d:
			bits += 1
	match bits:
		1:
			return CGBoard.Tile.CAP
		2:
			return CGBoard.Tile.STRAIGHT if m == 5 or m == 10 else CGBoard.Tile.ELBOW
		3:
			return CGBoard.Tile.TEE
	return CGBoard.Tile.EMPTY


static func _rot_for(t: int, m: int) -> int:
	var base: int = CGBoard.BASE_MASK[t]
	for k in 4:
		if CGBoard.rotate_mask(base, k) == m:
			return k
	return 0


func _finish(solved: CGBoard, params: Dictionary, level_seed: int) -> CGLevel:
	var n := solved.cell_count()
	var solution := solved.rot.duplicate()
	var target := solved.masks()
	var board := solved.duplicate_board()
	var rotatable := 0
	for i in n:
		if board.is_rotatable(i):
			rotatable += 1
			board.rot[i] = rng.randi_range(0, 3)
	# Lock tiles until the solver proves the solution is unique.
	var solver := CGSolver.new()
	var locks: Array[int] = []
	var search_nodes := 0
	while true:
		var free := board.duplicate_board()
		var count := solver.count_solutions(free, 2)
		search_nodes += solver.nodes_visited
		if solver.aborted:
			return null
		if count == 0:
			push_error("solver found no solution for a carved board")
			return null
		if count == 1:
			break
		var a: PackedInt32Array = solver.solutions[0]
		var bb: PackedInt32Array = solver.solutions[1]
		var diff: Array[int] = []
		for i in n:
			if a[i] != bb[i] and board.is_rotatable(i):
				diff.append(i)
		if diff.is_empty():
			return null
		var pick: int = diff[rng.randi_range(0, diff.size() - 1)]
		board.locked[pick] = 1
		board.rot[pick] = solution[pick]
		locks.append(pick)
	var min_moves := board.taps_to(target)
	var free_tiles := rotatable - locks.size()
	var min_scramble: float = params.get("min_scramble", 0.5)
	if min_moves < maxi(3, ceili(free_tiles * min_scramble)) or board.is_solved():
		return null
	# Trivial-solution check: count tiles fixed by local constraints alone.
	var forced := 0
	var probe := CGSolver.new()
	probe.count_solutions(board.duplicate_board(), 1)
	for i in n:
		if board.is_rotatable(i) and probe._cand[i].size() == 1:
			forced += 1
	var forced_ratio := float(forced) / maxf(1.0, free_tiles)
	if forced_ratio >= params.get("max_forced_ratio", 0.85):
		return null
	var lv := CGLevel.new()
	lv.size = solved.size
	lv.level_seed = level_seed
	lv.codes = solved.to_codes()
	lv.colors = solved.colors.duplicate()
	lv.solution = solution
	lv.start = board.rot.duplicate()
	lv.locked = PackedInt32Array(locks)
	lv.min_moves = min_moves
	lv.par = min_moves + solved.size
	var colors := lv.color_count()
	var crosses := lv.codes.count("+")
	var score := free_tiles * 1.0 + min_moves * 0.5 + log(1.0 + search_nodes) * 2.0 \
		+ (colors - 1) * 4.0 + crosses * 3.0 - forced * 0.75
	lv.difficulty = {
		"score": snappedf(score, 0.1), "free_tiles": free_tiles, "locks": locks.size(),
		"forced_tiles": forced, "search_nodes": search_nodes, "colors": colors,
		"crosses": crosses, "generator": "forest-v1",
	}
	return lv
