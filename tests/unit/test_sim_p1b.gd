extends RefCounted
const Unit = preload("res://tests/unit/test_sim_p1.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Memory = preload("res://scripts/spatial/spatial_memory.gd")
const Policy = preload("res://scripts/spatial/spatial_policy.gd")
const Data = preload("res://scripts/core/sim_data.gd")

func check(ok: bool, message: String, f: Array) -> void:
	if not ok: f.append(message)

func garden(seed_value: int = 382010):
	var w = Unit.new().garden(seed_value)
	Memory.enable_revision(w.creatures[w.pet_id].mind.spatial)
	return w

func run() -> Array:
	var f: Array = []
	_boundary(f)
	_negative_evidence(f)
	_ecosystem_rng(f)
	_legacy_and_save(f)
	return f

# Deny arbitrary receivers, including aliases and chains, while permitting
# only explicit perceptual channels and the mind's own object memory.
func forbidden_access(source: String, world_scope: bool = false) -> bool:
	var access := RegEx.new()
	access.compile("([A-Za-z_][A-Za-z_0-9]*(?:\\s*\\.\\s*[A-Za-z_][A-Za-z_0-9]*)*)\\s*(?:\\.\\s*(foods|waters|feeders|objects|books|terminals|boards)\\b|\\[\\s*[\"'](foods|waters|feeders|objects|books|terminals|boards)[\"']\\s*\\]|\\.\\s*get\\s*\\(\\s*[\"'](foods|waters|feeders|objects|books|terminals|boards)[\"'])")
	for line in source.split("\n"):
		var code: String = line.get_slice("#", 0)
		for hit in access.search_all(code):
			var receiver := hit.get_string(1).replace(" ", "").replace("\t", "")
			var field := hit.get_string(2) + hit.get_string(3) + hit.get_string(4)
			if receiver in ["sensors", "seen"]: continue
			if field == "objects" and receiver in ["mind", "creature.mind", "data"]: continue
			return true
		if world_scope:
			# In world methods unqualified collections are implicit self accesses.
			var bare := RegEx.new()
			bare.compile("(?<![A-Za-z_0-9.\"'])(foods|waters|feeders|objects|books|terminals|boards)\\b(?![\"'])")
			if bare.search(code) != null: return true
	return false

func _boundary(f: Array) -> void:
	for field in ["foods", "waters", "feeders", "objects", "books", "terminals", "boards"]:
		for alias in ["w", "world_ref", "self.world", "arbitrary_alias", "self"]:
			for expression in [alias + "." + field, alias + "[\"" + field + "\"]", alias + ".get(\"" + field + "\", [])"]:
				check(forbidden_access("var leaked = " + expression), "detector nao pegou " + expression, f)
		check(forbidden_access("for row in " + field + ":\n pass", true) and forbidden_access(field + ".size()", true), "detector nao pegou campo nu " + field, f)
	check(not forbidden_access("sensors.foods\nsensors.get(\"books\", [])\nmind.objects"), "detector rejeitou canal sensorial/memoria", f)
	for folder in ["res://scripts/mind", "res://scripts/spatial", "res://scripts/behavior"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				check(not forbidden_access(FileAccess.get_file_as_string(folder.path_join(file))), "verdade por alias em " + file, f)
	var source := FileAccess.get_file_as_string("res://scripts/world/sim_world.gd")
	for name in ["_mind_action", "_spatial_seek", "_spatial_turn", "_personality_seek_food", "_seek_water"]:
		var body := source.get_slice("func " + name + "(", 1).get_slice("\nfunc ", 0).get_slice("\nstatic func ", 0)
		check(not body.is_empty() and not forbidden_access(body, true), "verdade por alias na decisao " + name, f)

func trained_state() -> Dictionary:
	var s := Memory.empty(35.0)
	Memory.enable_revision(s)
	for i in 8: Memory.evidence(s, "comida", Vector2(100, 100), i, true, 24.0, "interagido")
	return s

func _negative_evidence(f: Array) -> void:
	var full := trained_state()
	var partial := full.duplicate(true)
	var none := full.duplicate(true)
	Memory.evidence(full, "comida", Vector2(100, 100), 20, false, 0.0, "observado", 1.0)
	Memory.evidence(partial, "comida", Vector2(100, 100), 20, false, 0.0, "observado", 0.1)
	Memory.evidence(none, "comida", Vector2(100, 100), 20, false, 0.0, "observado", 0.0)
	check(float(full.lugares[0].expectativa) < float(partial.lugares[0].expectativa) and float(partial.lugares[0].expectativa) < float(none.lugares[0].expectativa), "evidencia negativa nao proporcional a inspecao", f)
	check(int(none.lugares[0].falhas) == 0, "area nao vista virou falha", f)
	check(int(full.lugares[0].retry_tick) == 20 + Memory.RETRY, "cooldown curto nao limitado", f)
	Memory.evidence(full, "comida", Vector2(100, 100), 80, false)
	check(float(full.lugares[0].expectativa) < 0.25 and int(full.lugares[0].falhas) == 2, "duas inspecoes completas nao revisaram", f)
	check(Memory.best(full, "comida", Vector2(100, 100), 81).is_empty(), "abandono nao suspendeu alvo", f)
	check(not Memory.best(full, "comida", Vector2(100, 100), 80 + Memory.REASSESS).is_empty(), "lugar bom nunca e reavaliado", f)
	var w = garden()
	var c = w.creatures[w.pet_id]
	c.mind.spatial = full
	c.heading = 0.0
	var open := Policy.survey_mask(c, full, {"obstacles": []}, c.pos)
	var blocked := Policy.survey_mask(c, full, {"obstacles": [{"pos": c.pos + Vector2(15, 0), "radius": 12.0}]}, c.pos)
	check(Policy.inspected_fraction(blocked) < Policy.inspected_fraction(open), "oclusao nao reduziu area inspecionada", f)
	var narrow := full.duplicate(true)
	narrow.scan_mask = 0
	c.genome.vision_fov = 0.2
	var narrow_mask := Policy.survey_mask(c, narrow, {"obstacles": []}, c.pos)
	check(Policy.inspected_fraction(narrow_mask) < Policy.inspected_fraction(open), "FOV nao limita evidencia negativa", f)
	var water := Memory.empty(35.0)
	Memory.enable_revision(water)
	Memory.evidence(water, "agua", Vector2(100, 100), 0, true)
	check(not Memory.best(water, "agua", Vector2(850, 550), 100).is_empty(), "sede ignorou margem ja observada em favor de busca cega", f)

func _ecosystem_rng(f: Array) -> void:
	var a = garden(382011)
	a.set_feeding_mode("ecosystem")
	a.food_capacity = 3
	a.food_regrow_interval = 3
	a.food_regrow_batch = 1
	var ca = a.creatures[a.pet_id]
	ca.pos = Vector2(80, 80)
	ca.heading = 0.0
	ca.energy = 35.0
	a.step() # Normalize the initial mind goal/log before serialization.
	var b = World.from_dict(a.to_dict())
	check(b != null, "clone v2 rejeitado", f)
	if b == null: return
	for point in [Vector2(800, 500), Vector2(800, 550), Vector2(850, 500)]: b.place_food(point, "fruta")
	var cb = b.creatures[b.pet_id]
	var diverged_rng := false
	for i in 120:
		# Keep the test away from hidden items and boundaries; regrow still
		# consumes a different number of world draws on every actual step.
		ca.pos = Vector2(80, 80)
		cb.pos = ca.pos
		check(a.sense(ca) == b.sense(cb), "sensores diferentes antes do par ecossistema", f)
		a.step()
		b.step()
		check(ca.to_dict() == cb.to_dict(), "comida oculta alterou vagar v2 tick=" + str(i), f)
		diverged_rng = diverged_rng or a.rng.to_dict() != b.rng.to_dict()
	check(diverged_rng, "controle positivo nao perturbou RNG do mundo", f)
	# Visible evidence is a positive control for the same comparison harness.
	a.foods.clear()
	b.foods.clear()
	b.place_food(cb.pos + Vector2.from_angle(cb.heading) * 20, "fruta")
	check(a.sense(ca) != b.sense(cb), "controle positivo sensorial inoperante", f)
	a.step()
	b.step()
	check(ca.to_dict() != cb.to_dict(), "controle positivo nao detectou divergencia", f)

func _legacy_and_save(f: Array) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experiments/p1b_legacy_fixture.json"))
	var old = World.from_dict(fixture.initial)
	check(old != null, "save v1 antigo rejeitado", f)
	if old != null:
		for i in int(fixture.ticks): old.step()
		check(JSON.stringify(old.to_dict(), "", true, true).sha256_text() == fixture.expected_sha256, "hash de mundo antigo alterado", f)
	var w = garden(382012)
	var c = w.creatures[w.pet_id]
	c.mind.spatial = trained_state()
	w.tick = 20
	c.mind.motivo = "spatial.visible"
	c.mind.spatial.scan_mask = 7
	var pre: Dictionary = w.to_dict()
	var loaded = World.from_dict(JSON.parse_string(JSON.stringify(pre, "", true, true)))
	check(loaded != null and loaded.to_dict() == pre, "roundtrip v2/visible/inspecao parcial perdeu dados", f)
	if loaded != null:
		for i in 120:
			w.step()
			loaded.step()
		check(w.to_dict() == loaded.to_dict(), "continuacao RNG v2 apos save divergiu", f)
	for mask in [-1, 131072, "0", NAN]:
		var hostile := pre.duplicate(true)
		hostile.creatures[0].mind.spatial.scan_mask = mask
		check(World.from_dict(hostile) == null, "mascara hostil aceita", f)
