extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Mind = preload("res://scripts/mind/creature_mind.gd")
const Affect = preload("res://scripts/mind/affect.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func check(ok: bool, message: String, f: Array) -> void:
	if not ok: f.append(message)

func snapshot(w) -> String:
	return JSON.stringify(w.to_dict(), "", true, true)

func garden(world_seed: int = 81001):
	return World.new(world_seed, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false, "personality_enabled": true, "water_enabled": true})

func body(w, pos: Vector2 = Vector2(100, 100)):
	var g := Genes.new()
	g.size = 8.0
	g.speed = 30.0
	g.vision_range = 180.0
	g.vision_fov = snappedf(TAU, 0.000001)
	g.temperament = {"curiosity": 0.5, "caution": 0.5, "sociability": 0.5, "impulsivity": 0.5}
	var id: int = w.spawn_creature(pos, "M1", g)
	if w.pet_id == -1: w.pet_id = id
	w.creatures[id].heading = 0.0
	return w.creatures[id]

func run() -> Array:
	var f: Array = []
	_scope_and_golden(f)
	_affect_and_physics(f)
	_motivation(f)
	_persistence(f)
	return f

func _scope_and_golden(f: Array) -> void:
	var fresh = World.new_world(44)
	check(not fresh.mind_all and fresh.mind_enabled_ids == [fresh.pet_id] and fresh.creatures.values().filter(func(c): return c.mind != null).size() == 1, "M1 deve iniciar apenas no pet novo", f)
	var all = World.new_world(44, {"mind_all": true, "creature_count": 3})
	check(all.mind_enabled_ids.size() == 3, "mind_all nao ativou os tres", f)
	var off = World.new_world(44, {"mind_enabled_ids": []})
	check(off.mind_enabled_ids.is_empty(), "config explicita de IDs vazia ignorada", f)
	var before: String = snapshot(off)
	check(off.enable_mind(off.pet_id) and off.disable_mind(off.pet_id) and snapshot(off) == before, "enable/disable alterou estado fisico/RNG", f)
	check(not off.enable_mind(-1), "ID invalido ativou mind", f)
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experiments/m1_golden.json"))
	for item in data:
		var original := JSON.stringify(item.initial, "", true, true)
		var w = World.from_dict(item.initial)
		check(w != null, "golden v7 nao carregou", f)
		if w == null: continue
		check(w.mind_enabled_ids.is_empty(), "migracao v7 ativou M1", f)
		check(World._migrate_v7(w.to_dict()) == w.to_dict(), "migracao v7 nao idempotente", f)
		for i in 100: w.step()
		var expected = World.from_dict(item.after100)
		check(expected != null and snapshot(w) == snapshot(expected), "golden v7 mudou em 100 ticks (estado inteiro)", f)
		check(JSON.stringify(item.initial, "", true, true) == original, "migracao alterou entrada", f)
		# Explicit opt-out and ancient world are byte-identical after schema migration.
		var explicit = World.from_dict(item.initial)
		var control = World.from_dict(item.initial)
		explicit.enable_mind(explicit.pet_id)
		explicit.disable_mind(explicit.pet_id)
		for i in 40:
			explicit.step()
			control.step()
		check(snapshot(explicit) == snapshot(control), "criatura sem mind mudou comportamento", f)

