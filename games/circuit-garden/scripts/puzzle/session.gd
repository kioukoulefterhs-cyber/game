class_name CGSession
extends RefCounted
## One play-through of a level: taps, undo, restart, hints, moves, timer and stars.
## Pure logic so it can be tested headless.

signal changed
signal solved

var level: CGLevel
var board: CGBoard
var moves: int = 0
var hints_used: int = 0
var elapsed: float = 0.0
var time_limit: float = 0.0 ## 0 = untimed. Challenge modes set a limit in seconds.
var is_solved: bool = false
var analysis: Dictionary = {}

var _history: Array[int] = []
var _target := PackedInt32Array()


func _init(lv: CGLevel) -> void:
	level = lv
	_target = lv.solution_masks()
	restart()


func restart() -> void:
	board = level.make_board()
	moves = 0
	hints_used = 0
	elapsed = 0.0
	is_solved = false
	_history.clear()
	_refresh()


func tap(i: int) -> bool:
	if is_solved or is_time_up():
		return false
	if not board.tap(i):
		return false
	moves += 1
	_history.append(i)
	_refresh()
	return true


func can_undo() -> bool:
	return not _history.is_empty() and not is_solved


func undo() -> bool:
	if not can_undo():
		return false
	var i: int = _history.pop_back()
	board.untap(i)
	moves -= 1
	_refresh()
	return true


## Turns one wrong tile to its solution orientation and pins it.
## Returns the cell index, or -1 when every free tile is already correct.
func hint() -> int:
	if is_solved:
		return -1
	var best := -1
	for i in board.cell_count():
		if board.is_rotatable(i) and board.mask(i) != _target[i]:
			best = i
			break
	if best < 0:
		return -1
	board.rot[best] = level.solution[best]
	board.locked[best] = 1
	hints_used += 1
	# Taps on a pinned tile can no longer be undone tap by tap.
	_history = _history.filter(func(c): return c != best)
	_refresh()
	return best


func tick(delta: float) -> void:
	if not is_solved:
		elapsed += delta


func is_time_up() -> bool:
	return time_limit > 0.0 and elapsed >= time_limit


func stars() -> int:
	if not is_solved:
		return 0
	if hints_used == 0 and moves <= level.par:
		return 3
	if hints_used <= 1 and moves <= 2 * level.par:
		return 2
	return 1


func _refresh() -> void:
	analysis = board.analyze()
	var was := is_solved
	is_solved = analysis.solved
	changed.emit()
	if is_solved and not was:
		solved.emit()
