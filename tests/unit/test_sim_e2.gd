extends RefCounted
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Personality = preload("res://scripts/behavior/personality.gd")
const Inheritance = preload("res://scripts/evolution/inheritance.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func run() -> Array:
	var f: Array = []
	_legacy(f)
	_drives_and_survival(f)
	_experience_and_conditioning(f)
	_bonds_and_expression(f)
	_memory_limits(f)
	_inheritance_and_identity(f)
	_round_trip(f)
	_profiles(f)
	_invalid(f)
	return f

func _check(ok: bool, message: String, f: Array) -> void:
	if not ok:
		f.append(message)

func _snapshot(w) -> String:
	return JSON.stringify(w.to_dict(), "", true, true)

func _config() -> Dictionary:
	return {"creature_count": 0, "food_count": 0, "obstacle_count": 0, "water_count": 0,
		"food_regrow": false, "reproduction_enabled": false, "water_enabled": true, "personality_enabled": true}

func _genes() -> Genes:
	var genes := Genes.new()
	genes.size = 8.0
	genes.speed = 30.0
	genes.vision_range = 180.0
	genes.vision_fov = snappedf(TAU, 0.000001)
	genes.temperament = {"curiosity": 0.5, "caution": 0.5, "sociability": 0.5, "impulsivity": 0.5}
	return genes

func _body(w, pos: Vector2 = Vector2(100, 100), genes = null):
	var id: int = w.spawn_creature(pos, "E2", _genes() if genes == null else genes)
	w.creatures[id].heading = 0.0
	if w.pet_id == -1:
		w.pet_id = id
	return w.creatures[id]

## Captured with the untouched E1 v4 code at commit 12b869d.
## This compares the full state, not merely population or aggregate scores.
func _legacy(f: Array) -> void:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_v4.json"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_v4_after100.json"))
	var untouched := JSON.stringify(saved, "", true, true)
	var w := World.from_dict(saved)
	_check(w != null, "Save real v4 não carregou", f)
	if w == null:
		return
	_check(not w.personality_enabled and w.creatures.values().all(func(c): return c.personality == null and c.temperament.is_empty()), "Migração ativou personalidade no legado", f)
	_check(JSON.stringify(saved, "", true, true) == untouched, "Migração v4 alterou entrada", f)
	_check(World._migrate_v4(w.to_dict()) == w.to_dict(), "Migração v4 não idempotente", f)
	for i in range(100):
		w.step()
	var reference := World.from_dict(expected)
	_check(reference != null and _snapshot(w) == _snapshot(reference), "Baseline v4 mudou após 100 passos (inclui RNG/genes/eventos)", f)
	var low_level := World.new(17, {"creature_count": 1, "obstacle_count": 0, "food_count": 0})
	_check(not low_level.personality_enabled and low_level.creatures.values()[0].personality == null, "Construtor histórico ativou E2", f)
	_check(World.new_world(17).personality_enabled, "new_world não ativou E2", f)

