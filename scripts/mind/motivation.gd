extends RefCounted
## Retrieval affects utility; affect controls activation and commitment thresholds.
## Both channels are deterministic and independently ablatable; no physical writes.
const GOALS := ["comer", "beber", "descansar", "explorar", "buscar_companhia", "buscar_privacidade", "brincar", "investigar_objeto"]
const MIN_COMMITMENT := 12
const MAX_COMMITMENT := 80

static func modulation(mind) -> Dictionary:
	var a: Dictionary = mind.affect.values if mind.affect_enabled and mind.policy_mode == "full" else mind.empty_affect()
	var frustration := float(a.frustracao)
	# Commitment shortening concerns the currently obstructed locomotor strategy.
	var blocked: bool = mind.blocked_ticks >= 2 and mind.objetivo_atual in ["explorar", "brincar", "buscar_companhia", "buscar_privacidade"]
	return {"minimum": maxi(2, MIN_COMMITMENT - int(10.0 * frustration)) if blocked else MIN_COMMITMENT,
		"maximum": maxi(12, MAX_COMMITMENT - int(68.0 * frustration)) if blocked else MAX_COMMITMENT,
		"release_blocked": blocked and frustration >= 0.25,
		"hysteresis": snappedf(0.08 * (1.0 - frustration) + float(a.receio) * 0.06, 0.000001),
		"thresholds": {
			"comer": 0.0, "beber": 0.0,
			"descansar": -0.35 * frustration - 0.35 * float(a.satisfacao) - 0.3 * float(a.receio) - 0.15 * float(a.tranquilidade),
			"explorar": 0.35 * frustration + 0.55 * float(a.receio) + 0.5 * float(a.satisfacao) - 0.3 * float(a.entusiasmo),
			"buscar_companhia": 1.4 * float(a.saturacao_social) + 0.5 * float(a.receio) - 1.2 * float(a.solidao),
			"buscar_privacidade": -1.4 * float(a.saturacao_social) - 0.8 * float(a.receio),
			"brincar": 0.5 * frustration + 0.4 * float(a.satisfacao) - 0.4 * float(a.entusiasmo),
			"investigar_objeto": 0.0}}

static func utilities(creature, mind, tick: int, sensors: Dictionary) -> Dictionary:
	var t: Dictionary = mind.traits(creature)
	var fatigue: float = creature.personality.fatigue if creature.personality != null else 0.0
	var result := {
		"comer": creature.hunger * 1.8,
		"beber": creature.thirst * 1.8 if creature.personality_water_enabled else -4.0,
		"descansar": fatigue * 1.4 + float(t.caution) * 0.12,
		"explorar": 0.22 + float(t.curiosity) * 0.25,
		"buscar_companhia": 0.1 + float(t.sociability) * 0.35,
		"buscar_privacidade": float(t.caution) * 0.35,
		"brincar": 0.15 + float(t.impulsivity) * 0.2,
		"investigar_objeto": -4.0}
	for goal in GOALS:
		result[goal] = snappedf(float(result[goal]) + mind.memory_bias(goal, tick, sensors) + mind.rng.between(-0.045, 0.045), 0.000001)
	return result

static func scores(creature, mind, tick: int, sensors: Dictionary) -> Dictionary:
	var result := utilities(creature, mind, tick, sensors)
	var thresholds: Dictionary = modulation(mind).thresholds
	for goal in GOALS:
		result[goal] = snappedf(float(result[goal]) - float(thresholds[goal]), 0.000001)
	if sensors.get("creatures", []).is_empty():
		result.buscar_privacidade = -4.0
	return result

static func choose(creature, mind, tick: int, sensors: Dictionary) -> String:
	var scores_now := scores(creature, mind, tick, sensors)
	mind.pontuacoes = scores_now
	var critical := ""
	if creature.hunger > 0.55 or (creature.personality_water_enabled and creature.thirst > 0.55):
		critical = "beber" if creature.personality_water_enabled and creature.thirst > 0.55 and creature.thirst >= creature.hunger else "comer"
	var elapsed: int = tick - mind.goal_started
	if critical != "":
		mind.set_goal(critical, tick, "mind.urgency")
		return critical
	var control := modulation(mind)
	var release: bool = control.release_blocked
	if mind.objetivo_atual != "" and elapsed < int(control.minimum) and not release:
		return mind.objetivo_atual
	var timeout: bool = mind.objetivo_atual != "" and elapsed >= int(control.maximum)
	var winner := ""
	var highest := -INF
	for goal in GOALS:
		if goal == "investigar_objeto" or (goal == "beber" and not creature.personality_water_enabled) or (goal == "buscar_privacidade" and sensors.get("creatures", []).is_empty()):
			continue
		if (timeout or release) and goal == mind.objetivo_atual:
			continue
		var score: float = scores_now[goal]
		if mind.policy_mode == "random":
			score = mind.rng.between(0.0, 1.0)
			mind.pontuacoes[goal] = snappedf(score, 0.000001)
		if score > highest:
			highest = score
			winner = goal
	if not timeout and not release and mind.policy_mode != "random" and mind.objetivo_atual != "" and highest < float(scores_now[mind.objetivo_atual]) + float(control.hysteresis):
		return mind.objetivo_atual
	mind.set_goal(winner, tick, "mind.timeout" if timeout else "mind.score")
	return mind.objetivo_atual
