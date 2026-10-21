extends SceneTree
## Rasterizes the SVG art into the PNG sizes Android needs (launcher, adaptive layers, splash).
##   godot --headless --path games/circuit-garden -s res://tools/make_icons.gd


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/icon.svg")
	_save(svg, 192, "res://assets/icons/icon_192.png")
	_save(svg, 512, "res://assets/icons/icon_512.png")
	# Adaptive icon: foreground art inside the 66% safe zone on a transparent 432px canvas.
	var fg_svg := svg.replace('<rect width="512" height="512" rx="112" fill="#12201b"/>', "") \
		.replace('<rect x="56" y="56" width="400" height="400" rx="72" fill="#1a2c25"/>', "")
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	var art := Image.new()
	art.load_svg_from_string(fg_svg, 300.0 / 512.0)
	fg.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(66, 66))
	fg.save_png(ProjectSettings.globalize_path("res://assets/icons/adaptive_fg_432.png"))
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color("1a2c25"))
	bg.save_png(ProjectSettings.globalize_path("res://assets/icons/adaptive_bg_432.png"))
	# Splash: icon centred on the background colour.
	var splash := Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
	splash.fill(Color("12201b"))
	var big := Image.new()
	big.load_svg_from_string(svg, 384.0 / 512.0)
	splash.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(348, 768))
	splash.save_png(ProjectSettings.globalize_path("res://assets/icons/splash.png"))
	print("icons written")
	quit()


func _save(svg: String, px: int, path: String) -> void:
	var img := Image.new()
	img.load_svg_from_string(svg, px / 512.0)
	img.save_png(ProjectSettings.globalize_path(path))
