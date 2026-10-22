class_name StudioPlayBillingAdapter
extends StudioBillingAdapter
## Google Play Billing through the official godot-sdk-integrations "GodotGooglePlayBilling"
## plugin (MIT, Godot 4.2+). The plugin is looked up at runtime by its global class name
## BillingClient, so projects without the plugin still load; then the store reports itself
## unavailable and purchases stay disabled.
##
## Needs: the plugin in addons/GodotGooglePlayBilling, a Gradle Android build, products set up
## in Play Console, and testing with a licence tester. Only use it when the game's
## monetization config enables Play Billing (see docs/monetization.md).

const CLIENT_CLASS := "BillingClient"
const RETRY_SECONDS := [2.0, 5.0, 15.0, 60.0]

var _client: Object
var _enums := {}
var _product_ids := PackedStringArray()
var _retries := 0
var _buying := "" ## product of the purchase flow in progress, for failure reports


func name() -> String:
	return "play_billing"


static func plugin_available() -> bool:
	return _client_script() != null and Engine.has_singleton("GodotGooglePlayBilling")


static func _client_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c.get("class", "") == CLIENT_CLASS:
			return load(c.path)
	return null


func start_connection() -> void:
	var script := _client_script()
	if script == null or not Engine.has_singleton("GodotGooglePlayBilling"):
		connected.emit(false)
		return
	if _client == null:
		_client = script.new()
		_enums = script.get_script_constant_map()
		if _client is Node:
			(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_client)
		_client.connect("connected", _on_connected)
		_client.connect("disconnected", _on_disconnected)
		_client.connect("connect_error", _on_connect_error)
		_client.connect("query_product_details_response", _on_product_details)
		_client.connect("query_purchases_response", _on_query_purchases)
		_client.connect("on_purchase_updated", _on_purchase_updated)
		_client.connect("acknowledge_purchase_response", func(r: Dictionary):
			acknowledged.emit(str(r.get("token", "")), _ok(r)))
		_client.connect("consume_purchase_response", func(r: Dictionary):
			consumed.emit(str(r.get("token", "")), _ok(r)))
	_client.call("start_connection")


func query_products(ids: PackedStringArray) -> void:
	_product_ids = ids
	if _ready():
		_client.call("query_product_details", ids, _enum("ProductType", "INAPP", 0))
	else:
		products_received.emit([])


func purchase(product_id: String) -> void:
	if not _ready():
		purchase_failed.emit(product_id, "store unavailable")
		return
	_buying = product_id
	var r = _client.call("purchase", product_id)
	if typeof(r) == TYPE_DICTIONARY and not _ok(r):
		purchase_failed.emit(product_id, _reason(r))


func query_purchases() -> void:
	if _ready():
		_client.call("query_purchases", _enum("ProductType", "INAPP", 0))


func acknowledge(token: String) -> void:
	if _ready():
		_client.call("acknowledge_purchase", token)
	else:
		acknowledged.emit(token, false)


func consume(token: String) -> void:
	if _ready():
		_client.call("consume_purchase", token)
	else:
		consumed.emit(token, false)


func _ready() -> bool:
	return _client != null and bool(_client.call("is_ready"))


func _on_connected() -> void:
	_retries = 0
	connected.emit(true)


func _on_disconnected() -> void:
	_reconnect_later()


func _on_connect_error(_code: int, _message: String) -> void:
	connected.emit(false)
	_reconnect_later()


func _reconnect_later() -> void:
	if _retries >= RETRY_SECONDS.size():
		return
	var wait: float = RETRY_SECONDS[_retries]
	_retries += 1
	(Engine.get_main_loop() as SceneTree).create_timer(wait).timeout.connect(func():
		if _client != null and not _ready():
			_client.call("start_connection"))


func _on_product_details(r: Dictionary) -> void:
	if not _ok(r):
		products_received.emit([])
		return
	var out: Array = []
	for d in r.get("product_details", []):
		var price := ""
		var offer = d.get("one_time_purchase_offer_details", {})
		if typeof(offer) == TYPE_DICTIONARY:
			price = str(offer.get("formatted_price", ""))
		out.append({"id": str(d.get("product_id", "")), "title": str(d.get("name", d.get("title", ""))), "price": price})
	products_received.emit(out)


func _on_query_purchases(r: Dictionary) -> void:
	# Only a successful answer is authoritative; on errors keep what the player already has.
	if _ok(r):
		purchases_restored.emit(_convert_all(r.get("purchases", [])))


func _on_purchase_updated(r: Dictionary) -> void:
	if _ok(r):
		purchases_updated.emit(_convert_all(r.get("purchases", [])))
		return
	var code := int(r.get("response_code", -999))
	if code == int(_enum("BillingResponseCode", "ITEM_ALREADY_OWNED", 7)):
		query_purchases() # the store says we own it: restore so the entitlement appears
	purchase_failed.emit(_buying, _reason(r))


func _convert_all(list: Array) -> Array:
	var out: Array = []
	for p in list:
		var ids = p.get("product_ids", [])
		var state := "pending"
		if int(p.get("purchase_state", -1)) == int(_enum("PurchaseState", "PURCHASED", 1)):
			state = "purchased"
		for id in ids:
			out.append({
				"product_id": str(id), "token": str(p.get("purchase_token", "")),
				"order_id": str(p.get("order_id", "")), "state": state,
				"acknowledged": bool(p.get("is_acknowledged", false)),
				"original_json": str(p.get("original_json", "")), "signature": str(p.get("signature", "")),
			})
	return out


func _ok(r: Dictionary) -> bool:
	return int(r.get("response_code", -999)) == int(_enum("BillingResponseCode", "OK", 0))


func _reason(r: Dictionary) -> String:
	var code := int(r.get("response_code", -999))
	if code == int(_enum("BillingResponseCode", "USER_CANCELED", 1)):
		return "cancelled"
	return "error %d: %s" % [code, r.get("debug_message", "")]


func _enum(enum_name: String, key: String, fallback: int) -> int:
	var e = _enums.get(enum_name, {})
	if typeof(e) == TYPE_DICTIONARY and e.has(key):
		return int(e[key])
	return fallback
