extends SceneTree
# Headless test runner: godot --headless --path . -s tests/run_tests.gd
# Discovers tests/unit/test_*.gd; each exposes `func run() -> Array` of failure strings.

func _init() -> void:
	var failures := 0
	var dir := DirAccess.open("res://tests/unit")
	if dir == null:
		printerr("FALHA: diretório de testes ausente")
		quit(1)
		return
	for f in dir.get_files():
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script = load("res://tests/unit/" + f)
		if script == null or not script.can_instantiate():
			printerr("FALHA: teste não compilou: ", f)
			failures += 1
			continue
		var t = script.new()
		if not t.has_method("run"):
			printerr("FALHA: teste sem método run: ", f)
			failures += 1
			continue
		var errs: Array = t.run()
		for e in errs:
			printerr("FAIL ", f, ": ", e)
		print("%s: %s" % [f, "ok" if errs.is_empty() else "FAILED"])
		failures += errs.size()
	quit(1 if failures > 0 else 0)
