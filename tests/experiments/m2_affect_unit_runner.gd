extends SceneTree
const Suite = preload("res://tests/unit/test_sim_m1b.gd")
func _init() -> void:
	var failures: Array = Suite.new().run()
	for failure in failures: printerr("FAIL M1b: ", failure)
	print("M1b: ", "ok" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
