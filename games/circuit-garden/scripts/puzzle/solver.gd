class_name CGSolver
extends RefCounted
## Exhaustive backtracking solver. Counts solutions up to a limit, where two
## solutions are equal when every cell has the same mask (docs/puzzle-rules.md).

const NODE_LIMIT := 2_000_000

var nodes_visited: int = 0
var aborted: bool = false
var solutions: Array[PackedInt32Array] = []

var _b: CGBoard
var _cand: Array = []
var _assign := PackedInt32Array()
var _limit: int = 2


## Returns the number of solutions found, capped at `limit`. Check `aborted`
## when the node limit was hit; the count is then a lower bound.
func count_solutions(board: CGBoard, limit: int = 2) -> int:
	_b = board
	_limit = limit
	nodes_visited = 0
	aborted = false
	solutions.clear()
	var n := board.cell_count()
	_assign.resize(n)
	_assign.fill(0)
	_build_candidates()
	for c in _cand:
		if c.is_empty():
			return 0
	_search(0)
	return solutions.size()


func _build_candidates() -> void:
	_cand.clear()
	var n := _b.cell_count()
	for i in n:
		var opts: Array[int] = []
		if _b.is_rotatable(i):
			var base: int = CGBoard.BASE_MASK[_b.types[i]]
			for k in 4:
				var m := CGBoard.rotate_mask(base, k)
				if not opts.has(m):
					opts.append(m)
		else:
			opts.append(_b.mask(i))
		_cand.append(opts)
	# Static pruning against the border and fixed neighbours.
	for i in n:
		var keep: Array[int] = []
		for m in _cand[i]:
			if _static_ok(i, m):
				keep.append(m)
		_cand[i] = keep


func _static_ok(i: int, m: int) -> bool:
	for d in CGBoard.DIRS:
		var j := _b.neighbor(i, d)
		var open: bool = m & d != 0
		if j < 0:
			if open:
				return false
			continue
		if _cand[j].size() == 1 and j != i:
			var back: bool = _cand[j][0] & CGBoard.OPPOSITE[d] != 0
			if back != open:
				return false
	return true


func _search(i: int) -> void:
	if solutions.size() >= _limit or aborted:
		return
	nodes_visited += 1
	if nodes_visited > NODE_LIMIT:
		aborted = true
		return
	var n := _b.cell_count()
	if i == n:
		if _check_full():
			solutions.append(_assign.duplicate())
		return
	var size := _b.size
	var r := i / size
	var c := i % size
	for m in _cand[i]:
		if r > 0:
			var up := _assign[i - size]
			if (up & CGBoard.S != 0) != (m & CGBoard.N != 0):
				continue
		if c > 0:
			var left := _assign[i - 1]
			if (left & CGBoard.E != 0) != (m & CGBoard.W != 0):
				continue
		_assign[i] = m
		_search(i + 1)
		if solutions.size() >= _limit or aborted:
			return


func _check_full() -> bool:
	var tmp := _b.duplicate_board()
	for i in tmp.cell_count():
		var base: int = CGBoard.BASE_MASK[tmp.types[i]]
		for k in 4:
			if CGBoard.rotate_mask(base, k) == _assign[i]:
				tmp.rot[i] = k
				break
	return tmp.is_solved()
