extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Food = preload("res://scripts/environment/food_catalog.gd")
const Water = preload("res://scripts/environment/water_rules.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

class RestBrain extends RefCounted:
	var last_reason := "brain.q_frozen"
	func decide(_creature, _obs, _rng) -> int:
		return Actions.REST
	func on_death(_creature) -> void:
		pass

func run() -> Array:
	var failures: Array = []
	_legacy_and_expansion(failures)
	_food_effects(failures)
	_offering(failures)
	_water_physics_and_sensors(failures)
	_drought(failures)
	_q_water(failures)
	_new_world_and_round_trip(failures)
	_reject_invalid(failures)
	return failures

func _check(ok: bool, message: String, failures: Array) -> void:
	if not ok:
		failures.append(message)

func _snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)

func _config() -> Dictionary:
	return {"creature_count": 0, "food_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": false, "water_enabled": true}

func _body(world):
	var genes := Genes.new()
	genes.size = 8.0
	genes.speed = 30.0
	genes.metabolism = 1.0
	genes.vision_range = 100.0
	genes.vision_fov = snappedf(TAU, 0.000001)
	var id: int = world.spawn_creature(Vector2(100, 100), "E1", genes)
	world.pet_id = id
	world.creatures[id].heading = 0.0
	return world.creatures[id]

## Captured by the unmodified v3 build at 14f915b, not synthesized from v4.
func _legacy_and_expansion(f: Array) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_v3.json"))
	var untouched := JSON.stringify(fixture, "", true, true)
	_check(int(fixture.save_version) == 3, "Fixture não é v3", f)
	var world := World.from_dict(fixture)
	_check(world != null, "Save real v3 rejeitado", f)
	if world == null:
		return
	_check(JSON.stringify(fixture, "", true, true) == untouched, "Migração alterou a entrada", f)
	_check(not world.water_enabled and world.waters.is_empty() and world.creatures.size() == 3, "Migração alterou ecologia/população antiga", f)
	_check(world.rng.to_dict() == fixture.rng_state and world.ids.next_id == int(fixture.next_id), "Migração consumiu RNG/IDs", f)
	for index in range(fixture.creatures.size()):
		var old: Dictionary = fixture.creatures[index]
		var body = world.creatures[int(old.id)]
		_check(body.pos == Vector2(old.pos[0], old.pos[1]) and body.hydration == Water.INITIAL and body.energy == old.energy, "Migração alterou posição/fisiologia antiga", f)
		if old.has("brain"):
			for state in range(Obs.LEGACY_STATE_COUNT):
				for action in range(13):
					if not is_equal_approx(body.brain.value(state, action), float(old.brain.q[state * 13 + action])):
						f.append("Migração Q v2 perdeu célula aprendida")
						return
	for food in world.foods:
		_check(food.food_type == "legacy", "Comida antiga não migrou para legacy", f)
	var before := world.to_dict()
	_check(world.expand("right", 500) and world.expand("bottom", 250.0), "Expansões válidas recusadas", f)
	var after := world.to_dict()
	_check(world.size == Vector2(before.size[0] + 500, before.size[1] + 250), "Expansão não ampliou limites", f)
	after["size"] = before["size"]
	_check(after == before, "Expansão alterou entidades, IDs, RNG, eventos ou genealogia", f)
	var stable := _snapshot(world)
	for side in ["left", "top", "invalid"]:
		_check(not world.expand(side, 20), "Borda não suportada aceita", f)
	for amount in [0, -1, INF, NAN, 100001, "50", true, null, [], {}]:
		_check(not world.expand("right", amount) and _snapshot(world) == stable, "Expansão inválida alterou mundo", f)
	var restored := World.from_dict(JSON.parse_string(stable))
	_check(restored != null and _snapshot(restored) == stable, "Mundo expandido não persistiu", f)
	var migrated_again := World.from_dict(world.to_dict())
	_check(migrated_again != null and _snapshot(migrated_again) == stable, "Migração não é idempotente", f)
	_check(World._migrate_v3(world.to_dict()) == world.to_dict(), "Migração v3 repetida alterou v4", f)
	for version in [1, 2]:
		var legacy := fixture.duplicate(true)
		legacy.save_version = version
		legacy.erase("signal_log")
		legacy.erase("commands")
		if version == 1:
			legacy.erase("genealogy")
		var migrated := World.from_dict(legacy)
		_check(migrated != null and migrated.to_dict().save_version == 4 and migrated.creatures.size() == 3, "Migração v%d falhou" % version, f)

