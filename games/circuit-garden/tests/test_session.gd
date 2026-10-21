extends RefCounted
## Undo, restart, hints, moves, timer and stars on a generated level.

var t


func _level(s: int = 7) -> CGLevel:
	var lv := CGGenerator.new().generate({"size": 4, "colors": 1}, s)
	lv.id = "test"
	return lv


func _first_free(sess: CGSession) -> int:
	for i in sess.board.cell_count():
		if sess.board.is_rotatable(i):
			return i
	return -1


func test_tap_counts_moves_and_undo_restores() -> void:
	var s := CGSession.new(_level())
	var i := _first_free(s)
	var before := s.board.rot[i]
	t.check(s.tap(i))
	t.eq(s.moves, 1)
	t.eq(s.board.rot[i], (before + 1) % 4)
	t.check(s.undo())
	t.eq(s.moves, 0)
	t.eq(s.board.rot[i], before)
	t.check(not s.undo(), "nothing left to undo")


func test_tap_on_fixed_tile_is_not_a_move() -> void:
	var s := CGSession.new(_level())
	for i in s.board.cell_count():
		if s.board.types[i] == CGBoard.Tile.SOURCE:
			t.check(not s.tap(i))
	t.eq(s.moves, 0)


func test_restart_returns_to_scramble() -> void:
	var lv := _level()
	var s := CGSession.new(lv)
	for k in 6:
		s.tap(_first_free(s))
	s.hint()
	s.restart()
	t.eq(s.moves, 0)
	t.eq(s.hints_used, 0)
	t.eq(s.board.rot, lv.make_board().rot)
	t.check(not s.can_undo())


func _solve(s: CGSession) -> void:
	var lv := s.level
	var target := lv.solution_masks()
	for i in s.board.cell_count():
		var guard := 0
		while s.board.is_rotatable(i) and s.board.mask(i) != target[i] and guard < 4:
			s.tap(i)
			guard += 1


func test_solving_emits_once_and_freezes() -> void:
	var s := CGSession.new(_level())
	var hits := [0]
	s.solved.connect(func(): hits[0] += 1)
	_solve(s)
	t.check(s.is_solved)
	t.eq(hits[0], 1)
	t.eq(s.moves, s.level.min_moves, "solving by the shortest taps uses exactly min_moves")
	t.eq(s.stars(), 3)
	t.check(not s.tap(_first_free(s)), "no taps after solving")
	t.check(not s.undo(), "no undo after solving")


func test_hint_fixes_and_pins_a_tile() -> void:
	var s := CGSession.new(_level())
	var target := s.level.solution_masks()
	var i := s.hint()
	t.check(i >= 0)
	t.eq(s.board.mask(i), target[i])
	t.eq(s.board.locked[i], 1)
	t.eq(s.hints_used, 1)
	t.check(not s.tap(i), "hinted tile is pinned")


func test_hints_alone_can_finish_a_level() -> void:
	var s := CGSession.new(_level(11))
	var guard := 0
	while not s.is_solved and guard < 100:
		t.check(s.hint() >= 0, "hint available while unsolved")
		guard += 1
	t.check(s.is_solved)
	t.eq(s.stars(), 1)


func test_stars_thresholds() -> void:
	var s := CGSession.new(_level())
	_solve(s)
	s.moves = s.level.par + 1
	t.eq(s.stars(), 2)
	s.moves = s.level.par * 2 + 1
	t.eq(s.stars(), 1)
	s.moves = s.level.par
	s.hints_used = 1
	t.eq(s.stars(), 2)


func test_timer_and_time_limit() -> void:
	var s := CGSession.new(_level())
	s.time_limit = 10.0
	s.tick(4.0)
	t.check(not s.is_time_up())
	s.tick(6.5)
	t.check(s.is_time_up())
	t.check(not s.tap(_first_free(s)), "no taps after time is up")
