extends SceneTree
func _init() -> void:
	var errors: Array = preload("res://tests/unit/test_sim_m2.gd").new().run()
	for error in errors: printerr(error)
	print("M2 failures=", errors.size())
	quit(0 if errors.is_empty() else 1)