func _food_effects(f: Array) -> void:
	var measured: Array = []
	for type in ["fruta", "semente", "folha", "cogumelo"]:
		var world := World.new(901, _config())
		var body = _body(world)
		body.energy = 10.0
		body.hydration = 20.0
		var food_id: int = world.place_food(body.pos, type)
		world._eat(body, food_id)
		var params: Dictionary = Food.PARAMETERS[type]
		_check(is_equal_approx(body.energy - 10.0, params.nutrition - params.toxicity) and is_equal_approx(body.hydration - 20.0, params.hydration), "Efeitos incorretos: " + type, f)
		_check(world.foods.is_empty() and world.events.back().type == "eat" and world.events.back().energy > 0.0, "Ingestão não consumiu/registrou: " + type, f)
		measured.append([body.energy, body.hydration])
		body.energy = body.max_energy
		body.hydration = Water.CAPACITY
		world.events.clear()
		world._eat(body, world.place_food(body.pos, type))
		_check(world.events.is_empty(), "Ganho zero/negativo contou como refeição: " + type, f)
		_check(is_equal_approx(body.energy, body.max_energy - params.toxicity), "Toxicidade não aplicada após saciedade: " + type, f)
	for a in range(measured.size()):
		for b in range(a + 1, measured.size()):
			_check(measured[a] != measured[b], "Alimentos não têm efeitos distintos", f)
	var world := World.new(902, _config())
	var body = _body(world)
	body.energy = 10.0
	body.hydration = 20.0
	world._eat(body, world.place_food(body.pos))
	_check(body.energy == 42.0 and body.hydration == 20.0, "place_food legado perdeu semântica de 32 energia", f)
	var id_before: int = world.ids.next_id
	_check(world.place_food(body.pos, "inexistente") == -1 and world.ids.next_id == id_before, "Tipo inválido consumiu ID", f)
	var preferred: int = world.place_food(body.pos + Vector2(30, 0), "fruta")
	world.place_food(body.pos + Vector2(25, 0), "cogumelo")
	_check(Obs.features(body, world.sense(body), world.size).food_id == preferred, "Palatabilidade não afeta avaliação básica", f)

func _offering(f: Array) -> void:
	var world := World.new(903, _config())
	var body = _body(world)
	body.energy = 20.0
	var pos: Vector2 = body.pos
	var energy: float = body.energy
	var hydration: float = body.hydration
	var food_id: int = world.oferecer_alimento(body.id, "semente")
	_check(food_id != -1 and body.energy == energy and body.hydration == hydration and body.pos == pos, "Oferta alterou fisiologia/posição imediatamente", f)
	_check(body.pos.distance_to(world.foods[0].pos) > Obs.reach(body), "Oferta já estava ao alcance de ingestão", f)
	world._eat(body, food_id)
	_check(body.energy == energy and world.foods.size() == 1, "Comeu oferta sem aproximar", f)
	for i in range(12):
		world.step()
	_check(world.foods.is_empty() and body.pos != pos and body.energy > energy and body.memory.any(func(e): return e.type == "eat" and e.food_id == food_id), "Oferta não produziu aproximação e ingestão reais", f)
	_check(world.oferecer_alimento(-1, "fruta") == -1 and world.oferecer_alimento(body.id, "invalid") == -1, "Oferta inválida aceita", f)

func _water_physics_and_sensors(f: Array) -> void:
	var world := World.new(904, _config())
	var body = _body(world)
	body.hydration = 20.0
	var water_id: int = world.place_water(Vector2(230, 100), 50)
	var sensors: Dictionary = world.sense(body)
	_check(sensors.waters.size() == 1 and sensors.waters[0].pos == Vector2(180, 100), "Sensor não percebeu margem de lago com centro distante", f)
	sensors.waters[0].radius = -1.0
	_check(world.waters[0].radius == 50.0, "Sensor compartilha região mutável", f)
	var energy: float = body.energy
	_check(not world._drink(body, water_id) and body.hydration == 20.0 and body.energy == energy, "Bebeu fora do alcance", f)
	world._apply_action(body, world.sense(body), Actions.DRINK)
	_check(body.hydration == 20.0 and body.last_reason == "ecology.drink_empty", "Ação beber ignorou alcance", f)
	world.comandos.aplicar({"intent": "parar"}, world)
	var start: Vector2 = body.pos
	for i in range(40):
		world.step()
	_check(body.pos != start and body.hydration > 40.0 and world.events.any(func(e): return e.type == "drink"), "Sede não suspendeu ordem nem buscou água/beber", f)
	_check(world._clear(Vector2(230, 100), body.genome.size), "Lago virou obstáculo sólido", f)
	body.pos = Vector2(230, 100)
	body.hydration = 99.0
	energy = body.energy
	_check(world._drink(body, water_id) and body.hydration == 100.0 and body.energy == energy, "Bebida não respeita limite/alterou energia", f)
	var count: int = world.events.size()
	_check(not world._drink(body, water_id) and world.events.size() == count, "Bebida de ganho zero produziu evento", f)
	body.pos = Vector2(100, 100)
	world.place_obstacle(Vector2(140, 100), 10)
	_check(world.sense(body).waters.is_empty(), "Água visível através de obstáculo", f)
	body.pos = Vector2(350, 100)
	body.genome.vision_fov = PI / 3
	_check(world.sense(body).waters.is_empty(), "Água fora do campo de visão percebida", f)

