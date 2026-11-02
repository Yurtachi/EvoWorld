extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Objects = preload("res://scripts/mind/object_memory.gd")
const Mind = preload("res://scripts/mind/creature_mind.gd")

func garden(seed_value: int = 106101):
	var w = World.new(seed_value, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false, "personality_enabled": true, "water_enabled": true})
	var g := Genes.new()
	g.size = 8.0
	g.speed = 30.0
	g.vision_range = 180.0
	g.vision_fov = snappedf(TAU, 0.000001)
	g.temperament = {"curiosity": 0.9, "caution": 0.8, "sociability": 0.2, "impulsivity": 0.3}
	var id: int = w.spawn_creature(Vector2(300, 300), "M2", g)
	w.pet_id = id
	w.enable_mind(id)
	var c = w.creatures[id]
	c.energy = c.max_energy * 0.9
	c.hydration = 90.0
	c.heading = 0.0
	return w

func check(value: bool, message: String, failures: Array) -> void:
	if not value: failures.append(message)

func snapshot(w) -> String:
	return JSON.stringify(w.to_dict(), "", true, true)

func run() -> Array:
	var f: Array = []
	var w = garden()
	var c = w.creatures[w.pet_id]
	var id: int = w.place_object(c.pos + Vector2(24, 0), "capsula_aversiva")
	check(id > 0 and w.place_object(Vector2(NAN, 0)) == -1 and w.place_object(c.pos, "bad") == -1, "catalogo/posicao invalida aceita", f)
	var sensed: Dictionary = w.sense(c).objects[0]
	check(sensed.size() == 4 and not sensed.has("tipo") and not sensed.has("toxicity") and not sensed.has("energy"), "sensor vazou propriedades ocultas", f)
	Objects.observe(c.mind, w.sense(c), w.tick)
	check(c.mind.objects.entries[str(id)].source == "observado" and c.mind.objects.entries[str(id)].evidence.is_empty() and c.mind.objects.types.capsula.value == 0.0, "observacao inventou evidencia", f)
	var before: float = c.energy
	check(not w.interact_object(c, id) and c.energy == before, "interacao remota alterou corpo", f)
	var count := 0
	for i in 36:
		w.step()
		if c.last_action == "investigate_object": count += 1
	check(count == 1 and c.energy < before and c.mind.objects.types.capsula.value < 0.0, "iniciativa nao produziu consequencia aversiva unica", f)
	check(c.mind.mind_log.any(func(row): return row.motivo.begins_with("mind.iniciativa")), "sem justificativa de iniciativa no log", f)
	check(c.mind.objects.entries[str(id)].source == "interagido" and not c.mind.objects.entries[str(id)].evidence.is_empty(), "contato sem evidencia/fonte", f)
	var restored = World.from_dict(JSON.parse_string(snapshot(w)))
	check(restored != null and snapshot(restored) == snapshot(w), "roundtrip v9 perdeu objetos/memoria", f)
	if restored != null:
		for i in 60:
			w.step()
			restored.step()
		check(snapshot(w) == snapshot(restored), "continuacao v9 divergiu", f)
	var saved: Dictionary = w.to_dict()
	check(World._migrate_v8(saved) == saved, "migracao v8 nao idempotente", f)
	for invalid in [NAN, "alto", true]:
		var bad := saved.duplicate(true)
		bad.creatures[0].mind.objects.entries[str(id)].confidence = invalid
		check(World.from_dict(bad) == null, "confianca hostil aceita", f)
	for hostile in [[], {}, null]:
		var badtypes := saved.duplicate(true)
		var types = badtypes.creatures[0].mind.objects.types
		if types is Dictionary and not types.is_empty():
			var category = types.keys()[0]
			types[category].value = hostile
			types[category].confidence = hostile
			check(World.from_dict(badtypes) == null, "tipo de memoria hostil aceito", f)
	var bad := saved.duplicate(true)
	bad.objects[0].tipo = "desconhecido"
	check(World.from_dict(bad) == null, "tipo de objeto hostil aceito", f)
	bad = saved.duplicate(true)
	bad.objects[0].id = c.id
	check(World.from_dict(bad) == null, "colisao de ID aceita", f)
	bad = saved.duplicate(true)
	bad.creatures[0].mind.objects.entries[str(id)].source = "observado"
	check(World.from_dict(bad) == null, "evidencia como observacao aceita", f)
	var h = garden()
	var hc = h.creatures[h.pet_id]
	var hid: int = h.place_object(hc.pos, "capsula_neutra")
	var row: Dictionary = h.sense(hc).objects[0]
	var novelty_before := Objects.novelty(hc.mind, row, h.tick)
	for i in 8:
		h.tick += 181
		check(h.interact_object(hc, hid), "aquisicao fisica falhou", f)
	var familiar := Objects.novelty(hc.mind, row, h.tick)
	check(familiar < novelty_before * 0.5 and Objects.novelty(hc.mind, row, h.tick + 600) > familiar, "habituacao/recuperacao ausente", f)
	hc.mind.memory_enabled = false
	check(Objects.novelty(hc.mind, row, h.tick) == 1.0, "ablacao recuperou familiaridade", f)
	hc.energy = hc.max_energy * 0.2
	check(hc.mind.decide(hc, h.tick, h.sense(hc)) == "comer", "curiosidade venceu fome critica", f)
	hc.energy = hc.max_energy * 0.9
	hc.hydration = 20.0
	check(hc.mind.decide(hc, h.tick, h.sense(hc)) == "beber", "curiosidade venceu sede critica", f)
	# Expiration bounds both instance and consolidated category knowledge.
	hc.mind.memory_enabled = true
	Objects.observe(hc.mind, {}, h.tick + Objects.TTL + 1)
	check(hc.mind.objects.entries.is_empty() and hc.mind.objects.types.is_empty(), "memoria nao esquece", f)
	for i in 70:
		Objects.observe(hc.mind, {"objects": [{"id": i + 100, "category": "pedra"}]}, h.tick)
	check(hc.mind.objects.entries.size() == Objects.LIMIT, "memoria excedeu limite", f)
	var legacy = garden()
	var old: Dictionary = legacy.to_dict()
	old.save_version = 8
	old.erase("objects")
	old.erase("object_catalog_version")
	var original := JSON.stringify(old)
	var migrated = World.from_dict(old)
	check(migrated != null and migrated.objects.is_empty() and migrated.creatures[migrated.pet_id].mind.objects.is_empty() and original == JSON.stringify(old), "v8 inventou memoria/alterou entrada", f)
	check(World.new_world(106102).mind_enabled_ids.size() == 1, "mente padrao alem do pet", f)
	var timeout_world = garden()
	var tc = timeout_world.creatures[timeout_world.pet_id]
	var tid: int = timeout_world.place_object(tc.pos + Vector2(24, 0))
	Objects.observe(tc.mind, timeout_world.sense(tc), 0)
	Objects.state(tc.mind).target = tid
	tc.mind.set_goal("investigar_objeto", 0, "mind.iniciativa.novidade")
	timeout_world.tick = 81
	check(tc.mind.decide(tc, 81, timeout_world.sense(tc)) != "investigar_objeto" and tc.mind.motivo == "mind.timeout" and int(tc.mind.objects.entries[str(tid)].retry_tick) > 81, "investigacao sem timeout/retry limitado", f)
	var neutral_world = garden()
	var neutral = neutral_world.creatures[neutral_world.pet_id]
	neutral_world.place_object(neutral.pos + Vector2(24, 0))
	var adverse_world = garden()
	var adverse = adverse_world.creatures[adverse_world.pet_id]
	adverse_world.place_object(adverse.pos + Vector2(24, 0), "capsula_aversiva")
	check(neutral_world.sense(neutral).objects == adverse_world.sense(adverse).objects, "aparencia revela consequencia antes do contato", f)
	# Separate histories, identical current state: returning to a new instance.
	for target_world in [neutral_world, adverse_world]:
		var target_c = target_world.creatures[target_world.pet_id]
		target_world.objects[0].pos = target_c.pos
		for i in 8:
			target_world.tick += 181
			target_c.energy = target_c.max_energy * 0.9
			target_c.hydration = 90.0
			target_world.interact_object(target_c, int(target_world.objects[0].id))
		target_world.objects[0].pos = Vector2(1000, 600)
		target_world.place_object(target_c.pos + Vector2(24, 0))
		target_world.tick += 600
		target_c.energy = target_c.max_energy * 0.9
		target_c.hydration = 90.0
		target_c.mind.affect = preload("res://scripts/mind/affect.gd").new()
	check(neutral.mind.decide(neutral, neutral_world.tick, neutral_world.sense(neutral)) == "investigar_objeto" and adverse.mind.decide(adverse, adverse_world.tick, adverse_world.sense(adverse)) != "investigar_objeto", "historias diferentes nao mudaram escolha", f)
	for target_c in [neutral, adverse]:
		target_c.mind.memory_enabled = false
		target_c.mind.objetivo_atual = ""
	check(neutral.mind.decide(neutral, neutral_world.tick, neutral_world.sense(neutral)) == "investigar_objeto" and adverse.mind.decide(adverse, adverse_world.tick, adverse_world.sense(adverse)) == "investigar_objeto", "ablacao nao removeu divergencia de memoria", f)
	return f