func _drives_and_survival(f: Array) -> void:
	var resting := World.new(81, _config())
	var a = _body(resting)
	a.personality.fatigue = 0.95
	var initial: Vector2 = a.pos
	var energy: float = a.energy
	resting.step()
	_check(a.last_action == "rest" and a.personality.fatigue < 0.95 and a.pos == initial and a.energy < energy, "Descanso não recuperou fadiga com custo físico", f)
	var rest_cost: float = energy - a.energy
	var exploring := World.new(81, _config())
	var b = _body(exploring)
	b.personality.boredom = 0.95
	energy = b.energy
	exploring.step()
	_check(b.last_action == "explore" and b.pos != initial and b.personality.boredom < 0.95 and b.personality.fatigue > 0.0, "Explorar não moveu/aliviou tédio/aumentou fadiga", f)
	_check(energy - b.energy > rest_cost, "Descanso não reduziu gasto comparado ao movimento", f)
	print("E2 physical rest_cost=%.6f movement_cost=%.6f fatigue_after_rest=%.6f boredom_after_move=%.6f" % [rest_cost, energy - b.energy, a.personality.fatigue, b.personality.boredom])
	var social := World.new(82, _config())
	var c = _body(social)
	var neighbor = _body(social, Vector2(150, 100))
	neighbor.personality.fatigue = 0.95
	c.personality.loneliness = 0.95
	var distance: float = c.pos.distance_to(neighbor.pos)
	social.step()
	_check(c.last_action == "seek_contact" and c.pos.distance_to(neighbor.pos) < distance, "Drive social não aproximou fisicamente", f)
	for i in range(15):
		social.step()
	_check(c.personality.bonds.has(str(neighbor.id)) and c.personality.loneliness < 0.95 and c.personality.episodes.any(func(e): return e.reward_source == "encounter"), "Contato não aliviou isolamento/registrou encontro", f)
	# Critical needs must override fatigue, social motivation, commands AND a brain.
	var survival := World.new(83, _config())
	var d = _body(survival)
	d.personality.fatigue = 1.0
	d.personality.boredom = 1.0
	d.personality.loneliness = 1.0
	d.energy = 10.0
	d.brain = Q.new()
	d.brain.learning = false
	d.brain.prev_state = 0
	d.brain.prev_action = Actions.REST
	d.brain.prev_energy = 80.0
	survival.comandos.aplicar({"intent": "parar"}, survival)
	survival.place_food(d.pos, "fruta")
	survival.step()
	_check(d.last_action == "eat" and d.energy > 10.0 and d.brain.prev_state == -1 and d.brain.total_reward == 0.0, "Fome não prevaleceu ou creditou reflexo à transição Q", f)
	d.energy = d.max_energy
	d.hydration = 10.0
	survival.place_water(d.pos, 20.0)
	survival.step()
	_check(d.last_action == "drink" and d.hydration > 10.0, "Sede não prevaleceu sobre descanso/ordem/cérebro", f)
	# Without an observable movement, boredom must not be relieved.
	var blocked := World.new(84, _config())
	var e = _body(blocked, Vector2(1192, 100))
	e.personality.boredom = 0.8
	blocked.step()
	_check(e.pos == Vector2(1192, 100) and e.personality.boredom >= 0.8, "Movimento bloqueado aliviou tédio", f)

func _experience_and_conditioning(f: Array) -> void:
	var w := World.new(91, _config())
	var a = _body(w)
	var b = _body(w, Vector2(400, 100))
	_check(a.temperament == b.temperament, "Controle não tem o mesmo temperamento", f)
	# The same food yields positive nutrition when hungry and net toxic loss when full.
	for i in range(8):
		a.energy = 10.0
		b.energy = b.max_energy
		w._eat(a, w.place_food(a.pos, "cogumelo"))
		w._eat(b, w.place_food(b.pos, "cogumelo"))
	_check(float(a.personality.preferences.cogumelo) > float(b.personality.preferences.cogumelo) and float(b.personality.preferences.cogumelo) < -0.8, "Experiências distintas não diferenciaram aversão alimentar", f)
	_check(a.personality.conditioning.has("cogumelo:0:2") and b.personality.conditioning.has("cogumelo:2:2"), "Condicionamento ignorou contexto discretizado", f)
	_check(b.personality.episodes.back().consequence.energy == -8.0 and b.personality.episodes.back().consequence.event == "toxic_food" and b.personality.episodes.back().reward_source == "ingestion", "Memória não mediu dano tóxico/fonte", f)
	# Apply different lifetime experience to otherwise identical current bodies/genes.
	a.energy = 80.0
	b.energy = 80.0
	a.hydration = 100.0
	b.hydration = 100.0
	_check(a.personality.food_weight(a, "cogumelo") > b.personality.food_weight(b, "cogumelo"), "Preferência aprendida não entrou na avaliação alimentar", f)
	var choices_a := {"foods": [{"id": 1, "food_type": "cogumelo", "pos": a.pos + Vector2(5, 0)}, {"id": 2, "food_type": "folha", "pos": a.pos + Vector2(50, 0)}]}
	var choices_b := {"foods": [{"id": 1, "food_type": "cogumelo", "pos": b.pos + Vector2(5, 0)}, {"id": 2, "food_type": "folha", "pos": b.pos + Vector2(50, 0)}]}
	_check(Obs.features(a, choices_a, w.size).food_id == 1 and Obs.features(b, choices_b, w.size).food_id == 2, "Experiência não alterou escolha sob estado/estímulo idênticos", f)
	print("E2 experience mushroom_a=%.6f mushroom_b=%.6f choice_a=%d choice_b=%d" % [a.personality.preferences.cogumelo, b.personality.preferences.cogumelo, Obs.features(a, choices_a, w.size).food_id, Obs.features(b, choices_b, w.size).food_id])
	var before: Dictionary = a.personality.preferences.duplicate()
	var conditioned: Dictionary = a.personality.conditioning.duplicate()
	var sensors := {"foods": [{"food_type": "fruta"}], "signal": {}}
	for i in range(20):
		a.personality.perceive(sensors, i)
	_check(a.personality.preferences == before and a.personality.conditioning == conditioned, "Percepção sem ingestão condicionou recompensa", f)
	var novelty1: float = a.personality.stimulus("player", 20)
	var novelty2 := 1.0
	for i in range(20):
		novelty2 = a.personality.stimulus("player", 20)
	_check(novelty2 < novelty1 * 0.3, "Estímulo repetido não habituou", f)
	for i in range(500):
		a.personality.advance(i + 21, a.temperament)
	_check(a.personality.stimulus("player", 521) > novelty2, "Sensibilidade não recuperou sem estímulo", f)
	# RW has an explicit prediction error and can reverse after new measured outcomes.
	for i in range(20):
		b.energy = 10.0
		w._eat(b, w.place_food(b.pos, "fruta"))
	_check(float(b.personality.preferences.fruta) > 0.6 and b.personality.food_weight(b, "fruta") > b.personality.food_weight(b, "cogumelo"), "Consequência benéfica não produziu preferência relativa", f)
	var food := {"food_type": "cogumelo"}
	var learned_score: float = Obs.food_score(b, food, 10.0)
	b.personality.preferences.cogumelo = 0.0
	b.personality.conditioning.clear()
	_check(learned_score > Obs.food_score(b, food, 10.0), "Heurística/observação não penalizou alimento aversivo", f)