func _drought(f: Array) -> void:
	var explorer := World.new(908, _config())
	var thirsty = _body(explorer)
	thirsty.hydration = 39.0
	explorer.comandos.aplicar({"intent": "parar"}, explorer)
	var start: Vector2 = thirsty.pos
	explorer.step()
	_check(thirsty.last_reason == "ecology.no_water" and thirsty.pos != start and thirsty.hydration < 39.0, "Sede sem água não explora/suspende ordem", f)
	var world := World.new(905, _config())
	var body = _body(world)
	body.max_energy = 10000.0
	body.energy = 10000.0
	body.brain = RestBrain.new()
	for i in range(501):
		world.step()
	_check(is_equal_approx(body.hydration, 59.92) and is_equal_approx(body.thirst, 0.4008), "Regra explícita de perda de água divergente", f)
	for i in range(750):
		world.step()
	_check(body.hydration == 0.0 and body.thirst == 1.0 and body.alive, "Sem água não chegou à sede máxima limitada", f)
	var before: float = body.energy
	world.step()
	var basal: float = body.genome.metabolism * (0.52 + body.genome.size * 0.022) * World.TICK_DT
	_check(is_equal_approx(before - body.energy, basal + Water.DEHYDRATION_ENERGY_PER_SECOND * World.TICK_DT), "Desidratação não cobrou energia explicitamente", f)
	_check(not world.events.any(func(e): return e.type == "drink"), "Mundo sem água inventou bebida", f)
	for i in range(20):
		world.step()
		_check(is_finite(body.hydration) and body.hydration >= 0.0 and body.hydration <= 100.0 and is_finite(body.thirst), "Fisiologia não finita/limitada", f)

func _q_water(f: Array) -> void:
	var world := World.new(906, _config())
	var body = _body(world)
	world.place_water(Vector2(120, 100), 10)
	var sated: Dictionary = Obs.features(body, world.sense(body), world.size)
	body.hydration = 20.0
	var thirsty: Dictionary = Obs.features(body, world.sense(body), world.size)
	_check(thirsty.state != sated.state and thirsty.water_id != -1 and thirsty.water_bucket == 1, "Q não observa sede/água", f)
	_check(Actions.DRINK in thirsty.allowed_actions and Actions.SIGNAL_FIRST not in thirsty.allowed_actions, "Máscara de ações permite sinal desligado/omite bebida", f)
	var brain := Q.new()
	body.brain = brain
	brain.epsilon_start = 0.0
	brain.epsilon_min = 0.0
	brain.q[thirsty.state * Actions.COUNT + Actions.DRINK] = 5.0
	var energy: float = body.energy
	world.step()
	_check(body.last_action == "drink" and body.hydration > 50.0 and body.energy < energy, "Q não executou bebida física", f)
	world.step()
	_check(brain.total_reward > 0.0, "Q não contabilizou hidratação real", f)
	world.signal_enabled = true
	world.signal_count = 8
	var both: Dictionary = Obs.features(body, world.sense(body), world.size)
	_check(both.allowed_actions.size() == Actions.COUNT and Actions.DRINK in both.allowed_actions and Actions.emitir_sinal(7) in both.allowed_actions, "Água e oito sinais não coexistem", f)
	var snapshot := _snapshot(world)
	var restored := World.from_dict(JSON.parse_string(snapshot))
	_check(restored != null and _snapshot(restored) == snapshot, "Transição Q hídrica não persistiu", f)
	if restored != null:
		for i in range(40):
			world.step()
			restored.step()
		_check(_snapshot(restored) == _snapshot(world), "Continuação Q hídrica divergiu", f)

