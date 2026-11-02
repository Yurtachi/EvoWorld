extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Feeder = preload("res://scripts/environment/feeder.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Robust = preload("res://tests/unit/test_save_robustez.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func snapshot(w) -> String:
	return JSON.stringify(w.to_dict(), "", true, true)

func empty_world() -> World:
	return World.new(160010, {"creature_count": 0, "food_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": false})

func actor(w, pos: Vector2):
	var g := Genes.new()
	g.vision_range = 100.0
	g.vision_fov = snappedf(TAU, 0.000001)
	return w.creatures[w.spawn_creature(pos, "Pet", g)]

func run() -> Array:
	var f: Array = []
	_pet_defaults(f)
	_feeder_schedule(f)
	_physical_ingestion(f)
	_modes_and_determinism(f)
	_migrations_and_golden(f)
	_hostile_records(f)
	return f

func _pet_defaults(f: Array) -> void:
	var w := World.new_pet_world(160002, "  Pipoca  ")
	check(w.creatures.size() == 1 and w.pet_id > 0 and w.creatures[w.pet_id].name == "Pipoca", "pet adotado unico/nome incorreto", f)
	check(w.creatures[w.pet_id].mind != null and w.mind_enabled_ids == [w.pet_id], "mente avancada do pet nao ativa", f)
	check(not w.reproduction_enabled and w.feeders.is_empty(), "padrao criou reproducao/alimentador implicito", f)
	var state := w.pet_snapshot()
	state.mind.clear()
	check(not w.pet_snapshot().mind.is_empty(), "snapshot expos estado mutavel do pet", f)
	var start := Time.get_ticks_usec()
	var births := 0
	for i in 5000:
		w.step()
		if w.genealogy.records.size() != 1 or w.creatures.size() > 1: births += 1
	check(births == 0 and w.genealogy.records.size() == 1, "padrao produziu nascimento em 5000 ticks", f)
	check(w.creatures.size() == 1, "pet padrao nao sobreviveu 5000 ticks (160002)", f)
	print("P0 default ticks=5000 alive=%d records=%d ms/tick=%.4f" % [w.creatures.size(), w.genealogy.records.size(), (Time.get_ticks_usec() - start) / 5000000.0])
	for seed_value in [160001, 160003, 7421]:
		var other := World.new_pet_world(seed_value, "Pet")
		start = Time.get_ticks_usec()
		var always_single := true
		for i in 5000:
			other.step()
			if other.creatures.size() != 1 or other.genealogy.records.size() != 1: always_single = false
		check(always_single, "padrao nao manteve pet unico por 5000 ticks seed=%d" % seed_value, f)
		print("P0 default seed=%d ticks=5000 alive=%d ms/tick=%.4f" % [seed_value, other.creatures.size(), (Time.get_ticks_usec() - start) / 5000000.0])
	# Physical care, without replacing bodies, rewriting energy or suppressing death.
	var cared := World.new_pet_world(7421, "Cuidado")
	cared.set_feeding_mode("manual")
	for i in 5000:
		if cared.creatures.has(cared.pet_id) and i % 50 == 0:
			var pet = cared.creatures[cared.pet_id]
			# Place resources in sight but beyond ingestion reach: approaching is required.
			cared.oferecer_alimento(pet.id, "fruta")
			if cared.waters.size() < 64:
				var center: Vector2 = (pet.pos + Vector2(30, 0)).clamp(Vector2(20, 20), cared.size - Vector2(20, 20))
				cared.place_water(center, 15.0)
		cared.step()
	check(cared.creatures.size() == 1 and cared.genealogy.records.size() == 1, "cuidado fisico nao manteve pet unico por 5000 ticks", f)
	check(cared.events.any(func(e): return e.type == "eat"), "cuidado fisico nao gerou refeicao real", f)
	var eco := World.new_ecosystem_world(160004)
	check(eco.creatures.size() == 12 and eco.reproduction_enabled and eco.food_regrow, "preset ecossistema nao preservou 12/reproducao", f)
	w.set_reproduction(true)
	check(w.reproduction_enabled, "API nao ligou reproducao", f)
	w.set_reproduction(false)
	check(not w.reproduction_enabled, "API nao desligou reproducao", f)
	check(w.spawn_creature(Vector2(200, 200), "Visitante") > 0, "introducao posterior bloqueada", f)

func _feeder_schedule(f: Array) -> void:
	var w := empty_world()
	w.set_feeding_mode("feeder")
	var fid := w.place_feeder(Vector2(100, 100), {"tipo_alimento": "semente", "estoque": 3, "intervalo_ticks": 3, "capacidade_local": 2, "raio": 20.0})
	check(fid > 0, "alimentador valido recusado", f)
	if fid < 0: return
	for i in 2: w.step()
	check(w.foods.is_empty() and w.feeders[0].estoque == 3, "alimentador ignorou intervalo inicial", f)
	w.step()
	check(w.foods.size() == 1 and w.feeders[0].estoque == 2 and w.foods[0].food_type == "semente", "primeira reposicao/estoque/tipo incorretos", f)
	for i in 6: w.step()
	check(w.foods.size() == 2 and w.feeders[0].estoque == 1, "alimentador excedeu capacidade local", f)
	w.foods.clear()
	for i in 3: w.step()
	check(w.foods.size() == 1 and w.feeders[0].estoque == 0, "estoque finito nao esgotou", f)
	for i in 12: w.step()
	check(w.foods.size() == 1, "alimentador vazio produziu comida", f)
	check(w.feeder_refill(fid, 2) and w.feeder_set_enabled(fid, false), "reabastecer/desativar falhou", f)
	for i in 6: w.step()
	check(w.foods.size() == 1 and w.feeders[0].estoque == 2, "alimentador desligado produziu comida", f)
	check(w.feeder_set_enabled(fid, true), "ativacao falhou", f)
	w.step()
	check(w.foods.size() == 2 and w.feeders[0].estoque == 1, "alimentador reativado nao repoe", f)
	for n in [-1, 0, NAN, true, "2", 1.5, Feeder.MAX_STOCK + 1]:
		check(not w.feeder_refill(fid, n), "reabastecimento hostil aceito: %s" % str(n), f)
	check(not w.feeder_refill(-1, 1) and not w.feeder_set_enabled(-1, true), "alimentador inexistente aceito", f)
	# Food of every type counts towards the local cap; distant food does not.
	w.foods.clear()
	w.place_food(Vector2(105, 100), "folha")
	w.place_food(Vector2(110, 100), "fruta")
	w.place_food(Vector2(300, 300), "fruta")
	for i in 3: w.step()
	check(w.foods.size() == 3 and w.feeders[0].estoque == 1, "capacidade ignorou outros tipos de alimento", f)
	w.foods.remove_at(0)
	for i in 3: w.step()
	check(w.foods.size() == 3 and w.feeders[0].estoque == 0, "comida distante consumiu capacidade local", f)
	var full := empty_world()
	full.food_capacity = 0
	full.set_feeding_mode("feeder")
	full.place_feeder(Vector2(100, 100), {"estoque": 3, "intervalo_ticks": 1})
	full.step()
	check(full.foods.is_empty() and full.feeders[0].estoque == 3, "falha de colocacao consumiu estoque", f)

func _physical_ingestion(f: Array) -> void:
	var w := empty_world()
	var c = actor(w, Vector2(100, 100))
	c.energy = 20.0
	w.set_feeding_mode("feeder")
	w.place_feeder(Vector2(400, 100), {"estoque": 2, "intervalo_ticks": 1})
	var before: float = c.energy
	# Execute the exact production primitive, isolated from metabolism and motion.
	w.tick = 1
	Feeder.step(w, w.feeders[0])
	check(c.energy == before and w.foods.size() == 1, "alimentador alterou energia diretamente", f)
	var food_id: int = w.foods[0].id
	check(w.sense(c).foods.is_empty() and not w.sense(c).has("feeders"), "alimentador/comida distante vazou aos sensores", f)
	w._eat(c, food_id)
	check(c.energy == before and w.foods.size() == 1, "refeicao fora do alcance deu energia", f)
	c.pos = Vector2(400, 100) - Vector2(Obs.reach(c) + 1.0, 0)
	w._eat(c, food_id)
	check(c.energy == before and w.foods.size() == 1, "ingestao excedeu alcance corporal", f)
	c.pos += Vector2(2.0, 0)
	w._eat(c, food_id)
	check(c.energy > before and w.foods.is_empty(), "aproximacao fisica nao permitiu ingestao", f)
	# Occlusion blocks food perception and ingestion even within reach.
	c.energy = 20.0
	c.pos = Vector2(100, 100)
	w.obstacles = [{"pos": Vector2(104, 100), "radius": 1.0}]
	food_id = w.place_food(Vector2(109, 100), "fruta")
	check(food_id > 0, "fixture comida ocluida invalida", f)
	w._eat(c, food_id)
	check(c.energy == 20.0 and w.foods.size() == 1 and w.sense(c).foods.is_empty(), "comida atravessou obstaculo", f)
	# World ticks may spend energy, but replenishment cannot supply remote energy.
	var a := empty_world()
	var b := empty_world()
	var ca = actor(a, Vector2(100, 100))
	var cb = actor(b, Vector2(100, 100))
	a.set_feeding_mode("feeder")
	b.set_feeding_mode("feeder")
	a.place_feeder(Vector2(900, 600), {"estoque": 10, "intervalo_ticks": 1})
	for i in 10:
		a.step()
		b.step()
		check(ca.energy == cb.energy and ca.pos == cb.pos, "reposicao remota mudou corpo/politica sem percepcao", f)
	var ecology := empty_world()
	var manual := empty_world()
	var ec = actor(ecology, Vector2(100, 100))
	var mc = actor(manual, Vector2(100, 100))
	ecology.set_feeding_mode("ecosystem")
	ecology.food_regrow_interval = 1
	ecology.step()
	manual.step()
	check(ecology.foods.size() > 0 and ec.energy == mc.energy, "reposicao ecologica concedeu energia direta", f)

func _modes_and_determinism(f: Array) -> void:
	var w := empty_world()
	w.place_feeder(Vector2(100, 100), {"estoque": 10, "intervalo_ticks": 2})
	check(not w.set_feeding_mode("invalido"), "modo invalido aceito", f)
	w.set_feeding_mode("manual")
	for i in 4: w.step()
	check(w.foods.is_empty() and not w.food_regrow, "modo manual repoe automaticamente", f)
	w.set_feeding_mode("ecosystem")
	w.food_regrow_interval = 1
	w.step()
	check(not w.foods.is_empty() and w.feeders[0].estoque == 10, "ecossistema nao repoe ou acionou alimentador", f)
	w.set_feeding_mode("feeder")
	check(not w.food_regrow, "modo alimentador manteve reposicao ecologica", f)
	var restored := World.from_dict(JSON.parse_string(snapshot(w)))
	check(restored != null and snapshot(restored) == snapshot(w), "roundtrip v15 perdeu alimentador/modo", f)
	if restored == null: return
	var store := Store.new("user://p0_unit_" + str(OS.get_process_id()))
	var saved := store.save_world(w)
	var loaded := store.load_world()
	check(saved.ok and loaded.ok and snapshot(loaded.world) == snapshot(w), "checkpoint v15 em disco perdeu alimentador", f)
	DirAccess.remove_absolute(store.directory.path_join("world.json"))
	DirAccess.remove_absolute(store.directory)
	for i in 100:
		if i == 20:
			w.feeder_refill(w.feeders[0].id, 2)
			restored.feeder_refill(restored.feeders[0].id, 2)
		w.step()
		restored.step()
	check(snapshot(w) == snapshot(restored), "determinismo apos save/reabastecer divergiu", f)
	var same := World.new_pet_world(160002, "Pipoca")
	var replay := World.new_pet_world(160002, "Pipoca")
	for i in 300:
		same.step()
		replay.step()
	check(snapshot(same) == snapshot(replay), "pet com mesma seed divergiu", f)

func _migrations_and_golden(f: Array) -> void:
	# Captured from efb7810 in a separate git archive, before P0 changes.
	var golden := ["bbd1465f14a4555a8751df83b1568188faeb1f9633c1b87de461df06a415228f", "75c8cc5c0109cc5668401e8e8b4255dc53751c56d4d9f86068cdedc60d271073"]
	for mental in [false, true]:
		var old := World.new(160021, {"creature_count": 6, "food_count": 30, "obstacle_count": 3,
			"water_count": 3, "water_enabled": true, "personality_enabled": true, "mind_all": mental, "reproduction_enabled": true})
		var v14 := old.to_dict()
		v14.save_version = 14
		var untouched := JSON.stringify(v14, "", true, true)
		var migrated := World.from_dict(v14)
		check(migrated != null, "v14 valido recusado", f)
		check(untouched == JSON.stringify(v14, "", true, true), "migracao modificou entrada", f)
		check(World._migrate_v14(World._migrate_v14(v14)) == World._migrate_v14(v14), "migracao v14 nao idempotente", f)
		if migrated == null: continue
		check(migrated.creatures.size() == 6 and migrated.reproduction_enabled and migrated.feeders.is_empty(), "migracao apagou criaturas/alterou regras", f)
		for i in 600:
			old.step()
			migrated.step()
		check(snapshot(old) == snapshot(migrated), "migracao alterou trajetoria v14", f)
		var d := migrated.to_dict()
		d.save_version = 14
		check(JSON.stringify(d, "", true, true).sha256_text() == golden[int(mental)], "golden pre-P0 mudou (mente=%s)" % mental, f)
	for version in range(1, 15):
		var legacy: Dictionary
		if version < 7:
			legacy = Robust.new()._fixture(version)
		else:
			legacy = World.new(160022, {"creature_count": 2}).to_dict()
			legacy.save_version = version
			if version == 7:
				legacy.config.erase("mind_all")
				legacy.config.erase("mind_enabled_ids")
		var loaded := World.from_dict(legacy)
		check(loaded != null, "migracao v%d falhou" % version, f)
		if loaded == null: continue
		var stable := loaded.to_dict()
		var twice := World.from_dict(stable)
		check(twice != null and snapshot(twice) == snapshot(loaded), "migracao v%d nao estabilizou em v15" % version, f)
		check(stable.save_version == 15 and loaded.creatures.size() == legacy.creatures.size(), "migracao v%d mudou populacao" % version, f)
		legacy.feeders = []
		check(World.from_dict(legacy) == null, "schema futuro aceito em v%d" % version, f)

func _hostile_records(f: Array) -> void:
	var w := empty_world()
	w.set_feeding_mode("feeder")
	w.place_feeder(Vector2(100, 100), {"estoque": 3})
	var base := w.to_dict()
	for key in ["id", "pos", "tipo_alimento", "estoque", "intervalo_ticks", "capacidade_local", "raio", "enabled", "last_tick"]:
		for bad_value in [null, NAN, INF, "bad", [], {}, true]:
			if key == "enabled" and bad_value is bool: continue
			var bad := base.duplicate(true)
			bad.feeders[0][key] = bad_value
			check(World.from_dict(bad) == null, "campo hostil aceito: " + key + "=" + str(bad_value), f)
	for cfg in [{"estoque": -1}, {"estoque": Feeder.MAX_STOCK + 1}, {"intervalo_ticks": 0}, {"intervalo_ticks": Feeder.MAX_INTERVAL + 1}, {"capacidade_local": 0}, {"capacidade_local": 10001}, {"raio": 4}, {"raio": 513}, {"enabled": 1}, {"extra": 1}]:
		check(w.place_feeder(Vector2(200, 200), cfg) == -1, "config hostil de colocacao aceita: " + str(cfg), f)
		var bad := base.duplicate(true)
		bad.feeders[0].merge(cfg, true)
		check(World.from_dict(bad) == null, "config hostil de save aceita: " + str(cfg), f)
	for value in [0, "ecosystem", "invalid", [], true]:
		var bad := base.duplicate(true)
		bad.config.feeding_mode = value
		check(World.from_dict(bad) == null, "modo/tipo inconsistente aceito", f)
	var extra := base.duplicate(true)
	extra.feeders.append(extra.feeders[0].duplicate(true))
	check(World.from_dict(extra) == null, "IDs de alimentadores duplicados aceitos", f)
	extra = base.duplicate(true)
	extra.feeders.resize(Feeder.LIMIT + 1)
	check(World.from_dict(extra) == null, "limite de alimentadores ignorado", f)
	for replacement in [{"last_tick": -1}, {"last_tick": 1}, {"id": base.next_id}, {"pos": [-1, 10]}, {"pos": [NAN, 10]}]:
		var bad := base.duplicate(true)
		bad.feeders[0].merge(replacement, true)
		check(World.from_dict(bad) == null, "limite/geometria/tempo de alimentador ignorado", f)
	check(w.place_feeder(Vector2(NAN, 20)) == -1 and w.place_feeder(Vector2(-1, 20)) == -1, "geometria hostil aceita por API", f)
	var bounded := empty_world()
	for i in Feeder.LIMIT: check(bounded.place_feeder(Vector2(100, 100)) > 0, "limite legal de alimentador recusado", f)
	check(bounded.place_feeder(Vector2(100, 100)) == -1, "API ultrapassou limite de alimentadores", f)
	# Identity namespace includes living/dead creatures, genomes, devices and art.
	var c = actor(w, Vector2(300, 300))
	w.pet_id = c.id
	var dead = actor(w, Vector2(500, 500))
	dead.alive = false
	w.step()
	w.place_food(Vector2(200, 200))
	w.place_water(Vector2(250, 200), 20.0)
	w.place_object(Vector2(270, 200))
	w.place_book(Vector2(290, 200), "guia_capsulas")
	var device := w.place_terminal(c.pos)
	var board := w.place_board(c.pos + Vector2(10, 0))
	w.enable_mind(c.id)
	w.demonstrar_forma(board, "linha")
	w.terminal_offer_manual(c, device, "livro_desenho")
	for i in 8:
		w.tick += 1
		w.terminal_start(c, device, "DESENHAR LINHA")
		w.terminal_step(c, device)
	base = w.to_dict()
	check(not w.gallery.is_empty() and World.from_dict(base) != null, "fixture global de IDs invalida", f)
	var all_ids: Array = []
	for record in base.genealogy: all_ids.append_array([record.creature_id, record.genome.id])
	for collection in [base.foods, base.waters, base.objects, base.library.books, base.boards, base.gallery, base.terminals]:
		for row in collection: all_ids.append(row.id)
	for used_id in all_ids:
		var bad := base.duplicate(true)
		bad.feeders[0].id = used_id
		check(World.from_dict(bad) == null, "colisao global de ID aceita: %s" % used_id, f)
	print("P0 hostile feeder identities=%d" % all_ids.size())
