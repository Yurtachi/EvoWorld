extends RefCounted
const Fixture = preload("res://tests/unit/test_sim_m3.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Textos = preload("res://scripts/core/textos.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func run() -> Array:
	var f: Array = []
	_save_after_drawing(f)
	return f

func _save_after_drawing(f: Array) -> void:
	var t := Fixture.new()
	var w = t.studio(129010)
	var c = w.creatures[w.pet_id]
	var bid: int = w.place_board(c.pos + Vector2(20, 0))
	w.demonstrar_forma(bid, "quadrado")
	var drawn := false
	for i in range(80):
		c.energy = snappedf(c.max_energy * 0.95, 0.000001)
		c.hydration = 95.0
		w.step()
		if c.last_action == "draw_stroke":
			drawn = true
			break
	check(drawn and c.personality.episodes.any(func(e): return e.action == "draw_stroke"), "regressao save: episodio de desenho ausente", f)
	var store := Store.new("user://m3b_unit_" + str(OS.get_process_id()))
	var saved := store.save_world(w, "after_drawing")
	check(saved.ok, "save apos episodio draw_stroke falhou: " + saved.message, f)
	var loaded := store.load_world("after_drawing")
	check(loaded.ok and t.snapshot(loaded.world) == t.snapshot(w), "SaveStore roundtrip apos desenhar divergiu", f)