func _affect_and_physics(f: Array) -> void:
	var w = garden()
	var c = body(w)
	w.enable_mind(c.id)
	var neutral := Affect.new()
	for tick in 30: neutral.decay(tick, c.temperament)
	check(neutral.cause_log.is_empty() and neutral.values.values().all(func(v): return v == 0.0), "tempo sozinho criou afeto em estado neutro", f)
	var initial: Vector2 = c.pos
	var energy: float = c.energy
	var hydration: float = c.hydration
	# A real obstacle physically rejects a movement. No direct affect assignment.
	w.place_obstacle(c.pos + Vector2(35, 0), 20.0)
	c.pos = Vector2(106, 100)
	for tick in 8:
		w.tick += 1
		c.heading = 0.0
		w._apply_action(c, {}, Actions.FORWARD)
	check(float(c.mind.affect.values.frustracao) > 0.1 and c.mind.blocked_ticks >= 2, "bloqueio fisico repetido nao causou frustracao", f)
	check(c.energy == energy and c.hydration == hydration and c.pos == Vector2(106, 100), "afeto alterou fisiologia/posicao diretamente", f)
	check(c.mind.affect.cause_log.any(func(row): return row.causa == "blocked_motion"), "sem causa de bloqueio no log", f)
	var frustrated: float = c.mind.affect.values.frustracao
	w.obstacles.clear()
	for tick in 40: w.step()
	check(float(c.mind.affect.values.frustracao) < frustrated * 0.5, "frustracao nao decaiu apos liberar", f)
	var food_before: float = c.mind.affect.values.satisfacao
	c.energy = c.max_energy * 0.3
	var food: int = w.place_food(c.pos, "fruta")
	w._eat(c, food)
	check(float(c.mind.affect.values.satisfacao) > food_before, "refeicao real sem satisfacao", f)
	var fear_before: float = c.mind.affect.values.receio
	food = w.place_food(c.pos, "cogumelo")
	w._eat(c, food)
	check(float(c.mind.affect.values.receio) > fear_before, "toxicidade vivida sem receio", f)
	var ablated = garden()
	var off = body(ablated)
	ablated.enable_mind(off.id)
	off.mind.affect_enabled = false
	ablated.place_obstacle(off.pos + Vector2(35, 0), 20.0)
	off.pos = Vector2(106, 100)
	for tick in 8:
		ablated.tick += 1
		off.heading = 0.0
		ablated._apply_action(off, {}, Actions.FORWARD)
	check(off.mind.affect.cause_log.is_empty() and off.mind.affect.values.frustracao == 0.0, "ablacao ainda produz afeto", f)
	check(off.expression_state() == off.personality.expression(off), "ablacao ainda altera expressao", f)
	# Real prolonged contact, then separation; sensor data rebuilt at checkpoints.
	var social = garden()
	var a = body(social)
	var b = body(social, Vector2(120, 100))
	social.enable_mind(a.id)
	for tick in 50:
		social.tick += 1
		social._rebuild_spatial()
		a.mind.observe(social, a, social.sense(a), false)
	check(float(a.mind.affect.values.saturacao_social) > 0.1, "contato prolongado sem saturacao", f)
	b.pos = Vector2(800, 600)
	for tick in 70:
		social.tick += 1
		social._rebuild_spatial()
		a.mind.observe(social, a, social.sense(a), false)
	check(float(a.mind.affect.values.solidao) > 0.05, "ausencia real sem solidao", f)
	check(a.mind.experiences.any(func(row): return row.kind == "contact"), "encontro real nao criou memoria M1", f)

func _motivation(f: Array) -> void:
	var w = garden()
	var c = body(w)
	var other = body(w, Vector2(160, 100))
	w.enable_mind(c.id)
	w._rebuild_spatial()
	var sensors: Dictionary = w.sense(c)
	var goal: String = c.mind.decide(c, 0, sensors)
	c.personality.fatigue = 1.0
	check(c.mind.decide(c, 1, sensors) == goal, "compromisso minimo nao preservado", f)
	check(c.mind.decide(c, 12, sensors) == "descansar", "pontuacao nao troca apos compromisso", f)
	check(c.mind.decide(c, 92, sensors) != "descansar" and c.mind.motivo == "mind.timeout", "tempo maximo nao rompe loop", f)
	c.energy = c.max_energy * 0.1
	check(c.mind.decide(c, 93, sensors) == "comer" and c.mind.motivo == "mind.urgency", "fome critica nao prevalece", f)
	c.energy = c.max_energy
	c.hydration = 5.0
	check(c.mind.decide(c, 94, sensors) == "beber", "sede critica nao prevalece", f)
	c.hydration = 100.0
	c.personality.fatigue = 0.0
	var dist: float = c.pos.distance_to(other.pos)
	var energy: float = c.energy
	w._mind_action(c, sensors, "buscar_companhia", {}, INF)
	check(c.pos.distance_to(other.pos) < dist, "companhia nao aproxima fisicamente", f)
	dist = c.pos.distance_to(other.pos)
	w._mind_action(c, sensors, "buscar_privacidade", {}, INF)
	check(c.pos.distance_to(other.pos) > dist, "privacidade nao afasta fisicamente", f)
	# Memory bias depends on retrieval; ablation zeroes it without erasing history.
	c.mind.remember(94, "contact", -0.8, 0.9, other.id)
	check(c.mind.memory_bias("buscar_companhia", 94, sensors) < 0.0, "memoria adversa sem vies", f)
	c.mind.memory_enabled = false
	check(c.mind.memory_bias("buscar_companhia", 94, sensors) == 0.0, "ablacao de memoria nao remove vies", f)
	# All normal goal locomotion receives ordinary movement/metabolic cost via step.
	c.mind.objetivo_atual = "buscar_privacidade"
	c.mind.goal_started = w.tick
	w.step()
	check(c.energy < energy, "acao mental fisica sem custo normal", f)

