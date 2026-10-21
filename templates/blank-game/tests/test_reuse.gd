extends RefCounted
## Proves studio-core works in a project that has no Circuit Garden code.

var t
const DIR := "user://template_test"


func _studio() -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	var s: Node = load("res://scripts/studio.gd").new()
	t.root.add_child(s)
	s.configure(DIR.path_join("save.json"), DIR.path_join("settings.cfg"))
	return s


func test_no_circuit_garden_classes_present() -> void:
	for c in ProjectSettings.get_global_class_list():
		t.check(not (c["class"] as String).begins_with("CG"), "found game class " + c["class"])


func test_services_start_and_persist() -> void:
	var s := _studio()
	s.save.section("progress")["score"] = 7
	t.check(s.save.save_now())
	var again: Node = load("res://scripts/studio.gd").new()
	t.root.add_child(again)
	again.configure(DIR.path_join("save.json"), DIR.path_join("settings.cfg"))
	t.eq(int(again.save.section("progress").score), 7)
	t.root.remove_child(s)
	t.root.remove_child(again)
	s.free()
	again.free()


func test_mock_monetization_works() -> void:
	var s := _studio()
	var got := []
	s.ads.rewarded_result.connect(func(ok, _r): got.append(ok))
	s.ads.show_rewarded()
	t.eq(got, [true])
	s.billing.buy("remove_ads")
	t.check(s.billing.is_owned("remove_ads"))
	t.root.remove_child(s)
	s.free()


func test_main_menu_builds() -> void:
	var s := _studio()
	var menu: Control = load("res://scenes/main.tscn").instantiate()
	t.root.add_child(menu)
	if not menu.is_node_ready():
		menu._ready() # the runner executes before the first frame, so _ready may not have fired
	t.check(menu.get_child_count() > 0)
	menu.free()
	t.root.remove_child(s)
	s.free()
