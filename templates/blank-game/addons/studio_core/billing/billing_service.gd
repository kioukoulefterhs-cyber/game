class_name StudioBilling
extends Node
## Purchase flow on top of a store adapter:
## pending purchases are never granted; each token is granted at most once; non-consumables
## are acknowledged and consumables consumed only after granting; restore rebuilds
## permanent entitlements from the store's purchase list.

signal granted(product_id: String, purchase: Dictionary)
signal pending(product_id: String)
signal failed(product_id: String, reason: String)
signal entitlements_changed

enum Kind { CONSUMABLE, NON_CONSUMABLE }

var adapter: StudioBillingAdapter = StudioBillingAdapter.new()
var verifier := StudioPurchaseVerifier.new()
var products := {} ## id -> Kind
var store_products := {} ## id -> {title, price} from the store
var owned := {} ## non-consumable id -> true
var processed_tokens := {} ## token -> true, persisted to stop double grants
var connected := false


func configure(p_adapter: StudioBillingAdapter, catalog: Dictionary) -> void:
	adapter = p_adapter
	products = catalog
	verifier.known_products = PackedStringArray(catalog.keys())
	adapter.connected.connect(_on_connected)
	adapter.products_received.connect(func(list):
		for p in list:
			store_products[p.id] = p)
	adapter.purchases_updated.connect(_on_purchases)
	adapter.purchase_failed.connect(func(id, reason): failed.emit(id, reason))
	adapter.start_connection()


## Loads persisted state: { owned: [...], tokens: [...] }.
func restore_state(state: Dictionary) -> void:
	for id in state.get("owned", []):
		owned[id] = true
	for t in state.get("tokens", []):
		processed_tokens[t] = true


func export_state() -> Dictionary:
	return {"owned": owned.keys(), "tokens": processed_tokens.keys()}


func is_owned(id: String) -> bool:
	return owned.has(id)


func buy(id: String) -> void:
	if not products.has(id):
		failed.emit(id, "unknown product")
		return
	if products[id] == Kind.NON_CONSUMABLE and is_owned(id):
		failed.emit(id, "already owned")
		return
	if not connected:
		failed.emit(id, "store unavailable")
		return
	adapter.purchase(id)


func restore_purchases() -> void:
	adapter.query_purchases()


func _on_connected(ok: bool) -> void:
	connected = ok
	if ok:
		adapter.query_products(PackedStringArray(products.keys()))
		adapter.query_purchases()


func _on_purchases(list: Array) -> void:
	for p in list:
		_handle_purchase(p)


func _handle_purchase(p: Dictionary) -> void:
	var id: String = p.get("product_id", "")
	if not products.has(id):
		return
	if p.get("state") == "pending":
		pending.emit(id)
		return
	var token: String = p.get("token", "")
	var kind: Kind = products[id]
	if processed_tokens.has(token):
		# Already granted. Restores still rebuild ownership and finish any lost acknowledgement.
		if kind == Kind.NON_CONSUMABLE:
			if not owned.has(id):
				owned[id] = true
				entitlements_changed.emit()
			if not p.get("acknowledged", false):
				adapter.acknowledge(token)
		return
	var check := verifier.verify(p)
	if not check.ok:
		failed.emit(id, "verification failed: %s" % check.reason)
		return
	processed_tokens[token] = true
	if kind == Kind.NON_CONSUMABLE:
		owned[id] = true
		entitlements_changed.emit()
	granted.emit(id, p)
	if kind == Kind.NON_CONSUMABLE:
		if not p.get("acknowledged", false):
			adapter.acknowledge(token)
	else:
		adapter.consume(token)