func _new_world_and_round_trip(f: Array) -> void:
	var a := World.new_world(9181)
	var b := World.new_world(9181)
	_check(a.creatures.size() == 12 and a.water_enabled and a.waters.size() == 3, "Mundo novo não usa 12 organismos/água", f)
	_check(World.new_world(9181, {"creature_count": 5}).creatures.size() == 5, "Mundo novo ignorou população explícita", f)
	_check(_snapshot(a) == _snapshot(b), "Inicialização por seed divergiu", f)
	for i in range(900):
		a.step()
		b.step()
	_check(_snapshot(a) == _snapshot(b), "Simulação E1 por seed divergiu", f)
	for body in a.creatures.values():
		_check(is_finite(body.energy) and is_finite(body.hydration) and body.hydration >= 0.0 and body.hydration <= Water.CAPACITY and body.pos.is_finite(), "Ecologia E1 produziu valores não finitos/limitados", f)
	var restored := World.from_dict(JSON.parse_string(_snapshot(a)))
	_check(restored != null and _snapshot(restored) == _snapshot(a), "Round trip v4 divergiu", f)
	if restored == null:
		return
	for i in range(100):
		a.step()
		restored.step()
	_check(_snapshot(a) == _snapshot(restored), "Retomada v4 divergiu", f)
	var directory := "user://e1_test_" + str(OS.get_process_id())
	var store := Store.new(directory)
	var first: Dictionary = store.save_world(a)
	a.step()
	var second: Dictionary = store.save_world(a)
	var loaded: Dictionary = store.load_world()
	_check(first.ok and second.ok and loaded.ok and _snapshot(loaded.world) == _snapshot(a), "SaveStore v4 falhou", f)
	var file := FileAccess.open(directory + "/world.json", FileAccess.WRITE)
	file.store_string("corrompido")
	file.close()
	var recovered: Dictionary = store.load_world()
	_check(recovered.ok and recovered.recovered and recovered.world.to_dict().save_version == 4, "Backup v4 não recuperou corrupção", f)
	for suffix in ["/world.json", "/world.json.bak"]:
		DirAccess.remove_absolute(directory + suffix)
	DirAccess.remove_absolute(directory)

func _reject_invalid(f: Array) -> void:
	var world := World.new(907, _config())
	var body = _body(world)
	world.place_water(Vector2(200, 200), 30)
	world.place_food(Vector2(150, 100), "fruta")
	var saved := world.to_dict()
	for value in [NAN, INF, -INF, -1, 100.1, "20", true, null, [], {}]:
		var bad := saved.duplicate(true)
		bad.creatures[0].hydration = value
		_check(World.from_dict(bad) == null, "Hidratação inválida aceita: " + str(value), f)
	for value in [NAN, INF, -1, 0, 501, "30", true, null]:
		var bad := saved.duplicate(true)
		bad.waters[0].radius = value
		_check(World.from_dict(bad) == null, "Raio de água inválido aceito", f)
	for value in ["water", "fruta ", 1, true, null, [], {}]:
		var bad := saved.duplicate(true)
		bad.foods[0].food_type = value
		_check(World.from_dict(bad) == null, "Tipo alimentar inválido aceito", f)
	for field in ["waters", "config", "creatures"]:
		var bad := saved.duplicate(true)
		bad[field] = "inválido"
		_check(World.from_dict(bad) == null, "Campo estrutural inválido aceito: " + field, f)
	var bad := saved.duplicate(true)
	bad.config.water_enabled = "true"
	_check(World.from_dict(bad) == null, "water_enabled de tipo incorreto aceito", f)
	bad = saved.duplicate(true)
	bad.waters[0].id = body.id
	_check(World.from_dict(bad) == null, "Água com ID duplicado aceita", f)
	bad = saved.duplicate(true)
	bad.waters[0].pos = [NAN, 100]
	_check(World.from_dict(bad) == null, "Água com posição não finita aceita", f)
	bad = saved.duplicate(true)
	bad.foods[0].energy = 100
	_check(World.from_dict(bad) == null, "Comida tipada diverge da tabela canônica", f)
	bad = saved.duplicate(true)
	bad.creatures[0].erase("hydration")
	_check(World.from_dict(bad) == null, "Save v4 incompleto aceito", f)
	for value in [NAN, INF, -1.0, 0.0, 501.0]:
		_check(world.place_water(Vector2(200, 200), value) == -1, "API aceitou raio de água inválido", f)
