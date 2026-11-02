extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const Objects = preload("res://scripts/mind/object_memory.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Texto = preload("res://scripts/core/textos.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok:
		failures.append(message)

func snapshot(w) -> String:
	return JSON.stringify(w.to_dict(), "", true, true)

func studio(seed_value: int = 118001, curiosity: float = 0.85):
	var w = World.new(seed_value, {
		"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": false, "personality_enabled": true, "water_enabled": true
	})
	var g := Genes.new()
	g.size = 8.0
	g.speed = 32.0
	g.vision_range = 220.0
	g.vision_fov = snappedf(TAU, 0.000001)
	g.temperament = {"curiosity": curiosity, "caution": 0.3, "sociability": 0.3, "impulsivity": 0.4}
	var cid: int = w.spawn_creature(Vector2(300, 300), "Artista", g)
	w.pet_id = cid
	w.enable_mind(cid)
	var c = w.creatures[cid]
	c.energy = snappedf(c.max_energy * 0.95, 0.000001)
	c.hydration = 95.0
	c.heading = 0.0
	return w

func run() -> Array:
	var f: Array = []
	_primitives_and_bounds(f)
	_motivation_and_object_memory(f)
	_learning_and_shapes(f)
	_persistence_and_determinism(f)
	_hostile_inputs(f)
	return f

func _primitives_and_bounds(f: Array) -> void:
	var w = studio(118010)
	var c = w.creatures[w.pet_id]
	check(w.place_board(Vector2(NAN, 100.0)) == -1 and w.place_board(Vector2(INF, 100.0)) == -1, "place_board aceitou NaN/INF", f)
	w.place_obstacle(Vector2(500, 500), 24.0)
	check(w.place_board(Vector2(500, 500)) == -1, "place_board aceitou posicao obstruida", f)
	var bid: int = w.place_board(c.pos + Vector2(14, 0))
	check(bid > 0 and w.boards.size() == 1, "place_board valido falhou", f)
	# Verify primitive action execution and bounds enforcement.
	var oversized_actions: Array = [{"op": "pen_down", "dir": 0, "len": 0}]
	for i in range(100):
		oversized_actions.append({"op": "segment", "dir": i % 16, "len": 2})
	var exec := Atelier.execute_actions(oversized_actions)
	check(exec.strokes.size() <= Atelier.MAX_STROKES_PER_DRAWING, "strokes excederam MAX_STROKES_PER_DRAWING", f)
	check(int(exec.total_points) <= Atelier.MAX_POINTS_PER_DRAWING, "pontos excederam MAX_POINTS_PER_DRAWING", f)
	check(exec.stroke3.size() <= Atelier.MAX_ACTIONS_PER_DRAWING, "stroke3 excedeu MAX_ACTIONS_PER_DRAWING", f)
	for st in exec.strokes:
		check(st.size() >= 2 and st.size() <= Atelier.MAX_POINTS_PER_STROKE, "stroke fora do limite de pontos", f)
	# Translation and scale invariance of normalized symmetric Chamfer distance.
	for shape in Atelier.SHAPES:
		var ref_a := Atelier.build_reference_strokes(shape, {"center": Vector2(22, 22), "scale": 0.65, "dir_offset": 2})
		var ref_b := Atelier.build_reference_strokes(shape, {"center": Vector2(42, 40), "scale": 1.35, "dir_offset": 2})
		var dist_same := Atelier.chamfer_distance(ref_a, ref_b)
		check(dist_same < 0.05, "Chamfer nao invariante a translacao/escala em " + shape, f)
	var line_ref := Atelier.build_reference_strokes("linha", {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 0})
	var circle_ref := Atelier.build_reference_strokes("circulo", {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 0})
	check(Atelier.chamfer_distance(line_ref, circle_ref) > 0.25, "Chamfer nao distingue linha de circulo", f)

func _motivation_and_object_memory(f: Array) -> void:
	# Creature with very low curiosity and no enthusiasm ignores the board.
	var w_ignore = studio(118011, 0.05)
	var c_ignore = w_ignore.creatures[w_ignore.pet_id]
	w_ignore.place_board(c_ignore.pos + Vector2(20, 0))
	for i in range(30):
		w_ignore.step()
	check(c_ignore.mind.objetivo_atual != "desenhar" and w_ignore.gallery.is_empty(), "criatura sem curiosidade/entusiasmo nao ignorou quadro", f)

	# Curious creature notices board via ObjectMemory, approaches, makes exploratory scribble, pauses, and resumes.
	var w = studio(118012, 0.9)
	var c = w.creatures[w.pet_id]
	var bid: int = w.place_board(c.pos + Vector2(28, 0))
	var sensed := w.sense(c)
	check(sensed.get("boards", []).size() == 1 and sensed.boards[0].category == "quadro", "quadro visivel ausente nos sensores", f)
	Objects.observe(c.mind, sensed, w.tick)
	check(c.mind.objects.entries.has(str(bid)) and c.mind.objects.entries[str(bid)].source == "observado", "ObjectMemory nao registrou quadro observado", f)
	check(not w.draw_on_board(c, bid), "desenho fora de alcance aceito", f)

	var energy_start: float = c.energy
	var draw_ticks := 0
	var non_draw_after_first := 0
	var first_done_tick := -1
	for i in range(110):
		c.hydration = 95.0
		w.step()
		if c.last_action == "draw_stroke":
			draw_ticks += 1
		if w.gallery.size() >= 1 and first_done_tick == -1:
			first_done_tick = w.tick
		elif first_done_tick != -1 and w.gallery.size() == 1 and c.mind.objetivo_atual != "desenhar":
			non_draw_after_first += 1
	check(draw_ticks >= 4 and w.gallery.size() >= 2, "criatura nao concluiu rabisco inicial nem retomou sozinha", f)
	check(non_draw_after_first >= 10, "anti-loop nao liberou objetivo desenhar apos concluir rabisco", f)
	check(c.energy < energy_start, "desenhar nao consumiu custo energetico fisico real", f)
	check(c.mind.objects.entries[str(bid)].source == "interagido", "ObjectMemory nao marcou quadro como interagido", f)
	check(c.mind.mind_log.any(func(r): return r.objetivo == "desenhar" and r.motivo == "mind.iniciativa.desenhar"), "log mental sem objetivo/motivo desenhar", f)
	if not w.gallery.is_empty():
		var art: Dictionary = w.gallery[0]
		var replayed := Atelier.execute_actions(art.actions)
		check(art.target_shape == "rabisco" and art.owner_id == c.id and art.strokes == replayed.strokes and art.stroke3 == replayed.stroke3, "rabisco nao equivale a sequencia de acoes primitivas", f)

	# Critical hunger and thirst override drawing.
	c.energy = c.max_energy * 0.15
	check(c.mind.decide(c, w.tick, w.sense(c)) == "comer" and c.mind.motivo == "mind.urgency", "fome critica nao interrompeu desenhar", f)
	c.energy = c.max_energy * 0.9
	c.hydration = 15.0
	check(c.mind.decide(c, w.tick, w.sense(c)) == "beber" and c.mind.motivo == "mind.urgency", "sede critica nao interrompeu desenhar", f)

func _learning_and_shapes(f: Array) -> void:
	var w = studio(118013, 0.9)
	var c = w.creatures[w.pet_id]
	var bid: int = w.place_board(c.pos + Vector2(10, 0))
	check(not w.demonstrar_forma(bid, "letra_A") and not w.demonstrar_forma(bid, "simbolo"), "simbolo/letra aceito fora de escopo M3a", f)

	# Untrained (naive) vs random vs trained online across all 3 shapes.
	for shape in Atelier.SHAPES:
		var w_rand = studio(118020, 0.9)
		var c_rand = w_rand.creatures[w_rand.pet_id]
		var b_rand: int = w_rand.place_board(c_rand.pos + Vector2(10, 0))
		c_rand.atelier = Atelier.new()
		c_rand.atelier.policy_mode = "random"
		c_rand.atelier.learning = false
		w_rand.demonstrar_forma(b_rand, shape, {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 2})
		for step_i in range(4):
			w_rand.tick += 1
			w_rand.draw_on_board(c_rand, b_rand)
		var err_random: float = c_rand.atelier.attempts.back().error

		var w_naive = studio(118020, 0.9)
		var c_naive = w_naive.creatures[w_naive.pet_id]
		var b_naive: int = w_naive.place_board(c_naive.pos + Vector2(10, 0))
		c_naive.atelier = Atelier.new()
		c_naive.atelier.policy_mode = "naive"
		c_naive.atelier.learning = false
		w_naive.demonstrar_forma(b_naive, shape, {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 2})
		for step_i in range(4):
			w_naive.tick += 1
			w_naive.draw_on_board(c_naive, b_naive)
		var err_naive: float = c_naive.atelier.attempts.back().error

		var w_train = studio(118020, 0.9)
		var c_train = w_train.creatures[w_train.pet_id]
		var b_train: int = w_train.place_board(c_train.pos + Vector2(10, 0))
		for attempt_idx in range(8):
			w_train.demonstrar_forma(b_train, shape, {"center": Vector2(28 + (attempt_idx % 3) * 4, 30), "scale": 0.85 + 0.1 * float(attempt_idx % 3), "dir_offset": (attempt_idx * 3) % 16})
			var energy_before_attempt: float = c_train.energy
			for step_i in range(4):
				w_train.tick += 1
				w_train.draw_on_board(c_train, b_train)
			check(c_train.energy <= energy_before_attempt, "feedback de desenho adicionou energia fisica", f)
		# Evaluate on unseen scale/offset.
		w_train.demonstrar_forma(b_train, shape, {"center": Vector2(36, 34), "scale": 1.25, "dir_offset": 5})
		for step_i in range(4):
			w_train.tick += 1
			w_train.draw_on_board(c_train, b_train)
		var err_trained: float = c_train.atelier.attempts.back().error
		var snap: Dictionary = c_train.atelier_snapshot()
		check(err_trained < err_random and err_trained < err_naive and err_trained < Atelier.SUCCESS_THRESHOLD, "aprendizado nao reduziu erro em " + shape + (" (trained=%.3f naive=%.3f rand=%.3f)" % [err_trained, err_naive, err_random]), f)
		check(bool(snap.competence[shape].learned) and int(snap.updates) > 0, "competencia nao registrada em atelier_snapshot para " + shape, f)

	# Reproduction does not inherit atelier competence.
	c.atelier = Atelier.new()
	c.atelier.updates = 24
	c.age = w.min_reproduction_age
	c.energy = c.max_energy
	w.reproduction_enabled = true
	var child_id: int = w.reproduce(c.id)
	check(child_id != -1 and w.creatures[child_id].atelier == null, "filhote herdou competencia de atelie", f)

func _persistence_and_determinism(f: Array) -> void:
	var a = studio(118030, 0.9)
	var b = studio(118030, 0.9)
	var ba: int = a.place_board(a.creatures[a.pet_id].pos + Vector2(20, 0))
	var bb: int = b.place_board(b.creatures[b.pet_id].pos + Vector2(20, 0))
	a.demonstrar_forma(ba, "circulo", {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 0})
	b.demonstrar_forma(bb, "circulo", {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 0})
	for i in range(120):
		a.creatures[a.pet_id].energy = a.creatures[a.pet_id].max_energy * 0.9
		a.creatures[a.pet_id].hydration = 90.0
		b.creatures[b.pet_id].energy = b.creatures[b.pet_id].max_energy * 0.9
		b.creatures[b.pet_id].hydration = 90.0
		a.step()
		b.step()
	check(snapshot(a) == snapshot(b), "determinismo M3 divergiu com mesma seed", f)
	check(not a.gallery.is_empty() and a.creatures[a.pet_id].atelier != null, "mundo determinista nao produziu artefato", f)

	var restored = World.from_dict(JSON.parse_string(snapshot(a)))
	check(restored != null and restored.to_dict().save_version == World.SAVE_VERSION and snapshot(restored) == snapshot(a), "roundtrip v10 perdeu quadro/galeria/competencia", f)
	if restored != null:
		for i in range(60):
			a.creatures[a.pet_id].energy = a.creatures[a.pet_id].max_energy * 0.9
			a.creatures[a.pet_id].hydration = 90.0
			restored.creatures[restored.pet_id].energy = restored.creatures[restored.pet_id].max_energy * 0.9
			restored.creatures[restored.pet_id].hydration = 90.0
			a.step()
			restored.step()
		check(snapshot(a) == snapshot(restored), "continuacao apos roundtrip v10 divergiu", f)

	var store := Store.new("user://m3_unit_saves")
	check(store.save_world(a, "atelier_v10").ok, "save_world v10 falhou", f)
	var disk := store.load_world("atelier_v10")
	check(disk.ok and snapshot(disk.world) == snapshot(a), "load_world v10 divergiu", f)

	# Retention after 2000 idle ticks.
	var c_ret = a.creatures[a.pet_id]
	var weights_before: Array = c_ret.atelier.offset_weights.duplicate()
	a.boards.clear()
	for i in range(2000):
		c_ret.energy = c_ret.max_energy * 0.9
		c_ret.hydration = 90.0
		a.step()
	check(c_ret.atelier.offset_weights == weights_before, "competencia degradou apos 2000 ticks ociosos", f)

	# Snapshot isolation.
	var ui_snap: Dictionary = c_ret.atelier_snapshot()
	ui_snap.attempts.clear()
	ui_snap.policy_summary.offset_weights.fill(99.0)
	check(not c_ret.atelier.attempts.is_empty() and c_ret.atelier.offset_weights == weights_before, "atelier_snapshot expos estado interno mutavel", f)

	# Migration v9 -> v10 idempotence.
	var v9_world = studio(118031)
	var v9_dict: Dictionary = v9_world.to_dict()
	v9_dict["save_version"] = 9
	var migrated = World.from_dict(v9_dict)
	check(migrated != null and migrated.boards.is_empty() and World._migrate_v9(migrated.to_dict()) == migrated.to_dict(), "migracao v9 -> v10 falhou ou nao idempotente", f)

func _hostile_inputs(f: Array) -> void:
	var w = studio(118040, 0.9)
	var c = w.creatures[w.pet_id]
	var bid: int = w.place_board(c.pos + Vector2(10, 0))
	w.demonstrar_forma(bid, "quadrado", {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 0})
	for i in range(4):
		w.tick += 1
		w.draw_on_board(c, bid)
	var good: Dictionary = w.to_dict()
	check(World.from_dict(good) != null, "save valido v10 rejeitado", f)

	for bad_scalar in [NAN, INF, -INF, "bad", null, true]:
		var bad := good.duplicate(true)
		bad.boards[0].pos = [bad_scalar, 10.0]
		check(World.from_dict(bad) == null, "save aceitou board.pos hostil", f)
		bad = good.duplicate(true)
		bad.creatures[0].atelier.offset_weights[0] = bad_scalar
		check(World.from_dict(bad) == null, "save aceitou peso NaN/hostil", f)
		bad = good.duplicate(true)
		bad.gallery[0].error = bad_scalar
		check(World.from_dict(bad) == null, "save aceitou erro de artefato hostil", f)

	# Forged pre-made image (strokes not matching primitive actions) must be rejected.
	var forged := good.duplicate(true)
	forged.gallery[0].strokes[0][0] = [1.234567, 1.234567]
	check(World.from_dict(forged) == null, "save aceitou imagem/strokes forjados sem equivalencia de acoes", f)

	# Oversized strokes and action arrays must be rejected.
	var huge_actions := good.duplicate(true)
	huge_actions.gallery[0].actions.resize(Atelier.MAX_ACTIONS_PER_DRAWING + 1)
	check(World.from_dict(huge_actions) == null, "save aceitou acoes de desenho acima do limite", f)

	var huge_weights := good.duplicate(true)
	huge_weights.creatures[0].atelier.dir_weights.append(0.0)
	check(World.from_dict(huge_weights) == null, "save aceitou tabela de pesos adulterada", f)

	var id_collision := good.duplicate(true)
	id_collision.boards[0].id = c.id
	check(World.from_dict(id_collision) == null, "save aceitou colisao de ID entre quadro e criatura", f)

	# Verify M3 player texts in scripts/core/textos.gd use pt-BR observational language and never 'sente'.
	for key in Texto.M3_UI:
		var val: String = str(Texto.M3_UI[key]).to_lower()
		check(not ("sente" in val), "M3_UI contem palavra proibida 'sente' em " + key, f)
	check(Texto.acao("draw_stroke") != Texto.texto("action_unknown") and Texto.acao("seek_board") != Texto.texto("action_unknown"), "acoes M3 sem traducao em Textos", f)
	check(Texto.razao("mind.desenhar") == Texto.M3_UI["m1_goal_desenhar"] and Texto.razao("mind.iniciativa.desenhar") == Texto.M3_UI["m1_reason_iniciativa.desenhar"], "razoes M3 sem traducao em Textos", f)