func _bonds_and_expression(f: Array) -> void:
	var w := World.new(101, _config())
	var a = _body(w)
	a.personality.loneliness = 0.8
	var body := [a.energy, a.hydration, a.pos]
	_check(not w.interagir_jogador(a.id, a.pos + Vector2(100, 0)), "Interação distante criou vínculo", f)
	_check(w.interagir_jogador(a.id, a.pos, 0.5), "Contato próximo não foi registrado", f)
	_check(not w.interagir_jogador(a.id, a.pos, 0.5) and a.personality.bonds.player.count == 1, "Cliques no mesmo tick inflaram contagem", f)
	_check(body == [a.energy, a.hydration, a.pos] and a.personality.loneliness < 0.8, "Contato inventou recurso físico ou não aliviou contato", f)
	var happy: Dictionary = a.expression_state()
	a.personality.event_valence = -1.0
	a.energy = 1.0
	a.hydration = 0.0
	var distressed: Dictionary = a.expression_state()
	_check(distressed.valence < happy.valence and distressed.arousal > happy.arousal, "Expressão não deriva de carências/eventos", f)
	a.energy = a.max_energy * 0.8
	a.hydration = 100.0
	var familiarity: float = a.personality.bonds.player.familiarity
	for i in range(100):
		a.personality.advance(i + 1, a.temperament)
	_check(a.personality.bonds.player.familiarity < familiarity and a.personality.bonds.player.valence < 0.1, "Vínculo não decaiu", f)
	var other = _body(w, Vector2(120, 100))
	w.step()
	_check(a.personality.bonds.has(str(other.id)), "Encontro entre criaturas não criou familiaridade", f)
	_check(a.personality.episodes.any(func(e): return e.action == "player_contact" and e.consequence.energy == 0.0), "Interação do jogador não tem evidência episódica", f)

