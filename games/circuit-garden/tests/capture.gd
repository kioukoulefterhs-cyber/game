extends SceneTree
## Scripted tour that saves screenshots of every screen. Needs a display (e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://tests/capture.gd -- <out_dir>
## Uses the real Game autoload, so it resets local progress first and again at the end.

var _out := "user://shots"
var _main: Node
var _steps: Array = []
var _wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var game = root.get_node("Game")
	game.configure()
	game.reset_progress()
	game.settings.set_value("analytics_consent", "unknown")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_steps = [
		[20, func(): _shot("01_consent")],
		[1, func():
			game.settings.set_value("analytics_consent", "denied")
			_main.get_child(_main.get_child_count() - 1).queue_free()
			_main.show_screen("menu")],
		[20, func(): _shot("02_menu")],
		[1, func(): _main.play_level(0)],
		[20, func(): _shot("03_tutorial")],
		[1, func():
			var v := _board()
			var target := v.session.level.solution_masks()
			for i in target.size():
				var g := 0
				while v.session.board.is_rotatable(i) and v.session.board.mask(i) != target[i] and g < 4:
					v.session.tap(i)
					g += 1],
		[25, func(): _shot("04_solved")],
		[90, func(): _shot("05_win_panel")],
		[1, func():
			game.add_seeds(200)
			for id in ["daisy", "tulip", "sunflower", "orchid", "fern", "lantern", "stones"]:
				game.buy_garden_item(id)
			_main.show_screen("garden")],
		[30, func(): _shot("06_garden")],
		[1, func(): _main.show_screen("levels")],
		[20, func(): _shot("07_levels")],
		[1, func(): _main.play_level(20)],
		[30, func(): _shot("08_level21")],
		[1, func(): _main.play_level(95)],
		[30, func(): _shot("09_level96")],
		[1, func():
			# Half-solved Expert board: the energy reaching in from the sources.
			var v := _board()
			var target := v.session.level.solution_masks()
			for i in range(0, target.size() / 2):
				var g := 0
				while v.session.board.is_rotatable(i) and v.session.board.mask(i) != target[i] and g < 4:
					v.session.tap(i)
					g += 1],
		[30, func(): _shot("09b_level96_half")],
		[1, func(): _main.show_screen("store")],
		[20, func(): _shot("10_store")],
		[1, func(): _main.show_screen("daily")],
		[20, func(): _shot("11_daily")],
		[1, func(): _main.show_screen("settings")],
		[20, func(): _shot("12_settings")],
		[1, func(): game.reset_progress()],
	]


func _process(_delta: float) -> bool:
	if _steps.is_empty():
		return true
	_wait += 1
	if _wait >= _steps[0][0]:
		_wait = 0
		var step: Array = _steps.pop_front()
		step[1].call()
	return false


func _board() -> CGBoardView:
	return _find(_main)


func _find(n: Node) -> CGBoardView:
	if n is CGBoardView:
		return n
	for c in n.get_children():
		var f := _find(c)
		if f:
			return f
	return null


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("saved ", name)
