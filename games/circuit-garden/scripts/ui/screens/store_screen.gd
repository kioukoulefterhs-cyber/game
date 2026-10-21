extends "res://scripts/ui/screens/screen_base.gd"
## Store: optional purchases. In debug builds the mock store is used and nothing is charged.

const ITEMS := [
	{"id": "remove_ads", "title": "Remove ads", "text": "No more interstitial ads. Optional rewarded ads stay available if you want free hints."},
	{"id": "garden_pack", "title": "Aurora garden pack", "text": "Four exclusive cosmetic plants for your garden."},
	{"id": "hint_pack_10", "title": "10 hints", "text": "A bundle of hints. Hints are always optional."},
]

var _list: VBoxContainer


func _ready() -> void:
	build("Store")
	var mode := Game.billing.adapter.name()
	if mode == "mock":
		body.add_child(StudioUI.label("Test store: purchases are simulated and free.", 24, Color("f0e442")))
	elif not Game.billing.connected:
		body.add_child(StudioUI.label("The store is not available right now. You can keep playing; everything in the game is earnable without buying.", 24, Palette.TEXT_DIM))
	_list = scroll_area()
	Game.billing.granted.connect(_on_granted)
	Game.billing.pending.connect(_on_pending)
	Game.billing.failed.connect(_on_failed)
	_rebuild()


func _exit_tree() -> void:
	Game.billing.granted.disconnect(_on_granted)
	Game.billing.pending.disconnect(_on_pending)
	Game.billing.failed.disconnect(_on_failed)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(StudioUI.label("Hints: %d" % Game.hints(), 28, Palette.TEXT_DIM))
	for item in ITEMS:
		var panel := PanelContainer.new()
		_list.add_child(panel)
		var v := StudioUI.vbox(10)
		panel.add_child(v)
		v.add_child(StudioUI.label(item.title, 32, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(StudioUI.label(item.text, 24, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		var price: String = Game.billing.store_products.get(item.id, {}).get("price", "")
		var owned := Game.billing.is_owned(item.id)
		var b := StudioUI.button("Owned" if owned else ("Buy  " + price).strip_edges(), func(): Game.buy_product(item.id))
		b.disabled = owned or not Game.billing.connected
		v.add_child(b)
	_list.add_child(StudioUI.button("Restore purchases", Game.billing.restore_purchases))


func _on_granted(id: String, _p: Dictionary) -> void:
	host.toast("Thank you! %s is ready." % id.replace("_", " "))
	Game.audio.play("unlock")
	_rebuild()


func _on_pending(_id: String) -> void:
	host.toast("Payment pending. We'll unlock it as soon as it clears.")


func _on_failed(_id: String, reason: String) -> void:
	host.toast("Purchase not completed (%s)." % reason)
	_rebuild()
