class_name CGBoard
extends RefCounted
## Pure puzzle state and rules for Circuit Garden. No nodes, no rendering.
## The rules are specified in docs/puzzle-rules.md.

enum Tile { EMPTY, BLOCKED, STRAIGHT, ELBOW, TEE, CROSS, CAP, SOURCE, RECEIVER }

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [N, E, S, W]
const DR := {N: -1, E: 0, S: 1, W: 0}
const DC := {N: 0, E: 1, S: 0, W: -1}
const OPPOSITE := {N: S, E: W, S: N, W: E}

const BASE_MASK := {
	Tile.EMPTY: 0, Tile.BLOCKED: 0, Tile.STRAIGHT: N | S, Tile.ELBOW: N | E,
	Tile.TEE: N | E | S, Tile.CROSS: N | E | S | W, Tile.CAP: N,
	Tile.SOURCE: N, Tile.RECEIVER: N,
}
const CODES := {
	".": Tile.EMPTY, "#": Tile.BLOCKED, "I": Tile.STRAIGHT, "L": Tile.ELBOW,
	"T": Tile.TEE, "+": Tile.CROSS, "c": Tile.CAP, "S": Tile.SOURCE, "R": Tile.RECEIVER,
}

var size: int = 0
var types := PackedInt32Array()
var rot := PackedInt32Array()
var colors := PackedInt32Array()
var locked := PackedByteArray()


static func create(board_size: int) -> CGBoard:
	var b := CGBoard.new()
	b.size = board_size
	var n := board_size * board_size
	b.types.resize(n)
	b.rot.resize(n)
	b.colors.resize(n)
	b.locked.resize(n)
	b.colors.fill(-1)
	return b


func cell_count() -> int:
	return size * size


func duplicate_board() -> CGBoard:
	var b := CGBoard.new()
	b.size = size
	b.types = types.duplicate()
	b.rot = rot.duplicate()
	b.colors = colors.duplicate()
	b.locked = locked.duplicate()
	return b


static func rotate_mask(m: int, times: int) -> int:
	for i in posmod(times, 4):
		m = ((m << 1) | (m >> 3)) & 15
	return m


func mask(i: int) -> int:
	return rotate_mask(BASE_MASK[types[i]], rot[i])


func masks() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(cell_count())
	for i in cell_count():
		out[i] = mask(i)
	return out


## Rotatable by type. Cross is symmetric, endpoints with color are fixed anchors.
static func type_rotatable(t: int) -> bool:
	return t in [Tile.STRAIGHT, Tile.ELBOW, Tile.TEE, Tile.CAP]


func is_rotatable(i: int) -> bool:
	return type_rotatable(types[i]) and locked[i] == 0


## Rotates a tile 90 degrees clockwise. Returns false when the tile cannot rotate.
func tap(i: int) -> bool:
	if i < 0 or i >= cell_count() or not is_rotatable(i):
		return false
	rot[i] = (rot[i] + 1) % 4
	return true


func untap(i: int) -> void:
	rot[i] = (rot[i] + 3) % 4


func neighbor(i: int, d: int) -> int:
	var r: int = i / size + DR[d]
	var c: int = i % size + DC[d]
	if r < 0 or c < 0 or r >= size or c >= size:
		return -1
	return r * size + c


static func channel_of(t: int, d: int) -> int:
	if t == Tile.CROSS:
		return 0 if d == N or d == S else 1
	return 0


## Computes networks, leaks and the win state.
## Returns {
##   node_net: Dictionary (cell * 2 + channel) -> network id,
##   networks: Array of { nodes: Array[int], sources: Array[int], color: int, shorted: bool },
##   leaks: Array of [cell, dir],
##   receivers_ok: int, receivers_total: int, solved: bool }
func analyze() -> Dictionary:
	var m := masks()
	var node_net := {}
	var networks: Array = []
	var leaks: Array = []
	for i in cell_count():
		for d in DIRS:
			if m[i] & d == 0:
				continue
			var j := neighbor(i, d)
			if j < 0 or m[j] & OPPOSITE[d] == 0:
				leaks.append([i, d])
	for i in cell_count():
		for d in DIRS:
			if m[i] & d == 0:
				continue
			var key := i * 2 + channel_of(types[i], d)
			if node_net.has(key):
				continue
			var net_id := networks.size()
			var net := {"nodes": [], "sources": [], "color": -1, "shorted": false}
			networks.append(net)
			var stack: Array[int] = [key]
			node_net[key] = net_id
			while not stack.is_empty():
				var k: int = stack.pop_back()
				net.nodes.append(k)
				var ci := k / 2
				var ch := k % 2
				if types[ci] == Tile.SOURCE:
					net.sources.append(colors[ci])
				for dd in DIRS:
					if m[ci] & dd == 0 or channel_of(types[ci], dd) != ch:
						continue
					var nj := neighbor(ci, dd)
					if nj < 0 or m[nj] & OPPOSITE[dd] == 0:
						continue
					var nk := nj * 2 + channel_of(types[nj], OPPOSITE[dd])
					if not node_net.has(nk):
						node_net[nk] = net_id
						stack.append(nk)
	for net in networks:
		if net.sources.size() == 1:
			net.color = net.sources[0]
		elif net.sources.size() > 1:
			net.shorted = true
	var ok := 0
	var total := 0
	for i in cell_count():
		if types[i] != Tile.RECEIVER:
			continue
		total += 1
		var key := i * 2
		if node_net.has(key) and networks[node_net[key]].color == colors[i]:
			ok += 1
	var solved := leaks.is_empty() and ok == total
	if solved:
		for net in networks:
			if net.sources.size() != 1:
				solved = false
				break
	return {
		"node_net": node_net, "networks": networks, "leaks": leaks,
		"receivers_ok": ok, "receivers_total": total, "solved": solved,
	}


## Hop distance of every powered node from its network's source, for flow animation.
func flow_distances(analysis: Dictionary) -> Dictionary:
	var m := masks()
	var dist := {}
	var queue: Array[int] = []
	for i in cell_count():
		if types[i] == Tile.SOURCE:
			var net_id = analysis.node_net.get(i * 2, -1)
			if net_id >= 0 and analysis.networks[net_id].color >= 0:
				dist[i * 2] = 0
				queue.append(i * 2)
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		var ci := k / 2
		var ch := k % 2
		for d in DIRS:
			if m[ci] & d == 0 or channel_of(types[ci], d) != ch:
				continue
			var nj := neighbor(ci, d)
			if nj < 0 or m[nj] & OPPOSITE[d] == 0:
				continue
			var nk := nj * 2 + channel_of(types[nj], OPPOSITE[d])
			if not dist.has(nk):
				dist[nk] = dist[k] + 1
				queue.append(nk)
	return dist


func is_solved() -> bool:
	return analyze().solved


## Fewest clockwise taps from the current rotations to the target masks.
func taps_to(target_masks: PackedInt32Array) -> int:
	var total := 0
	for i in cell_count():
		if not type_rotatable(types[i]):
			continue
		total += taps_for_cell(i, target_masks[i])
	return total


func taps_for_cell(i: int, target_mask: int) -> int:
	var base: int = BASE_MASK[types[i]]
	for k in 4:
		if rotate_mask(base, rot[i] + k) == target_mask:
			return k
	return -1


func to_codes() -> String:
	var inv := {}
	for k in CODES:
		inv[CODES[k]] = k
	var s := ""
	for t in types:
		s += inv[t]
	return s
