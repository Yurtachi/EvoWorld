extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Signals = preload("res://scripts/communication/signal_channel.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func run() -> Array:
	var failures: Array = []
	_channel(failures)
	_noise(failures)
	_policy(failures)
	_persistence(failures)
	_commands(failures)
	return failures

func _check(ok: bool, message: String, failures: Array) -> void:
	if not ok:
		failures.append(message)

func _world(seed: int = 82):
	var world := World.new(seed, {"creature_count": 0, "food_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": false, "signal_enabled": true,
		"signal_noise": 0.0, "signal_cost": 0.75, "signal_range": 100.0})
	world.pet_id = world.spawn_creature(Vector2(200, 200), "Emissor", Genes.new())
	world.spawn_creature(Vector2(250, 200), "Vizinho", Genes.new())
	world.spawn_creature(Vector2(500, 200), "Distante", Genes.new())
	return world

func _channel(f: Array) -> void:
	var world = _world()
	var bodies: Array = world.creatures.values()
	var emitter = bodies[0]
	var near = bodies[1]
	near.heading = 0.0
	var energy: float = emitter.energy
	world.place_food(emitter.pos)
	_check(world.emitir_sinal(emitter.id, 2), "Emissão válida recusada", f)
	_check(is_equal_approx(energy - emitter.energy, 0.75), "Custo incorreto", f)
	_check(near.last_signal.symbol == 2 and bodies[2].last_signal.is_empty() and emitter.last_signal.is_empty(), "Alcance/receptor incorreto", f)
	_check(near.last_signal.distance_bucket == 0 and near.last_signal.direction_bucket == 0, "Categorias de distância/direção incorretas", f)
	_check(world.signal_log[0].context.saw_food and world.signal_log[0].receivers == [near.id], "Contexto/receptores ausentes", f)
	var observed: Dictionary = world.sense(near)
	observed.signal.symbol = 0
	_check(near.last_signal.symbol == 2, "Observação compartilha memória mutável", f)
	energy = emitter.energy
	for symbol in [-1, 4, 99]:
		_check(not world.emitir_sinal(emitter.id, symbol), "Símbolo inválido aceito", f)
	_check(not world.emitir_sinal(-1, 0) and emitter.energy == energy, "Emissão inválida cobrou energia", f)
	world.signal_enabled = false
	_check(not world.emitir_sinal(emitter.id, 0) and emitter.energy == energy and world.sense(near).signal.is_empty(), "Canal desligado tem efeito", f)
	_check(world.sense(emitter).action_count == 5, "Canal desligado permite ações de sinal", f)
	world.signal_enabled = true
	# Eight symbols are available when explicitly configured; none has a label.
	world.signal_count = 8
	_check(world.emitir_sinal(emitter.id, 7) and near.last_signal.symbol == 7, "Oitavo símbolo indisponível", f)
	emitter.energy = 0.1
	_check(not world.emitir_sinal(emitter.id, 0) and emitter.energy == 0.1, "Energia insuficiente cobrada", f)
	world.step()
	_check(world.signal_log.back().action_changes.size() == 1 and world.signal_log[0].action_changes.is_empty(), "Primeira ação após a última recepção não registrada", f)
	world.tick += world.signal_ttl + 1
	_check(world.sense(near).signal.is_empty(), "Sinal não expirou", f)
	var limit_world = _world()
	limit_world.signal_cost = 0.0
	for i in range(Signals.LOG_LIMIT + 20):
		limit_world.tick = i
		limit_world.emitir_sinal(limit_world.pet_id, i % 4)
	_check(limit_world.signal_log.size() == Signals.LOG_LIMIT and limit_world.signal_log[0].tick == 20, "Buffer de sinais sem limite", f)

func _noise(f: Array) -> void:
	var a = _world(998)
	var b = _world(998)
	a.signal_noise = 0.5
	b.signal_noise = 0.5
	a.signal_cost = 0.0
	b.signal_cost = 0.0
	var heard := 0
	for i in range(100):
		a.tick = i
		b.tick = i
		a.emitir_sinal(a.pet_id, i % 4)
		b.emitir_sinal(b.pet_id, i % 4)
		heard += a.signal_log.back().receivers.size()
	_check(heard > 0 and heard < 100 and a.to_dict() == b.to_dict(), "Ruído não é reproduzível/perda parcial", f)
	a.signal_noise = 1.0
	a.tick += 1
	var before: float = a.creatures[a.pet_id].energy
	a.signal_cost = 0.75
	_check(a.emitir_sinal(a.pet_id, 0) and a.signal_log.back().receivers.is_empty() and is_equal_approx(before - a.creatures[a.pet_id].energy, 0.75), "Ruído total deve perder recepção e cobrar emissão", f)

func _policy(f: Array) -> void:
	var world = _world()
	var bodies: Array = world.creatures.values()
	var sender = bodies[0]
	var receiver = bodies[1]
	sender.brain = Q.new()
	receiver.brain = Q.new()
	sender.brain.learning = false
	receiver.brain.learning = false
	var initial: Dictionary = Obs.features(sender, world.sense(sender), world.size)
	sender.brain.q[initial.state * Actions.COUNT + Actions.emitir_sinal(3)] = 4.0
	world.emitir_sinal(sender.id, 3)
	var heard: Dictionary = Obs.features(receiver, world.sense(receiver), world.size)
	var silence: Dictionary = Obs.features(receiver, {"foods": [], "obstacles": []}, world.size)
	_check(heard.state != silence.state and heard.signal.symbol == 3, "Sinal não altera estado Q", f)
	receiver.brain.q[heard.state * Actions.COUNT + Actions.REST] = 3.0
	var before: float = sender.energy
	world.step()
	_check(sender.last_action == "emit_signal_3" and sender.energy < before - world.signal_cost, "Política não emitiu com custo real", f)
	_check(receiver.last_action == "rest", "Política não reagiu ao estado ouvido", f)
	# Learning uses actual energy loss; symbols themselves give no reward.
	sender.brain.learning = true
	sender.brain.epsilon_start = 0.0
	sender.brain.epsilon_min = 0.0
	world.step()
	_check(sender.brain.total_reward < 0.0, "Emissão ganhou recompensa artificial", f)
	var old := Q.new().to_dict()
	old.version = 1
	old.q = []
	old.q.resize(48 * 5)
	old.q.fill(0.0)
	old.q[7 * 5 + 3] = 12.5
	old.prev_state = 7
	old.prev_action = 3
	var migrated = Q.from_dict(old)
	_check(migrated != null and migrated.value(7, 3) == 12.5 and migrated.prev_state == 7 and migrated.prev_action == 3, "Migração Q v1 perdeu valores/transição", f)
	old.prev_state = 48
	_check(Q.from_dict(old) == null, "Migração Q aceitou estado fora da tabela v1", f)

func _persistence(f: Array) -> void:
	var world = _world()
	world.creatures[world.pet_id].brain = Q.new()
	world.emitir_sinal(world.pet_id, 1)
	world.comandos.aplicar({"intent": "seguir"}, world, Vector2(400, 250))
	var saved: Dictionary = world.to_dict()
	var restored = World.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(restored != null, "Save de sinais/ordens rejeitado", f)
	if restored == null:
		return
	_check(_snapshot(world) == _snapshot(restored), "Round-trip alterou sinais/ordens", f)
	for i in range(30):
		world.step()
		restored.step()
	_check(_snapshot(world) == _snapshot(restored), "Continuação divergiu após round-trip", f)
	var directory := "user://signal_test_" + str(OS.get_process_id())
	var store := Store.new(directory)
	var written: Dictionary = store.save_world(world)
	var loaded: Dictionary = store.load_world()
	_check(written.ok and loaded.ok, "Round-trip em arquivo falhou", f)
	if loaded.ok:
		_check(_snapshot(loaded.world) == _snapshot(world), "Arquivo perdeu canal/ordens", f)
	DirAccess.remove_absolute(directory + "/world.json")
	DirAccess.remove_absolute(directory)
	var legacy := _world().to_dict()
	legacy.save_version = 2
	legacy.erase("commands")
	legacy.erase("signal_log")
	for key in Signals.DEFAULTS:
		legacy.config.erase(key)
	var migrated = World.from_dict(legacy)
	_check(migrated != null and migrated.to_dict().save_version == World.SAVE_VERSION and not migrated.signal_enabled and migrated.signal_log.is_empty(), "Migração v2 falhou", f)
	for key in ["signal_cost", "signal_noise", "signal_range", "signal_count", "signal_ttl"]:
		var bad := saved.duplicate(true)
		bad.config[key] = "inválido"
		_check(World.from_dict(bad) == null, "Configuração de sinal inválida aceita: " + key, f)
	var bad := saved.duplicate(true)
	bad.signal_log[0].receivers = ["inválido"]
	_check(World.from_dict(bad) == null, "Receptor inválido aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[1].last_signal.tick = saved.tick + 1
	_check(World.from_dict(bad) == null, "Sinal futuro aceito", f)
	bad = saved.duplicate(true)
	bad.commands.order.target = [INF, 0]
	_check(World.from_dict(bad) == null, "Alvo inválido aceito", f)
	for malformed in [null, {}, [{"tick": 0}], ["sinal"]]:
		bad = saved.duplicate(true)
		bad.signal_log = malformed
		_check(World.from_dict(bad) == null, "Log malformado aceito", f)
	bad = saved.duplicate(true)
	bad.signal_log[0].symbol = 4
	_check(World.from_dict(bad) == null, "Símbolo de log inválido aceito", f)

func _commands(f: Array) -> void:
	var world = _world()
	var pet = world.creatures[world.pet_id]
	pet.heading = 0.0
	pet.brain = Q.new()
	world.step()
	world.comandos.aplicar({"intent": "parar"}, world)
	var pos: Vector2 = pet.pos
	var energy: float = pet.energy
	var table: Array = pet.brain.q.duplicate()
	for i in range(5):
		world.step()
	_check(pet.pos == pos and pet.energy < energy and pet.brain.q == table and pet.brain.prev_state == -1, "Parar moveu/gerou energia/contaminou aprendizado", f)
	world.comandos.aplicar({"intent": "seguir"}, world, pos + Vector2(150, 0))
	for i in range(10):
		world.step()
	_check(pet.pos.x > pos.x, "Seguir não moveu o companheiro", f)
	_check(world.comandos.atualizar_alvo(world, pet.pos + Vector2(100, 0)), "Alvo de seguir não atualizou", f)
	for intent in ["chamar", "brincar"]:
		pos = pet.pos
		pet.heading = 0.0
		world.comandos.aplicar({"intent": intent}, world, pos + Vector2(40, 0))
		for i in range(18):
			world.step()
		_check(pet.pos.x > pos.x and not world.comandos.acao_pendente(pet, world).ativo, intent + " não chegou/terminou", f)
	world.comandos.limpar()
	world.step()
	_check(pet.brain.prev_state >= 0, "Cérebro não retomou após comando", f)
	world.comandos.aplicar({"intent": "seguir"}, world, pet.pos + Vector2(100, 0))
	world.place_obstacle(pet.pos + Vector2(30, 0), 8.0)
	for i in range(10):
		world.step()
	_check(world._clear(pet.pos, pet.genome.size), "Comando atravessou obstáculo", f)
	for intent in ["parar", "seguir", "chamar", "brincar"]:
		world.comandos.aplicar({"intent": intent}, world, Vector2(600, 300))
		var restored = World.from_dict(JSON.parse_string(_snapshot(world)))
		_check(restored != null, "Ordem não restaurou: " + intent, f)
		if restored != null:
			world.step()
			restored.step()
			_check(_snapshot(restored) == _snapshot(world), "Retomada de ordem divergiu: " + intent, f)

func _snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)
