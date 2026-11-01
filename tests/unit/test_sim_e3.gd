extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const Teaching = preload("res://scripts/interaction/ensino.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func run() -> Array:
	var failures: Array = []
	_reward_gate(failures)
	_water_and_assistance(failures)
	_training_and_reset(failures)
	_persistence(failures)
	_bounds_and_legacy(failures)
	return failures

func check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)

func snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)

func scene(seed_value: int = 51, heading: float = 0.0):
	var world := World.new(seed_value, {"creature_count": 0, "food_count": 0,
		"obstacle_count": 0, "water_count": 0, "water_enabled": true,
		"food_regrow": false, "reproduction_enabled": false})
	var genes := Genes.new()
	genes.size = 8.0
	genes.speed = 30.0
	genes.vision_range = 240.0
	genes.vision_fov = TAU
	var id: int = world.spawn_creature(Vector2(400, 300), "E3", genes)
	world.pet_id = id
	world.creatures[id].heading = heading
	world.creatures[id].hydration = 65.0
	return world

func body(world):
	return world.creatures[world.pet_id]

func finish(world, limit: int = 140) -> Dictionary:
	var creature = body(world)
	for index in range(limit):
		world.step()
		if not creature.alive or not creature.ensino.running():
			break
	return creature.ensino.active

func _reward_gate(f: Array) -> void:
	var w = scene()
	var c = body(w)
	var energy: float = c.energy
	var hydration: float = c.hydration
	var position: Vector2 = c.pos
	check(not w.ensino_recompensar(c.id).ok, "Recompensa sem sessão aceita", f)
	check(w.ensino_iniciar(c.id, "ir_ate_local", Vector2(500, 300), true, 140).ok, "Não iniciou ensino", f)
	var q: Array = c.brain.goal_q.duplicate()
	var survival_q: Array = c.brain.q.duplicate()
	check(not w.ensino_recompensar(c.id).ok and c.brain.goal_q == q and c.brain.q == survival_q, "Recompensa sem conclusão alterou política", f)
	w.ensino_mostrar(c.id, Vector2(500, 300), true)
	w.ensino_observar(c.id)
	check(c.energy == energy and c.hydration == hydration and c.pos == position, "Iniciar/mostrar/observar/recompensar alterou fisiologia/posição", f)
	var result := finish(w)
	check(result.status == "success" and c.pos.distance_to(Vector2(500, 300)) <= Obs.reach(c), "Conclusão não corresponde a chegada física", f)
	energy = c.energy
	hydration = c.hydration
	position = c.pos
	check(w.ensino_recompensar(c.id).updates > 0 and c.brain.goal_q != q, "Conclusão real não atualizou política", f)
	check(c.brain.q == survival_q and c.energy == energy and c.hydration == hydration and c.pos == position, "Reforço de ensino alterou fisiologia ou política de sobrevivência", f)
	q = c.brain.goal_q.duplicate()
	check(not w.ensino_recompensar(c.id).ok and c.brain.goal_q == q, "Recompensa repetida gerou crédito grátis", f)
	check(w.ensino_observar(c.id).skills[0].text == "Ainda não aprendeu", "Demonstração assistida contou como aprendizado autônomo", f)
	var blocked = scene(52)
	var b = body(blocked)
	b.brain = Q.new()
	b.brain.learning = false
	blocked.place_obstacle(Vector2(450, 300), 20)
	blocked.ensino_iniciar(b.id, "ir_ate_local", Vector2(510, 300), false, 50)
	q = b.brain.goal_q.duplicate()
	check(finish(blocked, 50).status == "timeout" and not blocked.ensino_recompensar(b.id).ok and b.brain.goal_q == q, "Proximidade/bloqueio produziu sucesso ou recompensa sem conclusão", f)

