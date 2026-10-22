extends SceneTree
## Minimal headless test runner (no third-party framework).
## Runs every test_*.gd in res://tests, calling each method named test_*.
##   godot --headless --path games/circuit-garden -s res://tests/run_tests.gd [-- filter]
## Exit code is the number of failed tests.

var failures: Array[String] = []
var _current := ""
var _current_failed := false


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var passed := 0
	var total := 0
	var started := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var suite = script.new()
		suite.set("t", self)
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (filter != "" and not (f + ":" + name).contains(filter)):
				continue
			total += 1
			_current = f.get_basename() + "." + name
			_current_failed = false
			var t0 := Time.get_ticks_msec()
			suite.call(name)
			var ms := Time.get_ticks_msec() - t0
			if _current_failed:
				print("FAIL  %s (%d ms)" % [_current, ms])
			else:
				passed += 1
				print("ok    %s (%d ms)" % [_current, ms])
		if suite is Node:
			suite.free()
	print("")
	print("%d/%d tests passed in %d ms" % [passed, total, Time.get_ticks_msec() - started])
	for f in failures:
		print("  ", f)
	quit(total - passed)


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		_current_failed = true
		failures.append("%s: %s" % [_current, msg if msg != "" else "check failed"])


func eq(a, b, msg: String = "") -> void:
	if typeof(a) != typeof(b) or a != b:
		_current_failed = true
		failures.append("%s: expected %s, got %s %s" % [_current, str(b), str(a), msg])
