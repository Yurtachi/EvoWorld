extends SceneTree
# Harness aberto de robustez; não é um avaliador de holdout científico.
const Suite = preload("res://tests/unit/test_terminal.gd")

func _init() -> void:
	var failures: Array = Suite.new().run()
	for failure in failures:
		printerr("FAIL terminal: ", failure)
	print("Terminal seguro: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
