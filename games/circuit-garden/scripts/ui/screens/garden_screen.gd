extends "res://scripts/ui/screens/screen_base.gd"
## Garden: spend seeds on cosmetic plants and decorations, pick an unlocked theme.

var _view: CGGardenView
var _seeds: Label
var _shop: VBoxContainer


func _ready() -> void:
	build("Garden")
	_seeds = StudioUI.label("", 30, Color("f0e442"))
	body.add_child(_seeds)
	_view = CGGardenView.new()
	_view.custom_minimum_size = Vector2(0, 520)
	_view.reduce_motion = Game.settings.get_value("reduce_motion")
	body.add_child(_view)
	_shop = scroll_area()
	_refresh()


func _refresh() -> void:
	var g := Game.garden()
	_seeds.text = "%d seeds" % Game.seeds()
	var owned: Array = g.owned.map(func(id): return CGGarden.find(CGGarden.all_plants(), id)).filter(func(d): return not d.is_empty())
	_view.set_garden(CGGarden.find(CGGarden.THEMES, g.theme), owned, g.decor)
	for c in _shop.get_children():
		c.queue_free()
	_shop.add_child(StudioUI.label("Themes", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	var unlocked := CGGarden.themes_unlocked(Game.completed_count())
	for t in CGGarden.THEMES:
		var label: String = t.name
		if not t.id in unlocked:
			label += "  (complete %d levels)" % t.levels
		elif t.id == g.theme:
			label += "  ✓"
		var b := StudioUI.button(label, func():
			if Game.set_theme(t.id):
				_refresh())
		b.disabled = not t.id in unlocked
		_shop.add_child(b)
	_shop.add_child(StudioUI.label("Plants", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	for p in CGGarden.PLANTS:
		_shop.add_child(_item_button(p))
	_shop.add_child(StudioUI.label("Decorations", 30, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	for d in CGGarden.DECOR:
		_shop.add_child(_item_button(d))


func _item_button(item: Dictionary) -> Button:
	var owned := Game.owns_item(item.id)
	var text: String = item.name + ("  ✓" if owned else "  ·  %d seeds" % item.cost)
	var b := StudioUI.button(text, func():
		var err := Game.buy_garden_item(item.id)
		if err == "":
			Game.audio.play("unlock")
			_view.celebrate(item.id)
			host.toast("%s planted!" % item.name)
			_refresh()
		else:
			host.toast(err.capitalize() + "."))
	b.disabled = owned
	return b
