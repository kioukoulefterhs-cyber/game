extends SceneTree
## Renders the Play Store feature graphic (1024x500) from real game drawing code.
## Needs a display (e.g. xvfb-run) and a renderer:
##   godot --path games/circuit-garden --rendering-driver opengl3 -s res://tools/make_store_art.gd -- <out.png>

const Palette := preload("res://scripts/ui/palette.gd")
const LEVEL_INDEX := 30 ## a 5x5 two-colour level with a bridge

var _out := "user://feature_graphic.png"
var _vp: SubViewport
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_vp = SubViewport.new()
	_vp.size = Vector2i(1024, 500)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.size = Vector2(1024, 500)
	_vp.add_child(bg)
	var levels := CGLevel.load_pack("res://puzzles/levels_v1.json")
	var lv: CGLevel = levels[LEVEL_INDEX]
	var session := CGSession.new(lv)
	var target := lv.solution_masks()
	for i in target.size():
		while session.board.is_rotatable(i) and session.board.mask(i) != target[i]:
			session.tap(i)
	var board := CGBoardView.new()
	board.position = Vector2(574, 30)
	board.size = Vector2(440, 440)
	_vp.add_child(board)
	board.bind(session)
	var title := Label.new()
	title.text = "Circuit Garden"
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Palette.TEXT)
	title.position = Vector2(48, 150)
	_vp.add_child(title)
	var tag := Label.new()
	tag.text = "Turn the vines. Light every flower."
	tag.add_theme_font_size_override("font_size", 32)
	tag.add_theme_color_override("font_color", Palette.ACCENT)
	tag.position = Vector2(52, 262)
	_vp.add_child(tag)
	var sub := Label.new()
	sub.text = "100 logic puzzles  ·  offline  ·  one solution each"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
	sub.position = Vector2(52, 316)
	_vp.add_child(sub)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40: # let the flow animation settle into a nice phase
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8) # Play wants no alpha in the feature graphic
		img.save_png(_out)
		print("wrote ", _out)
		return true
	return false
