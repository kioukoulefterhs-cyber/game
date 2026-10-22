extends SceneTree
## Dumps raw generator candidates for difficulty analysis and curve selection.
##   godot --headless --path games/circuit-garden -s res://tools/dump_candidates.gd -- <params.json> <first_seed> <count> <out.json>
## params.json is one band's "params" object. Deterministic for the same arguments.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("usage: -- <params.json> <first_seed> <count> <out.json>")
		quit(2)
		return
	var params = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var first := int(args[1])
	var count := int(args[2])
	var gen := CGGenerator.new()
	var out: Array = []
	for k in count:
		var lv := gen.generate(params, first + k)
		if lv != null:
			out.append(lv.to_dict())
	var f := FileAccess.open(args[3], FileAccess.WRITE)
	f.store_string(JSON.stringify({"params": params, "levels": out}))
	f.close()
	print("%d candidates from %d seeds" % [out.size(), count])
	quit(0)
