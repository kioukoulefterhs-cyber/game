class_name StudioBillingAdapter
extends RefCounted
## Interface for a store backend. A purchase is a Dictionary:
## { product_id, token, order_id, state: "purchased" | "pending", acknowledged: bool }

signal connected(ok: bool)
signal products_received(products: Array) ## [{id, title, price}]
signal purchases_updated(purchases: Array) ## new purchases and restore results
signal purchase_failed(product_id: String, reason: String) ## "cancelled", "error", ...
signal acknowledged(token: String, ok: bool)
signal consumed(token: String, ok: bool)


func name() -> String:
	return "none"


func start_connection() -> void:
	connected.emit(false)


func query_products(_ids: PackedStringArray) -> void:
	products_received.emit([])


func purchase(product_id: String) -> void:
	purchase_failed.emit(product_id, "unavailable")


func query_purchases() -> void:
	purchases_updated.emit([])


func acknowledge(token: String) -> void:
	acknowledged.emit(token, false)


func consume(token: String) -> void:
	consumed.emit(token, false)