func _water_and_assistance(f: Array) -> void:
	var w = scene(53, PI)
	var c = body(w)
	w.place_water(Vector2(500, 300), 18)
	w.ensino_iniciar(c.id, "buscar_agua", Vector2.INF, true, 140)
	var result := finish(w)
	check(result.status == "success" and result.assistance == result.steps and result.assistance > 0, "Rota assistida não registrada", f)
	check(w.events.any(func(e): return e.type == "drink" and e.creature_id == c.id and e.hydration > 0), "Busca de água concluiu sem bebida real", f)
	check(c.hydration > 65 and c.energy < result.energy_before, "Água não passou pela física/custo normal", f)
	check(w.ensino_recompensar(c.id).ok, "Bebida real não pode ser recompensada", f)
	var thirsty = scene(54)
	var t = body(thirsty)
	t.hydration = 10.0
	thirsty.place_water(t.pos, 18)
	thirsty.ensino_iniciar(t.id, "ir_ate_local", Vector2(510, 300), true, 5)
	thirsty.step()
	check(t.last_action == "drink" and t.ensino.active.assistance == 0 and t.ensino.active.status != "success", "Ensino sobrepôs sede crítica", f)
	var commands = scene(55)
	var p = body(commands)
	commands.ensino_iniciar(p.id, "ir_ate_local", Vector2(500, 300), true, 140)
	commands.comandos.aplicar("chamar", commands, Vector2(500, 300))
	check(p.ensino.active.status == "cancelled", "Ordem do jogador poderia contar como autonomia de ensino", f)

func train():
	var policy := Q.new()
	for heading_index in range(-6, 7):
		var w = scene(80 + heading_index, heading_index * 0.5)
		var c = body(w)
		c.brain = policy
		w.ensino_iniciar(c.id, "ir_ate_local", Vector2(500, 300), true, 140)
		finish(w)
		w.ensino_recompensar(c.id)
	return policy

func _training_and_reset(f: Array) -> void:
	var policy = train()
	policy.learning = false
	var naive = scene(60, PI)
	var n = body(naive)
	n.brain = Q.new()
	n.brain.learning = false
	naive.ensino_iniciar(n.id, "ir_ate_local", Vector2(500, 300), false, 140)
	var trained = scene(60, PI)
	var t = body(trained)
	t.brain = policy
	trained.ensino_iniciar(t.id, "ir_ate_local", Vector2(500, 300), false, 140)
	var nr := finish(naive)
	var tr := finish(trained)
	print("E3 measured naive=%s distance=%.2f trained=%s distance=%.2f updates=%d" % [nr.status, nr.final_distance, tr.status, tr.final_distance, policy.goal_updates])
	check(nr.status == "timeout" and tr.status == "success" and tr.assistance == 0 and t.pos != n.pos, "Treinamento não mudou comportamento medido versus naive", f)
	var energy: float = t.energy
	var hydration: float = t.hydration
	var position: Vector2 = t.pos
	var other_table: Array = n.brain.goal_q.duplicate()
	check(trained.ensino_reset(t.id) and t.brain.goal_updates == 0 and t.brain.goal_q.all(func(v): return v == 0.0), "Reset não apagou tabela/contador de ensino", f)
	check(t.ensino.active.is_empty() and t.ensino.events.is_empty() and t.ensino.attempts.is_empty() and t.energy == energy and t.hydration == hydration and t.pos == position and n.brain.goal_q == other_table, "Reset alterou corpo/outra criatura ou reteve histórico", f)

