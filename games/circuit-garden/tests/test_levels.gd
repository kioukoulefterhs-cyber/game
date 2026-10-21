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


func test_regeneration_is_reproducible() -> void:
	var levels := CGLevel.load_pack(PACK)
	for idx in [0, 37, 99]:
		var lv: CGLevel = levels[idx]
		var again := CGGenerator.new().generate(_params_for(lv), lv.level_seed)
		t.check(again != null, lv.id)
		if again:
			t.eq(again.codes, lv.codes, lv.id + " tiles reproduce from seed")
			t.eq(again.start, lv.start, lv.id + " scramble reproduces from seed")


func _params_for(lv: CGLevel) -> Dictionary:
	var cur = JSON.parse_string(FileAccess.get_file_as_string("res://puzzles/curriculum.json"))
	for band in cur.bands:
		if band.name == lv.difficulty.band:
			return band.params
	return {}
