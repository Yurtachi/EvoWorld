extends RefCounted
## Scores endogenous goals. No physical writes and no external model/network.
const GOALS := ["comer", "beber", "descansar", "explorar", "buscar_companhia", "buscar_privacidade", "brincar", "investigar_objeto"]
const MIN_COMMITMENT := 12
const MAX_COMMITMENT := 80

static func scores(creature, mind, tick: int, sensors: Dictionary) -> Dictionary:
	var t: Dictionary = mind.traits(creature)
	var a: Dictionary = mind.affect.values if mind.affect_enabled and mind.policy_mode == "full" else mind.empty_affect()
	var fatigue: float = creature.personality.fatigue if creature.personality != null else 0.0
	var result := {
		"comer": creature.hunger * 1.8,
		"beber": creature.thirst * 1.8 if creature.personality_water_enabled else -4.0,
		"descansar": fatigue * 1.4 + float(t.caution) * 0.12 + float(a.frustracao) * 0.8 + float(a.tranquilidade) * 0.15,
		"explorar": 0.22 + float(t.curiosity) * 0.25 + float(a.entusiasmo) * 0.3 - float(a.frustracao) * 0.35 - float(a.receio) * 0.3,
		"buscar_companhia": 0.1 + float(t.sociability) * 0.35 + float(a.solidao) * 0.85 + float(a.satisfacao) * 0.15 - float(a.saturacao_social) * 0.9 - float(a.receio) * 0.5,
		"buscar_privacidade": float(t.caution) * 0.35 + float(a.saturacao_social) * 0.9 + float(a.receio) * 0.8,
		"brincar": 0.15 + float(t.impulsivity) * 0.2 + float(a.entusiasmo) * 0.4 - float(a.frustracao) * 0.5,
		"investigar_objeto": -4.0 # M2 stub: no invented objects or actions.
	}
	for goal in GOALS:
		result[goal] = snappedf(float(result[goal]) + mind.memory_bias(goal, tick, sensors) + mind.rng.between(-0.045, 0.045), 0.000001)
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
	if mind.objetivo_atual != "" and elapsed < MIN_COMMITMENT:
		return mind.objetivo_atual
	var timeout: bool = mind.objetivo_atual != "" and elapsed >= MAX_COMMITMENT
	var winner := ""
	var highest := -INF
	for goal in GOALS:
		if goal == "investigar_objeto" or (goal == "beber" and not creature.personality_water_enabled) or (goal == "buscar_privacidade" and sensors.get("creatures", []).is_empty()):
			continue
		if timeout and goal == mind.objetivo_atual:
			continue
		var score: float = scores_now[goal]
		if mind.policy_mode == "random":
			score = mind.rng.between(0.0, 1.0)
			mind.pontuacoes[goal] = snappedf(score, 0.000001)
		if score > highest:
			highest = score
			winner = goal
	# A small hysteresis protects the goal beyond its minimum commitment.
	if not timeout and mind.policy_mode != "random" and mind.objetivo_atual != "" and highest < float(scores_now[mind.objetivo_atual]) + 0.08:
		return mind.objetivo_atual
	mind.set_goal(winner, tick, "mind.timeout" if timeout else "mind.score")
	return mind.objetivo_atual
