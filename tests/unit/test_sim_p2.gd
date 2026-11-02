extends RefCounted
## P2 unit tests: typed obstacles, creature local map, A* planner,
## telepathy boundary, persistence v17, and hostile data rejection.
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Memory = preload("res://scripts/spatial/spatial_memory.gd")
const Policy = preload("res://scripts/spatial/spatial_policy.gd")
const Planner = preload("res://scripts/spatial/spatial_planner.gd")
const ObstacleCatalog = preload("res://scripts/environment/obstacle_catalog.gd")
const Store = preload("res://scripts/persistence/save_store.gd")
const Bug = preload("res://scripts/behavior/bug_policy.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func garden(seed_val: int = 592010):
	var w = World.new(seed_val, {
		"size": Vector2(900, 600), "creature_count": 0, "food_count": 0,
		"water_count": 0, "obstacle_count": 0, "food_regrow": false,
		"reproduction_enabled": false, "personality_enabled": true
	})
	var g := Genes.new()
	g.size = 8.0
	g.speed = 55.0
	g.vision_range = 70.0
	g.vision_fov = snappedf(PI * 1.5, 0.000001)
	g.metabolism = 0.5
	g.temperament = {"curiosity": 0.5, "caution": 0.5, "sociability": 0.5, "impulsivity": 0.5}
	w.pet_id = w.spawn_creature(Vector2(120, 300), "PetP2", g)
	w.enable_mind(w.pet_id)
	w.creatures[w.pet_id].enable_spatial_memory()
	return w

func run() -> Array:
	var f: Array = []
	_test_typed_obstacles(f)
	_test_local_map_and_memory(f)
	_test_planner_and_replan(f)
	_test_telepathy_boundary(f)
	_test_persistence_v17(f)
	_test_performance(f)
	return f

func _test_typed_obstacles(f: Array) -> void:
	var w = garden(592011)
	check(ObstacleCatalog.valid_type("parede"), "tipo parede invalido no catalogo", f)
	check(ObstacleCatalog.valid_type("cerca"), "tipo cerca invalido no catalogo", f)
	check(ObstacleCatalog.valid_type("pedra"), "tipo pedra invalido no catalogo", f)
	check(not ObstacleCatalog.valid_type("invalido"), "tipo inexistente aceito", f)
	
	# Typed placement
	w.place_obstacle(Vector2(300, 200), "parede", 24.0)
	w.place_obstacle(Vector2(300, 300), "cerca", 18.0)
	w.place_obstacle(Vector2(300, 400), 20.0) # Legacy signature
	check(w.obstacles.size() == 3, "obstaculos nao inseridos", f)
	check(w.obstacles[0].tipo == "parede" and w.obstacles[0].modificavel == false and w.obstacles[0].material == "alvenaria" and w.obstacles[0].dureza == 10.0, "propriedades parede incorretas", f)
	check(w.obstacles[1].tipo == "cerca" and w.obstacles[1].material == "madeira" and w.obstacles[1].dureza == 3.0, "propriedades cerca incorretas", f)
	check(w.obstacles[2].tipo == "pedra" and w.obstacles[2].material == "rocha", "legado nao recebeu defaults pedra", f)
	
	# Occlusion and locomotion block
	var c = w.creatures[w.pet_id]
	c.pos = Vector2(250, 200)
	c.heading = 0.0
	w.place_food(Vector2(350, 200), "fruta")
	var sensed := w.sense(c)
	check(sensed["foods"].is_empty(), "comida atras da parede nao foi ocluida", f)
	check(not sensed["obstacles"].is_empty(), "parede visivel nao percebida em sensores", f)
	check(sensed["obstacles"][0].has("tipo") and sensed["obstacles"][0].has("dureza"), "sensores nao receberam obstaculos tipados", f)
	
	# Movement block
	var init_pos: Vector2 = c.pos
	for i in 10: w.step()
	check(c.pos.distance_to(Vector2(300, 200)) >= 24.0 + c.genome.size - 0.001, "criatura atravessou parede", f)

func _test_local_map_and_memory(f: Array) -> void:
	var w = garden(592012)
	var c = w.creatures[w.pet_id]
	c.pos = Vector2(100, 100)
	c.heading = 0.0
	
	# Initially local map is empty
	var s: Dictionary = c.mind.spatial
	check(s.version == 3, "memoria espacial nao e v3", f)
	check(s.mapa.is_empty(), "mapa local inicial nao vazio", f)
	
	# Place visible obstacle
	w.place_obstacle(Vector2(140, 100), "parede", 15.0)
	c.mind.decide(c, w.tick, w.sense(c))
	
	# Map must have recorded blocked cells
	check(not s.mapa.is_empty(), "mapa nao gravou celulas", f)
	var obs_cell := Planner.pos_to_cell(Vector2(140, 100), float(s.cell_size))
	var k := "%d:%d" % [obs_cell.x, obs_cell.y]
	check(s.mapa.has(k) and s.mapa[k].estado == "bloqueada", "celula de obstaculo visivel nao marcada como bloqueada", f)
	
	# Collision creates block memory and invalidates plan
	c.heading = 0.0
	var before_blocks: int = s.bloqueios.size()
	c.mind.consequence(c, w.tick, "blocked", 1.0)
	check(s.bloqueios.size() > before_blocks, "colisao nao gravou bloqueio", f)
	check(not s.bloqueios.is_empty() and s.bloqueios[0].tentativas >= 1, "tentativas de bloqueio zeradas", f)
	
	# Route success recording
	s.current_journey = [[1, 1], [2, 1], [3, 1]]
	Memory.record_route_success(s, "comida", w.tick)
	check(s.rotas.size() == 1, "rota bem sucedida nao gravada", f)
	check(s.rotas[0].usos == 1 and s.rotas[0].sucessos == 1, "estatisticas de rota nao inicializadas", f)
	
	# Reinforce route
	s.current_journey = [[1, 1], [2, 1], [3, 1]]
	Memory.record_route_success(s, "comida", w.tick + 10)
	check(s.rotas.size() == 1 and s.rotas[0].usos == 2 and s.rotas[0].peso > 1.0, "rota nao reforçada por uso", f)
	
	# Route decay and maintain
	Memory.maintain(s, w.tick + 37000)
	check(s.rotas.is_empty(), "esquecimento de rotas antigas falhou", f)

func _test_planner_and_replan(f: Array) -> void:
	var w = garden(592013)
	var c = w.creatures[w.pet_id]
	var s: Dictionary = c.mind.spatial
	
	# Test optimistic A* (unknown space is free)
	var start := Vector2(100, 100)
	var goal := Vector2(300, 100)
	var path := Planner.plan_path(start, goal, s, w.size)
	check(not path.is_empty() and path.back() == goal, "A* otimista falhou em espaco desconhecido", f)
	
	# Now block the direct path in local map
	var mid_cell := Planner.pos_to_cell(Vector2(200, 100), float(s.cell_size))
	s.mapa["%d:%d" % [mid_cell.x, mid_cell.y]] = {"pos": [mid_cell.x, mid_cell.y], "estado": "bloqueada", "confianca": 1.0, "tick": 1}
	var detour_path := Planner.plan_path(start, goal, s, w.size)
	check(not detour_path.is_empty(), "A* nao encontrou desvio", f)
	var intersects_blocked := false
	for pt in detour_path:
		if Planner.pos_to_cell(pt, float(s.cell_size)) == mid_cell:
			intersects_blocked = true
	check(not intersects_blocked, "A* passou por celula bloqueada conhecida", f)
	
	# Test preference for working routes
	s.rotas = [{
		"id": "rota_1", "origem": [mid_cell.x, mid_cell.y + 2], "destino": [mid_cell.x + 2, mid_cell.y + 2],
		"recurso": "comida", "celulas": [[mid_cell.x, mid_cell.y + 2], [mid_cell.x + 1, mid_cell.y + 2]],
		"usos": 5, "sucessos": 5, "ultimo_tick": 1, "peso": 2.0
	}]
	var routed_path := Planner.plan_path(Vector2(100, 100), Vector2(300, 100), s, w.size)
	check(not routed_path.is_empty(), "planejamento com rotas preferidas falhou", f)

func _test_telepathy_boundary(f: Array) -> void:
	# 1. Static check
	var forbidden := RegEx.new()
	forbidden.compile("(?:world|self)\\s*(?:\\.\\s*(?:obstacles|foods|waters|feeders|objects|_obstacle_grid)\\b|\\[\\s*[\"'](?:obstacles|foods|waters|feeders|objects|_obstacle_grid)[\"'])")
	for folder in ["res://scripts/mind", "res://scripts/spatial", "res://scripts/behavior"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				check(forbidden.search(FileAccess.get_file_as_string(folder.path_join(file))) == null, "verdade do mundo acessada em " + file, f)
	
	# 2. Dynamic check: Two worlds identical except for an obstacle outside sensory range
	var w1 = garden(592014)
	var w2 = garden(592014)
	
	# Food target at (750, 300) known to pet in both worlds
	w1.place_food(Vector2(750, 300), "fruta")
	w2.place_food(Vector2(750, 300), "fruta")
	w1.creatures[w1.pet_id].mind.spatial.lugares.append({
		"id": "comida:18:7", "recurso": "comida", "pos": [750, 300], "visitas": 8, "achados": 8,
		"falhas": 0, "ultimo_tick": 10, "ganho_medio": 25.0, "expectativa": 0.95, "confianca": 0.9,
		"fonte": "interagido", "alpha": 3.0, "beta": 0.5, "consecutivas": 0, "retry_tick": 0
	})
	w2.creatures[w2.pet_id].mind.spatial.lugares.append({
		"id": "comida:18:7", "recurso": "comida", "pos": [750, 300], "visitas": 8, "achados": 8,
		"falhas": 0, "ultimo_tick": 10, "ganho_medio": 25.0, "expectativa": 0.95, "confianca": 0.9,
		"fonte": "interagido", "alpha": 3.0, "beta": 0.5, "consecutivas": 0, "retry_tick": 0
	})
	
	# In w2, place obstacle far away outside vision range (x=500, y=500; pet at 120, 300)
	w2.place_obstacle(Vector2(500, 500), "parede", 30.0)
	
	# Run both for 20 ticks
	for i in 20:
		w1.step()
		w2.step()
		var c1 = w1.creatures[w1.pet_id]
		var c2 = w2.creatures[w2.pet_id]
		check(c1.pos == c2.pos, "posicoes divergiram com obstaculo oculto no tick %d" % i, f)
		check(c1.heading == c2.heading, "heading divergiu com obstaculo oculto no tick %d" % i, f)
		check(c1.mind.spatial.mapa == c2.mind.spatial.mapa, "mapa divergiu com obstaculo oculto no tick %d" % i, f)
	
	# Positive control: visible obstacle in front MUST cause divergence
	var w3 = garden(592014)
	w3.place_obstacle(Vector2(150, 300), "parede", 20.0)
	var diverged := false
	for i in 10:
		w3.step()
		if w3.creatures[w3.pet_id].heading != w1.creatures[w1.pet_id].heading:
			diverged = true
			break
	check(diverged, "controle positivo: obstaculo visivel nao causou divergencia", f)

func _test_persistence_v17(f: Array) -> void:
	var w = garden(592015)
	var c = w.creatures[w.pet_id]
	w.place_obstacle(Vector2(400, 300), "parede", 25.0)
	c.mind.decide(c, w.tick, w.sense(c))
	
	# Snapshot check
	var snap: Dictionary = c.spatial_snapshot()
	check(snap.has("mapa_local") and snap.has("bloqueios") and snap.has("rotas"), "snapshot nao contem campos estendidos P2", f)
	
	# Roundtrip test
	var dict := w.to_dict()
	check(dict.save_version == 17, "save_version nao e 17", f)
	var loaded = World.from_dict(JSON.parse_string(JSON.stringify(dict, "", true, true)))
	check(loaded != null, "load v17 falhou", f)
	check(loaded.to_dict() == dict, "roundtrip v17 divergiu", f)
	
	# Idempotent migration v16 -> v17
	var v16_data := dict.duplicate(true)
	v16_data.save_version = 16
	var migrated1 = World._migrate_v16(v16_data)
	var migrated2 = World._migrate_v16(migrated1)
	check(migrated1.save_version == 17, "migracao v16 para v17 falhou", f)
	check(migrated1 == migrated2, "migracao v16 nao idempotente", f)
	
	# Rejection of hostile data
	for bad in [NAN, INF, "bad", null, -5, 99999]:
		var hostile := dict.duplicate(true)
		var sp = hostile.creatures[0].mind.spatial
		sp.mapa["0:0"] = {"pos": [0, 0], "estado": bad, "confianca": 1.0, "tick": 0}
		check(World.from_dict(hostile) == null, "save hostil aceitou estado invalido", f)
	
	# Coordinate out of bounds
	var hostile_bounds := dict.duplicate(true)
	hostile_bounds.creatures[0].mind.spatial.mapa["999:999"] = {"pos": [999, 999], "estado": "livre", "confianca": 1.0, "tick": 0}
	check(World.from_dict(hostile_bounds) == null, "save hostil aceitou celula fora do mundo", f)

func _test_performance(f: Array) -> void:
	var w = garden(592016)
	var c = w.creatures[w.pet_id]
	for x in [300, 450, 600]:
		for y in [100, 200, 400, 500]:
			w.place_obstacle(Vector2(x, y), "parede", 20.0)
	
	var start_us := Time.get_ticks_usec()
	for i in 200:
		w.step()
	var elapsed_ms := float(Time.get_ticks_usec() - start_us) / 1000.0
	var ms_per_tick := elapsed_ms / 200.0
	check(ms_per_tick < 2.0, "CPU media do pet excedeu 2.0 ms/tick: %.3f ms" % ms_per_tick, f)