func _persistence(f: Array) -> void:
	var a = World.new_world(81002, {"creature_count": 3, "reproduction_enabled": false})
	var b = World.new_world(81002, {"creature_count": 3, "reproduction_enabled": false})
	for i in 100:
		a.step()
		b.step()
	check(snapshot(a) == snapshot(b), "mesma seed divergiu com M1", f)
	var c = World.from_dict(JSON.parse_string(snapshot(a)))
	check(c != null and c.to_dict().save_version == 8 and snapshot(a) == snapshot(c), "v8 roundtrip perdeu mind", f)
	if c == null: return
	for i in 100:
		a.step()
		c.step()
	check(snapshot(a) == snapshot(c), "continuacao determinista v8 divergiu", f)
	var store := Store.new("user://m1_unit_saves")
	check(store.save_world(a, "mind").ok, "save v8 em disco falhou", f)
	var loaded := store.load_world("mind")
	check(loaded.ok and snapshot(loaded.world) == snapshot(a), "load v8 em disco divergiu", f)
	var snap: Dictionary = a.creatures[a.pet_id].mind_snapshot()
	snap.afetos.frustracao = 0.99
	snap.ultimos_logs.clear()
	check(snapshot(a) == snapshot(c), "snapshot UI expos estado mutavel", f)
	var good: Dictionary = a.to_dict()
	for wrong in [NAN, INF, -0.1, 1.1, true, null, "0.5", [], {}]:
		var bad := good.duplicate(true)
		bad.creatures[0].mind.affect.values.frustracao = wrong
		check(World.from_dict(bad) == null, "save aceitou afeto hostil " + str(wrong), f)
	for field in ["goal_started", "blocked_ticks", "contact_ticks", "absent_ticks"]:
		for wrong in [true, null, "5", -1, 0.5, INF]:
			var bad := good.duplicate(true)
			bad.creatures[0].mind[field] = wrong
			check(World.from_dict(bad) == null, "save aceitou " + field + " hostil", f)
	for field in ["mind_log", "experiences"]:
		var bad := good.duplicate(true)
		bad.creatures[0].mind[field].resize(100)
		check(World.from_dict(bad) == null, "save aceitou log/memoria excedente", f)
	var bad := good.duplicate(true)
	bad.config.mind_enabled_ids = []
	check(World.from_dict(bad) == null, "save aceitou mind fora dos IDs", f)
	bad = good.duplicate(true)
	bad.creatures[0].mind.goal_started = good.tick + 1
	check(World.from_dict(bad) == null, "save aceitou objetivo futuro", f)
	for i in 200:
		a.step()
	var mind = a.creatures[a.pet_id].mind
	check(mind.mind_log.size() <= Mind.LOG_LIMIT and mind.affect.cause_log.size() <= Affect.LOG_LIMIT and mind.experiences.size() <= Mind.MEMORY_LIMIT, "limites M1 excedidos", f)
