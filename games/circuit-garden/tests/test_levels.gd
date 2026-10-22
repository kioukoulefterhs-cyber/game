extends RefCounted
## The shipped campaign pack: loads, every level unique and solvable, curve is sane.

const PACK := "res://puzzles/levels_v1.json"
var t


func test_pack_has_100_valid_unique_levels() -> void:
	var levels := CGLevel.load_pack(PACK)
	t.eq(levels.size(), 100)
	var solver := CGSolver.new()
	var ids := {}
	for lv in levels:
		ids[lv.id] = true
		t.check(lv.make_solved_board().is_solved(), lv.id + " solution solves")
		t.check(not lv.make_board().is_solved(), lv.id + " start not solved")
		t.eq(solver.count_solutions(lv.make_board(), 2), 1, lv.id + " unique")
		t.eq(lv.make_board().taps_to(lv.solution_masks()), lv.min_moves, lv.id + " min_moves")
	t.eq(ids.size(), 100, "ids unique")


func test_campaign_covers_all_sizes_in_order() -> void:
	var levels := CGLevel.load_pack(PACK)
	var prev := 0
	var sizes := {}
	for lv in levels:
		t.check(lv.size >= prev, "%s size does not shrink" % lv.id)
		prev = lv.size
		sizes[lv.size] = true
	t.eq(sizes.keys().size(), 4)
	t.eq(levels[0].size, 4)
	t.eq(levels[99].size, 7)


func test_every_level_reproduces_from_its_seed() -> void:
	var levels := CGLevel.load_pack(PACK)
	for lv in levels:
		var params: Dictionary = lv.difficulty.get("params", {})
		t.check(not params.is_empty(), lv.id + " records its generator params")
		var again := CGGenerator.new().generate(params, lv.level_seed)
		t.check(again != null, lv.id)
		if again:
			t.eq(again.codes, lv.codes, lv.id + " tiles reproduce from seed")
			t.eq(again.start, lv.start, lv.id + " scramble reproduces from seed")


func test_measured_difficulty_never_drops_and_is_labelled() -> void:
	var levels := CGLevel.load_pack(PACK)
	var prev := 0.0
	var labels := {}
	for lv in levels:
		var effort := float(lv.difficulty.get("effort", -1.0))
		t.check(effort >= prev, "%s effort %.0f >= previous %.0f" % [lv.id, effort, prev])
		prev = effort
		var label: String = lv.difficulty.get("label", "")
		t.check(label in ["Easy", "Medium", "Hard", "Expert"], lv.id + " has a difficulty label")
		labels[label] = true
	t.eq(labels.size(), 4, "all four labels used")
	t.eq(levels[0].difficulty.label, "Easy")
	t.eq(levels[99].difficulty.label, "Expert")
