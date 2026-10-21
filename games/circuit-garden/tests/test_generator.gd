extends RefCounted
## Seeded generation, determinism, solvability and the uniqueness criterion.

var t


func test_same_seed_same_level() -> void:
	for size in [4, 5, 6, 7]:
		var p := {"size": size, "colors": 2, "crosses": 1}
		var a := CGGenerator.new().generate(p, 1234)
		var b := CGGenerator.new().generate(p, 1234)
		t.check(a != null and b != null, "generated %d" % size)
		t.eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()), "size %d deterministic" % size)


func test_different_seeds_differ() -> void:
	var p := {"size": 5, "colors": 1}
	var a := CGGenerator.new().generate(p, 1)
	var b := CGGenerator.new().generate(p, 2)
	t.check(a.codes != b.codes or a.start != b.start)


func test_generated_levels_are_valid_and_unique() -> void:
	var cases := [
		{"size": 4, "colors": 1}, {"size": 5, "colors": 2, "crosses": 1},
		{"size": 6, "colors": 2, "crosses": 1, "blocked": 1},
		{"size": 7, "colors": 3, "crosses": 2, "blocked": 2, "receiver_ratio": 0.4},
	]
	for p in cases:
		for s in [3, 17, 99]:
			var lv := CGGenerator.new().generate(p, s)
			t.check(lv != null, "generate %s seed %d" % [p, s])
			if lv == null:
				continue
			t.check(lv.make_solved_board().is_solved(), "stored solution solves")
			t.check(not lv.make_board().is_solved(), "start is scrambled")
			var solver := CGSolver.new()
			t.eq(solver.count_solutions(lv.make_board(), 2), 1, "unique %s seed %d" % [p, s])
			t.check(not solver.aborted)
			t.eq(lv.make_board().taps_to(lv.solution_masks()), lv.min_moves)
			t.eq(lv.color_count(), int(p.colors))
			t.eq(lv.codes.count("+"), int(p.get("crosses", 0)))
			t.eq(lv.codes.count("#"), int(p.get("blocked", 0)))


## Cross-checks the solver against brute-force enumeration on small boards.
func test_solver_matches_brute_force() -> void:
	for s in range(1, 9):
		var lv := CGGenerator.new().generate({"size": 3, "colors": 1, "min_scramble": 0.2}, s)
		if lv == null:
			continue
		var board := lv.make_board()
		var free: Array[int] = []
		for i in board.cell_count():
			if board.is_rotatable(i):
				free.append(i)
		var seen := {}
		var combos := 1 << (2 * free.size())
		for code in combos:
			for k in free.size():
				board.rot[free[k]] = (code >> (2 * k)) & 3
			if board.is_solved():
				seen[str(board.masks())] = true
		var solver := CGSolver.new()
		t.eq(solver.count_solutions(lv.make_board(), 100), seen.size(), "seed %d" % s)


func test_level_json_round_trip() -> void:
	var lv := CGGenerator.new().generate({"size": 6, "colors": 2, "crosses": 1}, 5)
	lv.id = "rt"
	var text := JSON.stringify(lv.to_dict())
	var back := CGLevel.from_dict(JSON.parse_string(text))
	t.check(back != null)
	var a := lv.to_dict()
	var b := back.to_dict()
	for k in a:
		if k != "difficulty":
			t.eq(JSON.stringify(b[k]), JSON.stringify(a[k]), k)
	t.eq(float(b.difficulty.score), float(a.difficulty.score))