func _memory_limits(f: Array) -> void:
	var p := Personality.new()
	var where := {"energy": 1, "hydration": 2, "food_type": "fruta"}
	for i in range(200):
		p.record(i, where, "rest", -0.05, 0.0, 0.0, "metabolism", "body")
		p.stimulus("zone:%d:0" % i, i)
		p.meet(str(i + 1), i, 0.3)
		_check(p.episodes.size() <= Personality.EPISODE_LIMIT and p.bonds.size() <= Personality.BOND_LIMIT and p.habituation.size() <= Personality.STIMULUS_LIMIT, "Limite individual excedido", f)
	p.record(200, where, "eat", -8.0, 0.0, 0.0, "toxic_food", "ingestion")
	for i in range(201, 250):
		p.record(i, where, "rest", -0.05, 0.0, 0.0, "metabolism", "body")
	_check(p.episodes.any(func(e): return e.consequence.event == "toxic_food"), "Metabolismo descartou memória relevante imediatamente", f)
	p.advance(600, _genes().temperament)
	_check(p.episodes.size() == 1, "Esquecimento por idade/relevância não distinguiu rotina de dano", f)
	p.advance(3000, _genes().temperament)
	_check(p.episodes.is_empty(), "Memória episódica não esqueceu por idade", f)

func _inheritance_and_identity(f: Array) -> void:
	var w := World.new(111, _config())
	var a = _body(w)
	a.personality.boredom = 0.7
	w.interagir_jogador(a.id, a.pos)
	a.energy = 10.0
	w._eat(a, w.place_food(a.pos, "fruta"))
	a.energy = a.max_energy
	a.age = w.min_reproduction_age
	w.reproduction_enabled = true
	w.mutation_rate = 0.0
	var child_id := w.reproduce(a.id)
	_check(child_id != -1, "Descendente de controle não nasceu", f)
	if child_id == -1:
		return
	var child = w.creatures[child_id]
	_check(child.temperament == a.temperament and child.personality != a.personality, "Temperamento não herdou ou estado foi compartilhado", f)
	_check(child.personality.episodes.is_empty() and child.personality.bonds.is_empty() and child.personality.preferences.is_empty() and child.personality.conditioning.is_empty() and child.personality.habituation.is_empty() and child.personality.boredom == 0.0, "Descendente herdou memória/aprendizado/vínculo/drive", f)
	for random_seed in [7, 83, 20261101]:
		var inherited: Dictionary = Inheritance.inherit(a.genome, a.id, Rng.new(random_seed), 1.0, 0.025)
		for disposition in Genes.TEMPERAMENT_KEYS:
			var value: float = inherited.genome.temperament[disposition]
			_check(value >= 0.0 and value <= 1.0 and absf(value - float(a.temperament[disposition])) <= 0.075001, "Mutação do temperamento excedeu 3 sigma/limites", f)
	var old_id: int = a.id
	a.alive = false
	w.step()
	_check(w.pet_id == -1 and not w.creatures.has(old_id), "Pet morto foi substituído por descendente", f)
	var newcomer: int = w.spawn_creature(Vector2(500, 400))
	_check(newcomer != -1 and w.pet_id == -1, "Introdução mudou identidade do pet morto", f)
	var loaded := World.from_dict(JSON.parse_string(_snapshot(w)))
	_check(loaded != null and loaded.pet_id == -1 and loaded.genealogy.records[old_id].death_tick >= 0, "Morte/identidade não persistiu", f)

func _round_trip(f: Array) -> void:
	var w := World.new_world(9181)
	var pet = w.creatures[w.pet_id]
	w.interagir_jogador(pet.id, pet.pos, 0.4)
	pet.brain = Q.new()
	for i in range(120):
		w.step()
	_check(pet.brain.steps > 0, "Camada E2 impediu toda decisão do cérebro", f)
	var snapshot := _snapshot(w)
	var restored := World.from_dict(JSON.parse_string(snapshot))
	_check(restored != null and _snapshot(restored) == snapshot, "E2 round trip perdeu drives/episódios/vínculos/aprendizado", f)
	if restored == null:
		return
	for i in range(200):
		w.step()
		restored.step()
		if _snapshot(w) != _snapshot(restored):
			f.append("Sequência determinista E2 divergiu após carregar no passo %d" % i)
			break
	var directory := "user://e2_test_" + str(OS.get_process_id())
	var store := Store.new(directory)
	var saved: Dictionary = store.save_world(w)
	var loaded: Dictionary = store.load_world()
	_check(saved.ok and loaded.ok and _snapshot(loaded.world) == _snapshot(w), "Checkpoint E2 falhou", f)
	DirAccess.remove_absolute(directory + "/world.json")
	DirAccess.remove_absolute(directory)

