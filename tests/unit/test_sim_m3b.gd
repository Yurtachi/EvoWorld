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
	_review_regressions(f)
	_observation_and_memory(f)
	_scalar_search_and_migration(f)
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

func drawn_world():
	var w = Fixture.new().studio(129011)
	var c = w.creatures[w.pet_id]
	var bid: int = w.place_board(c.pos + Vector2(10, 0))
	w.demonstrar_forma(bid, "quadrado")
	for i in range(4):
		w.tick += 1
		w.draw_on_board(c, bid)
	return w

func _review_regressions(f: Array) -> void:
	var w = drawn_world()
	var good: Dictionary = w.to_dict()
	check(World.from_dict(good) != null, "controle positivo RM3 invalido", f)
	var bad := good.duplicate(true)
	bad.creatures[0].atelier.active.status = "active"
	bad.creatures[0].atelier.active.total_segments = 16
	bad.creatures[0].atelier.active.step_index = 8
	check(World.from_dict(bad) == null, "RM3-01 aceitou sessao 16 segmentos / indice 8", f)
	bad = good.duplicate(true)
	bad.creatures[0].atelier.active.step_index = 1
	check(World.from_dict(bad) == null, "RM3-01 aceitou contador incoerente com acoes", f)
	for collection in ["gallery", "board", "creature"]:
		bad = good.duplicate(true)
		var arts: Array = bad.gallery if collection == "gallery" else (bad.boards[0].artifacts if collection == "board" else bad.creatures[0].atelier.artifacts)
		arts.append(arts[0].duplicate(true))
		check(World.from_dict(bad) == null, "RM3-02 aceitou ID duplicado em " + collection, f)
	bad = good.duplicate(true)
	bad.creatures[0].atelier.artifacts[0].title = "replica adulterada"
	check(World.from_dict(bad) == null, "RM3-02 aceitou replicas divergentes", f)
	for mutation in range(3):
		bad = good.duplicate(true)
		if mutation == 0: bad.boards[0].reference_strokes[0][1] = [3.0, 4.0]
		if mutation == 1: bad.boards[0].reference_strokes = [[[3.0, 4.0], [4.0, 5.0]]]
		if mutation == 2: bad.boards[0].reference_shape = "linha"
		check(World.from_dict(bad) == null, "RM3-03 aceitou referencia adulterada " + str(mutation), f)
	check(w.gallery[0].title == Textos.texto("m3_artifact_title", [Textos.texto("shape_quadrado"), 1, w.creatures[w.pet_id].name]), "RM3-05 titulo nao vem de Textos", f)
	check(not Textos.texto("m3_policy_naive").contains("naive") and not Textos.texto("m3_ablation_note").contains("naive"), "RM3-04 termo tecnico visivel", f)

func _observation_and_memory(f: Array) -> void:
	for condition in ["disabled", "far", "behind", "occluded"]:
		var w = Fixture.new().studio(129012)
		var c = w.creatures[w.pet_id]
		c.atelier = Atelier.new()
		var pos: Vector2 = c.pos + Vector2(40, 0)
		if condition == "disabled": c.atelier.observation_enabled = false
		if condition == "far": pos = c.pos + Vector2(300, 0)
		if condition == "behind":
			c.genome.vision_fov = 1.0
			pos = c.pos - Vector2(40, 0)
		if condition == "occluded": w.place_obstacle(c.pos + Vector2(20, 0), 8.0)
		var bid: int = w.place_board(pos)
		w.demonstrar_forma(bid, "circulo")
		check(not c.atelier.has_observed("circulo") and c.atelier.propose_actions("circulo", Rng.new(1)).is_empty(), "observacao vazou em " + condition, f)
	var w = drawn_world()
	var c = w.creatures[w.pet_id]
	var a = c.atelier
	check(a.has_observed("quadrado") and a.shape_memory.size() <= 6 and a.shape_memory.quadrado.stroke3.size() <= 8, "memoria nao limitada", f)
	var actions: Array = a.propose_actions("quadrado", Rng.new(129013))
	var body := [c.energy, c.hydration, c.pos]
	var updates: int = a.updates
	var decoder: Array = a.best_params.duplicate()
	w.boards[0].reference_strokes = []
	w.boards[0].reference_params = {}
	check(actions == a.propose_actions("quadrado", Rng.new(129013)), "reproducao depende de vertices externos", f)
	for i in range(4):
		w.tick += 1
		w.draw_on_board(c, int(w.boards[0].id))
	check(a.updates == updates and a.best_params == decoder, "memoria sem referencia inventou feedback", f)
	check([c.energy, c.hydration, c.pos] == body, "atelie alterou corpo", f)
	check(World.from_dict(w.to_dict()) != null, "save com demonstracao limpa rejeitado", f)
	var mem_before: Dictionary = a.to_dict().shape_memory
	var loaded = World.from_dict(JSON.parse_string(Fixture.new().snapshot(w)))
	check(loaded != null and loaded.creatures[loaded.pet_id].atelier.shape_memory == mem_before, "memoria perdida no roundtrip", f)
	a.clear_memory()
	check(a.propose_actions("quadrado", Rng.new(1)).is_empty(), "reproducao sem memoria aceita", f)

func _scalar_search_and_migration(f: Array) -> void:
	var a := Atelier.new()
	var initial: Array = a.best_params.duplicate()
	a.apply_feedback("linha", 0.8)
	check(a.best_params == initial and a.decoder_params != initial, "busca nao gerou primeira proposta", f)
	var proposal: Array = a.decoder_params.duplicate()
	a.apply_feedback("linha", 0.2)
	check(a.best_params == proposal, "busca nao aceitou menor erro escalar", f)
	a.apply_feedback("linha", 0.9)
	check(a.best_params == proposal, "busca aceitou erro pior", f)
	var before := a.to_dict()
	a.apply_feedback("linha", NAN)
	check(a.to_dict() == before, "feedback NaN alterou politica", f)
	var w = drawn_world()
	var legacy: Dictionary = w.to_dict()
	legacy.save_version = 10
	var old_a := {}
	for key in ["version", "next_id", "learning", "policy_mode", "updates", "offset_weights", "dir_weights", "len_weights", "last_error", "attempts", "artifacts", "active"]:
		old_a[key] = legacy.creatures[0].atelier[key]
	old_a.version = 1
	legacy.creatures[0].atelier = old_a
	var migrated = World.from_dict(legacy)
	check(migrated != null, "migracao v10 real rejeitada", f)
	if migrated != null:
		var ma = migrated.creatures[migrated.pet_id].atelier
		check(migrated.to_dict().save_version == World.SAVE_VERSION and ma.shape_memory.is_empty() and ma.to_dict().best_params == Atelier.new().to_dict().best_params, "migracao inventou memoria/calibracao X5", f)
		check(World._migrate_v10(migrated.to_dict()) == migrated.to_dict() and Atelier.migrate_v1(ma.to_dict()) == ma.to_dict(), "migracao nao idempotente", f)
	for bad_value in [NAN, INF, -INF, true, null, [], {}, "invalido"]:
		var bad: Dictionary = w.to_dict()
		bad.creatures[0].atelier.decoder_params[0] = bad_value
		check(World.from_dict(bad) == null, "decoder hostil aceito", f)
		bad = w.to_dict()
		bad.creatures[0].atelier.shape_memory.quadrado.turn_rads[1] = bad_value
		check(World.from_dict(bad) == null, "memoria hostil aceita", f)
