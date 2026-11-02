extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Memory = preload("res://scripts/spatial/spatial_memory.gd")
const Policy = preload("res://scripts/spatial/spatial_policy.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func garden(seed_value: int = 271010):
	var w = World.new(seed_value, {"size": Vector2(900, 600), "creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false, "personality_enabled": true})
	var g := Genes.new()
	g.size = 8.0
	g.speed = 55.0
	g.vision_range = 70.0
	g.vision_fov = snappedf(PI * 1.5, 0.000001)
	g.metabolism = 0.5
	g.temperament = {"curiosity": 0.5, "caution": 0.5, "sociability": 0.5, "impulsivity": 0.5}
	w.pet_id = w.spawn_creature(Vector2(100, 100), "P1", g)
	w.enable_mind(w.pet_id)
	w.creatures[w.pet_id].enable_spatial_memory()
	return w

func run() -> Array:
	var f: Array = []
	_static_boundary(f)
	_sensors_and_learning(f)
	_persistence(f)
	return f

func _static_boundary(f: Array) -> void:
	var forbidden := RegEx.new()
	forbidden.compile("(?:world|self)\\s*(?:\\.\\s*(?:foods|waters|feeders|objects)\\b|\\[\\s*[\"'](?:foods|waters|feeders|objects)[\"'])")
	for folder in ["res://scripts/mind", "res://scripts/spatial", "res://scripts/behavior"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				check(forbidden.search(FileAccess.get_file_as_string(folder.path_join(file))) == null, "verdade do mundo acessada em " + file, f)
	check(forbidden.search("world.foods") != null and forbidden.search("world[\"feeders\"]") != null, "detector estatico inoperante", f)
	var source := FileAccess.get_file_as_string("res://scripts/world/sim_world.gd")
	for name in ["_mind_action", "_spatial_seek", "_personality_seek_food", "_seek_water"]:
		var body := source.get_slice("func " + name + "(", 1).get_slice("\nfunc ", 0).get_slice("\nstatic func ", 0)
		check(not body.is_empty() and forbidden.search(body) == null, "vazamento na decisao " + name, f)

func _sensors_and_learning(f: Array) -> void:
	var w = garden()
	var c = w.creatures[w.pet_id]
	c.heading = 0.0
	w.place_food(Vector2(200, 100), "fruta")
	c.mind.decide(c, w.tick, w.sense(c))
	check(c.spatial_snapshot().lugares.is_empty(), "comida fora do alcance virou memoria", f)
	w.foods.clear()
	w.place_food(Vector2(70, 100), "fruta")
	c.mind.decide(c, w.tick, w.sense(c))
	check(c.spatial_snapshot().lugares.is_empty(), "comida atras do FOV virou memoria", f)
	w.foods.clear()
	w.place_obstacle(Vector2(125, 100), 10.0)
	w.place_food(Vector2(150, 100), "fruta")
	c.mind.decide(c, w.tick, w.sense(c))
	check(c.spatial_snapshot().lugares.is_empty(), "comida ocluida virou memoria", f)
	w.obstacles.clear()
	c.mind.decide(c, w.tick, w.sense(c))
	check(c.spatial_snapshot().lugares.size() == 1, "observacao real nao gravada", f)
	var initial_visits: int = c.mind.spatial.lugares[0].visitas
	for i in 40: c.mind.decide(c, w.tick, w.sense(c))
	check(c.mind.spatial.lugares[0].visitas == initial_visits, "observacao estacionaria inflou visitas", f)
	w.foods.clear()
	c.energy = 35.0
	var target := Vector2(100, 100)
	for i in 8:
		w.tick += 1
		c.energy = 35.0
		w._eat(c, w.place_food(target, "fruta"))
	var learned: Dictionary = Memory.find(c.mind.spatial, Memory.key_for("comida", target, 35.0))
	check(not learned.is_empty() and learned.fonte == "interagido" and learned.ganho_medio > 20.0, "ingestao real sem fonte/ganho", f)
	c.pos = Vector2(650, 400)
	c.energy = 35.0
	var body_before := [c.pos, c.energy, c.hydration]
	var d := Policy.choose(c, c.mind.spatial, w.sense(c), "comida", w.tick, w.size)
	check(not d.scan and d.target == target, "nao recuperou lugar sem comida visivel", f)
	check(body_before == [c.pos, c.energy, c.hydration], "cognicao escreveu corpo", f)
	# Relocating a hidden feeder cannot alter memory, choice, RNG or movement.
	w.place_feeder(Vector2(100, 100), {"estoque": 0})
	var other = World.from_dict(w.to_dict())
	check(other != null, "clone de teste nao carregou", f)
	if other != null:
		other.feeders[0].pos = Vector2(800, 500)
		for i in 10:
			w.step()
			other.step()
		check(c.to_dict() == other.creatures[other.pet_id].to_dict(), "alimentador movido fora da visao alterou decisao", f)
	# Three completed inspections, separated by cooldowns, revise the hypothesis.
	for visit in 3:
		w.tick += 600
		c.pos = target
		c.energy = 35.0
		c.mind.spatial.objetivo_atual = ""
		for i in 18: w.step()
	check(int(learned.falhas) >= 3 and float(learned.expectativa) < 0.25, "falhas reais nao revisaram expectativa", f)
	check(Memory.best(c.mind.spatial, "comida", target, w.tick + 2000).get("id", "") != learned.id, "lugar abandonado apos falhas repetidas voltou como alvo", f)
	var confidence: float = learned.confianca
	Memory.maintain(c.mind.spatial, w.tick + 6000)
	check(float(learned.confianca) < confidence, "confianca nao decai", f)
	var copy: Dictionary = c.spatial_snapshot()
	copy.lugares.clear()
	check(not c.mind.spatial.lugares.is_empty(), "snapshot compartilha memoria mutavel", f)
	var ablated = garden(271012)
	var off = ablated.creatures[ablated.pet_id]
	off.mind.spatial.enabled = false
	off.energy = 35.0
	ablated._eat(off, ablated.place_food(off.pos, "fruta"))
	check(off.energy > 35.0 and off.mind.spatial.lugares.is_empty(), "ablacao alterou ingestao ou codificou memoria", f)
	var bounded := Memory.empty(35.0)
	for i in 90: Memory.evidence(bounded, "comida", Vector2(i * 36, 10), i, true)
	check(bounded.lugares.size() == Memory.LIMIT, "memoria sem limite", f)
	Memory.maintain(bounded, Memory.TTL + 100)
	check(bounded.lugares.is_empty(), "esquecimento nao removeu lugares antigos", f)

func _persistence(f: Array) -> void:
	var w = garden(271011)
	var c = w.creatures[w.pet_id]
	c.energy = 35.0
	w._eat(c, w.place_food(c.pos, "fruta"))
	var original: Dictionary = w.to_dict()
	var loaded = World.from_dict(JSON.parse_string(JSON.stringify(original, "", true, true)))
	check(loaded != null and loaded.to_dict() == original, "roundtrip v16 perdeu estado espacial", f)
	if loaded != null:
		for i in 40:
			w.step()
			loaded.step()
		check(w.to_dict() == loaded.to_dict(), "continuacao divergiu apos save/load", f)
	var store := Store.new("user://p1_unit_" + str(OS.get_process_id()))
	var saved := store.save_world(w)
	var disk := store.load_world()
	check(saved.ok and disk.ok and disk.world.to_dict() == w.to_dict(), "save disco perdeu memoria", f)
	for name in ["world.json", "world.json.bak"]: DirAccess.remove_absolute(store.directory.path_join(name))
	DirAccess.remove_absolute(store.directory)
	for field in ["pos", "expectativa", "confianca", "visitas", "alpha", "fonte", "ultimo_tick", "id"]:
		for bad in [NAN, INF, null, [], {}, true]:
			var hostile := original.duplicate(true)
			hostile.creatures[0].mind.spatial.lugares[0][field] = bad
			check(World.from_dict(hostile) == null, "save hostil aceitou " + field, f)
	for mutation in ["duplicate", "outside", "size", "future"]:
		var hostile := original.duplicate(true)
		var s: Dictionary = hostile.creatures[0].mind.spatial
		match mutation:
			"duplicate": s.lugares.append(s.lugares[0].duplicate(true))
			"outside": s.lugares[0].pos = [901, 100]
			"size": s.cell_size = 0
			"future": hostile.save_version = 15
		check(World.from_dict(hostile) == null, "save hostil aceitou " + mutation, f)
	var legacy := original.duplicate(true)
	legacy.save_version = 15
	legacy.creatures[0].mind.erase("spatial")
	var untouched := legacy.duplicate(true)
	var migrated = World.from_dict(legacy)
	check(migrated != null and legacy == untouched and migrated.creatures[migrated.pet_id].mind.spatial.is_empty(), "migracao v15 alterou politica/dados antigos", f)
	check(World._migrate_v15(World._migrate_v15(legacy)) == World._migrate_v15(legacy), "migracao v15 nao idempotente", f)
