extends RefCounted
## Bounded, per-creature state, with its own persisted seeded RNG.
const Data = preload("res://scripts/core/sim_data.gd")
const Affect = preload("res://scripts/mind/affect.gd")
const Motivation = preload("res://scripts/mind/motivation.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Social = preload("res://scripts/social/social_dynamics.gd")
const LOG_LIMIT := 48
const MEMORY_LIMIT := 32
const MEMORY_TTL := 2400
const MEMORY_KINDS := ["contact", "food", "water", "blocked", "toxic"]
const REASONS := ["mind.disabled", "mind.score", "mind.timeout", "mind.urgency"]
var affect = Affect.new()
var affect_enabled := true
var memory_enabled := true
var policy_mode := "full"
var objetivo_atual := ""
var motivo := "mind.disabled"
var goal_started := 0
var pontuacoes: Dictionary = {}
var mind_log: Array = []
var experiences: Array = []
var objects: Dictionary = {} # reserved M2 stub, must remain empty
var blocked_ticks := 0
var contact_ticks := 0
var absent_ticks := 0
var rng = Rng.new()

func _init(mind_seed: int = 1) -> void:
	rng = Rng.new(mind_seed)

func empty_affect() -> Dictionary:
	return Affect.new().values

func traits(creature) -> Dictionary:
	if policy_mode == "fixed" or creature.temperament.is_empty():
		return {"curiosity": 0.5, "caution": 0.5, "sociability": 0.5, "impulsivity": 0.5}
	return creature.temperament

func set_goal(goal: String, tick: int, reason: String) -> void:
	if objetivo_atual == goal:
		if reason == "mind.urgency":
			motivo = reason
		return
	objetivo_atual = goal
	goal_started = tick
	motivo = reason
	mind_log.append({"tick": tick, "objetivo": goal, "pontuacoes": pontuacoes.duplicate(true), "motivo": reason})
	if mind_log.size() > LOG_LIMIT:
		mind_log.pop_front()

func decide(creature, tick: int, sensors: Dictionary) -> String:
	return Motivation.choose(creature, self, tick, sensors)

func remember(tick: int, kind: String, valence: float, importance: float, source: int = 0) -> void:
	# Ablation removes retrieval/encoding, not actual bodily experience.
	if not memory_enabled or policy_mode != "full":
		return
	experiences.append({"tick": tick, "kind": kind, "valence": snappedf(clampf(valence, -1.0, 1.0), 0.000001), "importance": snappedf(clampf(importance, 0.0, 1.0), 0.000001), "source": source})
	if experiences.size() > MEMORY_LIMIT:
		experiences.pop_front()

## Retrieval score = recency + contextual relevance + importance.
## Top three episodes vote, preserving signed consequences rather than counts.
func memory_bias(goal: String, tick: int, sensors: Dictionary) -> float:
	if not memory_enabled or policy_mode != "full":
		return 0.0
	var selected: Array = []
	for row in experiences:
		if tick - int(row.tick) > MEMORY_TTL:
			continue
		var relevant: bool = (row.kind == "contact" and goal in ["buscar_companhia", "buscar_privacidade"]) or (row.kind == "food" and goal == "comer") or (row.kind == "water" and goal == "beber") or (row.kind == "blocked" and goal in ["explorar", "descansar"])
		if not relevant:
			continue
		var relevance := 0.5
		for other in sensors.get("creatures", []):
			if int(other.id) == int(row.source):
				relevance = 1.0
		var retrieval := 1.0 / (1.0 + maxf(0.0, float(tick - int(row.tick))) / 300.0) + relevance + float(row.importance)
		selected.append({"score": retrieval, "valence": float(row.valence)})
	selected.sort_custom(func(a, b): return a.score > b.score)
	var weighted := 0.0
	var total := 0.0
	for i in range(mini(3, selected.size())):
		weighted += float(selected[i].score) * float(selected[i].valence)
		total += float(selected[i].score)
	var sign_bias := -1.0 if goal in ["buscar_privacidade", "descansar"] else 1.0
	return snappedf(sign_bias * 0.65 * weighted / maxf(1.0, total), 0.000001)

func consequence(creature, tick: int, kind: String, value: float, source: int = 0) -> void:
	var t := traits(creature)
	match kind:
		"food", "water":
			if value > 0.0:
				remember(tick, kind, minf(1.0, value / 30.0), 0.7, source)
				if affect_enabled:
					affect.change(tick, "satisfacao", minf(0.35, value / 100.0), "need_satisfied", t)
		"toxic":
			remember(tick, kind, -1.0, 1.0, source)
			if affect_enabled:
				affect.change(tick, "receio", 0.25, "toxic_exposure", t)
		"blocked":
			blocked_ticks = mini(10000, blocked_ticks + 1)
			if blocked_ticks >= 2:
				if blocked_ticks % 12 == 2:
					remember(tick, kind, -0.6, 0.6)
				if affect_enabled:
					affect.change(tick, "frustracao", 0.055, "blocked_motion", t)

func observe(world, creature, sensors: Dictionary, moving: bool) -> void:
	var t := traits(creature)
	# Decay is not spontaneous emotion generation: zero remains zero.
	if affect_enabled:
		affect.decay(world.tick, t)
	if moving:
		blocked_ticks = 0
		if affect_enabled:
			affect.change(world.tick, "frustracao", -0.025, "free_movement", t)
	var contact := false
	for row in sensors.get("creatures", []):
		var other = world.creatures.get(int(row.id))
		if other == null or not other.alive or creature.pos.distance_to(other.pos) > creature.genome.size + other.genome.size + 8.0 or world._occluded(creature.pos, other.pos):
			continue
		contact = true
		var contested: bool = not Social.contested(creature, other, sensors).is_empty() and creature.hunger > 0.2 and other.hunger > 0.2
		var valence := -0.8 if contested else 0.5
		if contact_ticks % 30 == 0:
			remember(world.tick, "contact", valence, 0.9, other.id)
		if affect_enabled:
			affect.change(world.tick, "solidao", -0.035, "contact", t)
			if contested:
				affect.change(world.tick, "receio", 0.035, "adverse_contact", t)
			else:
				affect.change(world.tick, "entusiasmo", 0.008, "contact", t)
	contact_ticks = mini(10000, contact_ticks + 1) if contact else 0
	absent_ticks = 0 if contact else mini(10000, absent_ticks + 1)
	if affect_enabled:
		if contact_ticks >= 20:
			affect.change(world.tick, "saturacao_social", 0.014, "prolonged_contact", t)
		if absent_ticks >= 30:
			affect.change(world.tick, "solidao", 0.012, "absence_of_contact", t)
		if creature.last_action == "rest" and blocked_ticks == 0 and float(affect.values.receio) < 0.2 and creature.hunger < 0.55:
			affect.change(world.tick, "tranquilidade", 0.012, "safe_rest", t)
	while not experiences.is_empty() and world.tick - int(experiences[0].tick) > MEMORY_TTL:
		experiences.pop_front()

func expression(base: Dictionary) -> Dictionary:
	if not affect_enabled or policy_mode != "full":
		return base.duplicate(true)
	var a: Dictionary = affect.values
	return {"valence": snappedf(clampf(float(base.valence) + float(a.satisfacao) * 0.35 + float(a.tranquilidade) * 0.25 - float(a.frustracao) * 0.55 - float(a.receio) * 0.4 - float(a.solidao) * 0.2, -1.0, 1.0), 0.000001),
		"arousal": snappedf(clampf(float(base.arousal) + float(a.entusiasmo) * 0.3 + float(a.receio) * 0.3 + float(a.frustracao) * 0.25 - float(a.tranquilidade) * 0.2, 0.0, 1.0), 0.000001)}

func snapshot(base: Dictionary) -> Dictionary:
	return {"afetos": affect.values.duplicate(true) if affect_enabled else empty_affect(), "objetivo_atual": objetivo_atual, "motivo": motivo, "ultimos_logs": mind_log.duplicate(true), "expressao": expression(base), "cause_log": affect.cause_log.duplicate(true), "pontuacoes": pontuacoes.duplicate(true), "affect_enabled": affect_enabled, "memory_enabled": memory_enabled}

func to_dict() -> Dictionary:
	return Data.restore_precision({"affect": affect.to_dict(), "affect_enabled": affect_enabled, "memory_enabled": memory_enabled, "policy_mode": policy_mode,
		"objetivo_atual": objetivo_atual, "motivo": motivo, "goal_started": goal_started, "pontuacoes": pontuacoes,
		"mind_log": mind_log, "experiences": experiences, "objects": objects, "blocked_ticks": blocked_ticks, "contact_ticks": contact_ticks, "absent_ticks": absent_ticks, "rng_state": rng.to_dict()})

static func valid_scores(value: Variant) -> bool:
	if not value is Dictionary or value.size() not in [0, Motivation.GOALS.size()]:
		return false
	for key in value:
		if key not in Motivation.GOALS or not Data.number(value[key]) or absf(float(value[key])) > 20.0:
			return false
	return true

static func from_dict(data: Variant, max_tick: int = 2147483647):
	if not data is Dictionary or data.size() != 15 or not Data.json_data(data):
		return null
	if not data.get("affect_enabled") is bool or not data.get("memory_enabled") is bool or data.get("policy_mode") not in ["full", "random", "fixed"] or data.get("objetivo_atual") not in Motivation.GOALS + [""] or data.get("motivo") not in REASONS:
		return null
	if not Data.integer(data.get("goal_started")) or int(data["goal_started"]) > max_tick or not valid_scores(data.get("pontuacoes")):
		return null
	for key in ["blocked_ticks", "contact_ticks", "absent_ticks"]:
		if not Data.integer(data.get(key)) or int(data[key]) > 10000:
			return null
	if not data.get("objects") is Dictionary or not data["objects"].is_empty() or not data.get("rng_state") is Dictionary or data["rng_state"].size() != 1 or not Data.integer_text(data["rng_state"].get("state")):
		return null
	if not data.get("mind_log") is Array or data["mind_log"].size() > LOG_LIMIT or not data.get("experiences") is Array or data["experiences"].size() > MEMORY_LIMIT:
		return null
	var previous := -1
	for row in data["mind_log"]:
		if not row is Dictionary or row.size() != 4 or not Data.integer(row.get("tick")) or int(row["tick"]) < previous or int(row["tick"]) > max_tick or row.get("objetivo") not in Motivation.GOALS or row.get("motivo") not in REASONS or not valid_scores(row.get("pontuacoes")):
			return null
		previous = int(row["tick"])
	previous = -1
	for row in data["experiences"]:
		if not row is Dictionary or row.size() != 5 or not Data.integer(row.get("tick")) or int(row["tick"]) < previous or int(row["tick"]) > max_tick or row.get("kind") not in MEMORY_KINDS or not Data.number(row.get("valence")) or absf(float(row["valence"])) > 1.0 or not Data.number(row.get("importance")) or float(row["importance"]) < 0.0 or float(row["importance"]) > 1.0 or not Data.integer(row.get("source")):
			return null
		previous = int(row["tick"])
	var loaded_affect = Affect.from_dict(data.get("affect"), max_tick)
	if loaded_affect == null:
		return null
	var result = load("res://scripts/mind/creature_mind.gd").new()
	for key in data:
		if key not in ["affect", "rng_state"]:
			result.set(key, Data.restore_precision(data[key]))
	result.affect = loaded_affect
	result.rng.restore(data["rng_state"])
	return result
