extends SceneTree
func _init() -> void:
	var failures: Array = preload("res://tests/unit/test_sim_m4b.gd").new().run()
	for failure in failures: printerr("FAIL ", failure)
	print("M4b unit: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
