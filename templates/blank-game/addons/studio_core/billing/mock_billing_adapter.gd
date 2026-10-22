class_name StudioMockBillingAdapter
extends StudioBillingAdapter
## Offline store for development and tests. No money, no network.
## `outcome` scripts the next purchase: success | cancel | pending | error | offline.

var outcome := "success"
var catalog: Array = [] ## [{id, title, price}]
var owned: Array = [] ## purchases the "store" remembers, for restore
var acks: PackedStringArray = []
var consumes: PackedStringArray = []
var _counter := 0
var _pending: Dictionary = {}


func name() -> String:
	return "mock"


func start_connection() -> void:
	connected.emit(outcome != "offline")


func query_products(ids: PackedStringArray) -> void:
	products_received.emit(catalog.filter(func(p): return ids.has(p.id)))


func purchase(product_id: String) -> void:
	match outcome:
		"cancel":
			purchase_failed.emit(product_id, "cancelled")
		"error", "offline":
			purchase_failed.emit(product_id, outcome)
		"pending":
			var p := _make(product_id, "pending")
			_pending[p.token] = p
			purchases_updated.emit([p.duplicate()])
		_:
			var p := _make(product_id, "purchased")
			owned.append(p)
			purchases_updated.emit([p.duplicate()])


## Simulates a pending payment (e.g. cash) clearing later.
func complete_pending(token: String) -> void:
	if not _pending.has(token):
		return
	var p: Dictionary = _pending[token]
	_pending.erase(token)
	p.state = "purchased"
	owned.append(p)
	purchases_updated.emit([p.duplicate()])


## Re-sends a purchase the store already delivered (the store may do this at any time).
func redeliver(token: String) -> void:
	for p in owned:
		if p.token == token:
			purchases_updated.emit([p.duplicate()])


func query_purchases() -> void:
	purchases_updated.emit(owned.map(func(p): return p.duplicate()))


func acknowledge(token: String) -> void:
	acks.append(token)
	for p in owned:
		if p.token == token:
			p.acknowledged = true
	acknowledged.emit(token, true)


func consume(token: String) -> void:
	consumes.append(token)
	owned = owned.filter(func(p): return p.token != token)
	consumed.emit(token, true)


func _make(product_id: String, state: String) -> Dictionary:
	_counter += 1
	return {
		"product_id": product_id, "token": "mock-token-%d" % _counter,
		"order_id": "MOCK.%04d" % _counter, "state": state, "acknowledged": false,
	}