func _persistence(f: Array) -> void:
	var w = scene(61, PI)
	var c = body(w)
	w.ensino_iniciar(c.id, "ir_ate_local", Vector2(500, 300), true, 140)
	for i in range(9):
		w.step()
	var encoded := snapshot(w)
	var restored := World.from_dict(JSON.parse_string(encoded))
	check(restored != null and snapshot(restored) == encoded, "Round-trip perdeu brain/registro/transição E3", f)
	if restored == null:
		return
	for i in range(45):
		w.step()
		restored.step()
	check(snapshot(w) == snapshot(restored), "Continuação determinista E3 divergiu após save", f)
	w.ensino_recompensar(c.id)
	restored.ensino_recompensar(c.id)
	check(snapshot(w) == snapshot(restored), "Recompensa após round-trip divergiu", f)
	var store := Store.new("user://e3-test-checkpoints")
	check(store.save_world(w, "teaching").ok, "Checkpoint E3 falhou", f)
	var loaded := store.load_world("teaching")
	check(loaded.ok and snapshot(loaded.world) == snapshot(w), "Arquivo perdeu brain/registro E3", f)
	var a = scene(62, 1.2)
	var b = scene(62, 1.2)
	a.ensino_iniciar(a.pet_id, "ir_ate_local", Vector2(500, 300), false, 70)
	b.ensino_iniciar(b.pet_id, "ir_ate_local", Vector2(500, 300), false, 70)
	for i in range(70):
		a.step()
		b.step()
	check(snapshot(a) == snapshot(b), "Ensino não determinista por seed", f)

func _bounds_and_legacy(f: Array) -> void:
	var w = scene(63)
	var c = body(w)
	for i in range(40):
		w.ensino_iniciar(c.id, "ir_ate_local", c.pos, true, 1)
		w.step()
		w.ensino_recompensar(c.id)
	check(c.ensino.attempts.size() == Teaching.LIMIT and c.ensino.sessions.size() == Teaching.LIMIT and c.ensino.events.size() == Teaching.LOG_LIMIT, "Histórico de ensino ultrapassou limites", f)
	var statistics: Dictionary = c.ensino.statistics("ir_ate_local")
	check(not statistics.learned and statistics.attempts == 0, "Assistência inflou taxa autônoma", f)
	for i in range(5):
		w.ensino_iniciar(c.id, "ir_ate_local", c.pos, false, 1)
		w.step()
	statistics = c.ensino.statistics("ir_ate_local")
	check(statistics.learned and statistics.success_rate == 1.0, "Cinco sucessos autônomos não aparecem na API", f)
	for i in range(20):
		w.ensino_iniciar(c.id, "ir_ate_local", Vector2(800, 300), false, 1)
		w.step()
	statistics = c.ensino.statistics("ir_ate_local")
	check(not statistics.learned and statistics.attempts == 20 and statistics.success_rate == 0.0, "Taxa recente não voltou a Ainda não aprendeu após fracassos", f)
	check(World.from_dict(w.to_dict()) != null, "Histórico no limite não carrega", f)
	var state: Dictionary = w.to_dict()
	var invalid := state.duplicate(true)
	invalid.creatures[0].ensino.active.final_distance = NAN
	check(World.from_dict(invalid) == null, "Save aceitou NaN no ensino", f)
	invalid = state.duplicate(true)
	invalid.creatures[0].ensino.events.append(invalid.creatures[0].ensino.events[0])
	check(World.from_dict(invalid) == null, "Save aceitou histórico acima do limite", f)
	invalid = state.duplicate(true)
	invalid.creatures[0].brain.erase("goal_q")
	check(World.from_dict(invalid) == null, "QBrain v4 incompleto aceito como legado", f)
	var legacy = scene(64)
	var v5: Dictionary = legacy.to_dict()
	v5.save_version = 5
	var original := JSON.stringify(v5)
	var migrated := World.from_dict(v5)
	check(migrated != null and migrated.creatures[migrated.pet_id].ensino == null and JSON.stringify(v5) == original and World._migrate_v5(migrated.to_dict()) == migrated.to_dict(), "Migração v5 não idempotente ou inventou ensino", f)
	var old_brain := Q.new().to_dict()
	old_brain.version = 3
	old_brain.erase("goal_q")
	old_brain.erase("goal_updates")
	old_brain.q[0] = 0.123
	var migrated_brain = Q.from_dict(old_brain)
	check(migrated_brain != null and migrated_brain.q[0] == snappedf(0.123, 0.000001) and migrated_brain.goal_updates == 0 and migrated_brain.goal_q.all(func(v): return v == 0.0), "Migração QBrain v3 perdeu aprendizado", f)
