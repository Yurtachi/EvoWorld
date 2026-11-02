extends SceneTree
const Suite = preload("res://tests/unit/test_sim_m1.gd")
func _init() -> void:
	var failures: Array = Suite.new().run()
	for failure in failures: printerr("FAIL M1: ", failure)
	print("M1: ", "ok" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