## Identical bodies, drives, geometry and stimulus; only each founder's temperament varies.
## Each profile is tested in an independent scene to remove crowd/order effects.
func _profiles(f: Array) -> void:
	for random_seed in [17, 89, 9181, 20261101]:
		var founders := World.new_world(random_seed)
		var unique: Dictionary = {}
		var actions: Dictionary = {}
		var first: Array = []
		for founder in founders.creatures.values():
			unique[JSON.stringify(founder.temperament)] = true
			first.append(_profile_action(founder.temperament))
		for action in first:
			actions[action] = int(actions.get(action, 0)) + 1
		_check(unique.size() == 12 and first.size() == 12 and actions.size() >= 2, "12 perfis não diferenciaram ação sob mesmo estímulo, seed %d" % random_seed, f)
		var replay: Array = []
		var neutral: Dictionary = {}
		for founder in founders.creatures.values():
			replay.append(_profile_action(founder.temperament))
			neutral[_profile_action(_genes().temperament)] = true
		_check(first == replay and neutral.size() == 1, "Diferenciação não determinista ou ablação neutra varia", f)
		print("E2 profiles seed=%d unique=%d actions=%s neutral_actions=%d" % [random_seed, unique.size(), JSON.stringify(actions), neutral.size()])

func _profile_action(traits: Dictionary) -> String:
	var w := World.new(540, _config())
	var genes := _genes()
	genes.temperament = traits.duplicate()
	var a = _body(w, Vector2(100, 100), genes)
	_body(w, Vector2(180, 100))
	a.personality.fatigue = 0.65
	a.personality.boredom = 0.65
	a.personality.loneliness = 0.65
	w.step()
	return a.last_action

func _invalid(f: Array) -> void:
	var w := World.new(121, _config())
	var a = _body(w)
	w.interagir_jogador(a.id, a.pos)
	w.step()
	var saved := w.to_dict()
	for field in ["fatigue", "boredom", "loneliness", "event_valence"]:
		for value in [NAN, INF, -INF, "0.5", true, null, [], {}, 1.1]:
			var bad := saved.duplicate(true)
			bad.creatures[0].personality[field] = value
			_check(World.from_dict(bad) == null, "Estado E2 inválido aceito: " + field, f)
	for field in ["episodes", "preferences", "conditioning", "habituation", "bonds"]:
		var bad := saved.duplicate(true)
		bad.creatures[0].personality[field] = null
		_check(World.from_dict(bad) == null, "Container E2 inválido aceito: " + field, f)
	for value in [NAN, INF, -0.1, 1.1, "0.2", true, null]:
		var bad := saved.duplicate(true)
		bad.creatures[0].genome.temperament.curiosity = value
		_check(World.from_dict(bad) == null, "Temperamento inválido aceito", f)
	var bad := saved.duplicate(true)
	bad.config.personality_enabled = "true"
	_check(World.from_dict(bad) == null, "Flag E2 não booleana aceita", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.episodes[0].tick = w.tick + 1
	_check(World.from_dict(bad) == null, "Memória episódica futura aceita", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.episodes[0].consequence.energy = NAN
	_check(World.from_dict(bad) == null, "NaN em consequência aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.episodes[0].context.energy = 3
	_check(World.from_dict(bad) == null, "Contexto fora dos buckets aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.episodes.resize(Personality.EPISODE_LIMIT + 1)
	_check(World.from_dict(bad) == null, "Buffer episódico grande aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.bonds[str(a.id)] = bad.creatures[0].personality.bonds.player
	_check(World.from_dict(bad) == null, "Vínculo consigo mesmo aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.bonds.player.count = 10001
	_check(World.from_dict(bad) == null, "Contagem de encontros ilimitada aceita", f)
	bad = saved.duplicate(true)
	bad.config.personality_enabled = false
	_check(World.from_dict(bad) == null, "Save inconsistente com flag E2 desligada aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.preferences.fruta = NAN
	_check(World.from_dict(bad) == null, "NaN em preferência aceito", f)
	bad = saved.duplicate(true)
	bad.creatures[0].personality.conditioning["fruta:9:0"] = 0.5
	_check(World.from_dict(bad) == null, "Condicionamento sem contexto válido aceito", f)
