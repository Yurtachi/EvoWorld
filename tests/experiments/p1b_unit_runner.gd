extends SceneTree
func _init() -> void:
	var failures: Array = preload("res://tests/unit/test_sim_p1b.gd").new().run()
	for failure in failures: printerr(failure)
	print("P1b unit failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
