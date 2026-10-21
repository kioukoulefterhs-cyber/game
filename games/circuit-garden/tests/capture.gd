extends SceneTree
## Renders the main scene and saves screenshots. Needs a display (e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 -s res://tests/capture.gd -- <out_dir>

var _out := "user://shots"
var _frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	root.add_child(load("res://scenes/main.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 30:
		_shot("01_start")
	if _frame == 31:
		var view: CGBoardView = _find_board(root)
		if view:
			for i in 5:
				view.session.tap(i * 3 % view.session.board.cell_count())
	if _frame == 60:
		_shot("02_after_taps")
	if _frame == 61:
		var view: CGBoardView = _find_board(root)
		if view:
			var lv := view.session.level
			for i in lv.size * lv.size:
				while view.session.board.is_rotatable(i) and view.session.board.rot[i] != lv.solution[i]:
					view.session.tap(i)
	if _frame == 75:
		_shot("03_solving")
	if _frame == 160:
		_shot("04_win")
		return true
	return false


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", _out.path_join(name + ".png"))


func _find_board(n: Node) -> CGBoardView:
	if n is CGBoardView:
		return n
	for c in n.get_children():
		var f := _find_board(c)
		if f:
			return f
	return null
