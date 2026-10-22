extends SceneTree
## Builds the campaign level pack from tools/level-generator/curriculum.json.
##   godot --headless --path games/circuit-garden -s res://tools/generate_levels.gd -- <curriculum.json> <out.json>
## Deterministic: the same curriculum always produces byte-identical output.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <curriculum.json> <out.json>")
		quit(2)
		return
	var cur = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if typeof(cur) != TYPE_DICTIONARY:
		printerr("cannot read curriculum ", args[0])
		quit(2)
		return
	var levels: Array = []
	var seed_cursor: int = int(cur.base_seed)
	var seen := {}
	var started := Time.get_ticks_msec()
	for band in cur.bands:
		var count: int = int(band.count)
		var want: int = count * int(cur.get("candidates", 3))
		var pool: Array[CGLevel] = []
		var gen := CGGenerator.new()
		var tries := 0
		while pool.size() < want and tries < want * 20:
			tries += 1
			seed_cursor += 1
			var lv := gen.generate(band.params, seed_cursor)
			if lv == null:
				continue
			var key := lv.codes + str(lv.colors)
			if seen.has(key):
				continue
			seen[key] = true
			pool.append(lv)
		if pool.size() < count:
			printerr("band %s: only %d candidates" % [band.name, pool.size()])
			quit(1)
			return
		pool.sort_custom(func(a, b): return a.difficulty.score < b.difficulty.score)
		for k in count:
			# Evenly spaced picks across the sorted pool, so difficulty climbs inside the band.
			var idx := roundi(float(k) * (pool.size() - 1) / maxf(1.0, count - 1))
			var lv: CGLevel = pool[idx]
			lv.id = "cg-%03d" % (levels.size() + 1)
			lv.difficulty["band"] = band.name
			levels.append(lv.to_dict())
		print("band %-10s %2d levels from %d candidates" % [band.name, count, pool.size()])
	var pack := {
		"format": "circuit-garden-pack", "version": 1, "generator": "forest-v1",
		"curriculum_version": int(cur.version), "base_seed": int(cur.base_seed),
		"levels": levels,
	}
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(pack, "\t", false) + "\n")
	f.close()
	print("wrote %d levels to %s in %d ms" % [levels.size(), args[1], Time.get_ticks_msec() - started])
	quit(0)
