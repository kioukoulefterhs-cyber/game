extends RefCounted
## Tile rotation, connection logic, energy propagation and win conditions.

const H := preload("res://tests/helpers.gd")
var t


func test_rotate_mask_clockwise() -> void:
	t.eq(CGBoard.rotate_mask(CGBoard.N | CGBoard.E, 1), CGBoard.E | CGBoard.S)
	t.eq(CGBoard.rotate_mask(CGBoard.N, 3), CGBoard.W)
	t.eq(CGBoard.rotate_mask(CGBoard.N | CGBoard.S, 2), CGBoard.N | CGBoard.S, "straight is 180-degree symmetric")
	for m in 16:
		t.eq(CGBoard.rotate_mask(m, 4), m, "four turns are identity")


func test_tap_rotates_only_free_tiles() -> void:
	var b := H.board(["SR", "LI"], ["13", "00"], {0: 0, 1: 0})
	t.check(not b.tap(0), "source is fixed")
	t.check(not b.tap(1), "receiver is fixed")
	t.check(b.tap(2), "elbow rotates")
	t.eq(b.rot[2], 1)
	t.eq(b.mask(2), CGBoard.E | CGBoard.S)
	b.locked[3] = 1
	t.check(not b.tap(3), "locked tile is fixed")
	t.check(not b.tap(-1) and not b.tap(99), "out of range")


func test_simple_connection_solves() -> void:
	var b := H.board(["SR", "##"], ["13", "00"], {0: 0, 1: 0})
	var a := b.analyze()
	t.check(a.leaks.is_empty(), "no leaks")
	t.eq(a.networks.size(), 1)
	t.eq(a.networks[0].color, 0)
	t.check(a.solved, "source to matching receiver is solved")


func test_wrong_color_receiver_is_not_solved() -> void:
	var b := H.board(["SR", "##"], ["13", "00"], {0: 0, 1: 1})
	var a := b.analyze()
	t.eq(a.receivers_ok, 0)
	t.check(not a.solved)


func test_leak_blocks_win() -> void:
	var b := H.board(["SR", "##"], ["10", "00"], {0: 0, 1: 0})
	var a := b.analyze()
	t.eq(a.leaks.size(), 2, "source faces an empty edge, receiver faces the border")
	t.check(not a.solved)


func test_cross_keeps_channels_independent() -> void:
	var b := H.board(["#S#", "S+R", "#R#"], ["020", "103", "000"],
		{1: 0, 3: 1, 5: 1, 7: 0})
	var a := b.analyze()
	t.check(a.leaks.is_empty())
	t.eq(a.networks.size(), 2, "vertical and horizontal channels are separate networks")
	t.check(a.solved, "each color reaches its own receiver through the cross")
	t.check(a.node_net[4 * 2 + 0] != a.node_net[4 * 2 + 1], "cross channels differ")


func test_tee_joining_two_sources_shorts() -> void:
	var b := H.board(["#S#", "STR", "###"], ["020", "133", "000"],
		{1: 0, 3: 1, 5: 1})
	var a := b.analyze()
	t.check(a.leaks.is_empty())
	t.eq(a.networks.size(), 1)
	t.check(a.networks[0].shorted, "two colors in one network short")
	t.check(not a.solved)


func test_unpowered_loop_is_not_solved() -> void:
	var b := H.board(["LL", "LL"], ["12", "03"])
	var a := b.analyze()
	t.check(a.leaks.is_empty(), "closed loop has no leaks")
	t.check(not a.solved, "a network without a source never solves")


func test_energy_propagation_distances() -> void:
	var b := H.board(["SIR", "###", "###"], ["111", "000", "000"], {0: 2, 2: 2})
	b.rot[2] = 3
	var a := b.analyze()
	t.check(a.solved)
	var d := b.flow_distances(a)
	t.eq(d.get(0), 0)
	t.eq(d.get(2), 1)
	t.eq(d.get(4), 2)


func test_unpowered_tiles_have_no_flow() -> void:
	var b := H.board(["SIR", "###", "###"], ["101", "000", "000"], {0: 2, 2: 2})
	var a := b.analyze()
	var d := b.flow_distances(a)
	t.check(d.has(0), "source itself glows")
	t.check(not d.has(4) and not d.has(2), "disconnected tiles get no energy")
