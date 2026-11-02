extends RefCounted
## Retrieval affects utility; affect controls activation and commitment thresholds.
## Both channels are deterministic and independently ablatable; no physical writes.
const BASE_GOALS := ["comer", "beber", "descansar", "explorar", "buscar_companhia", "buscar_privacidade", "brincar", "investigar_objeto"]
const GOALS := ["comer", "beber", "descansar", "explorar", "buscar_companhia", "buscar_privacidade", "brincar", "investigar_objeto", "desenhar", "ler", "usar_terminal"]
const MIN_COMMITMENT := 12
const MAX_COMMITMENT := 80
const Objects = preload("res://scripts/mind/object_memory.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")

static func modulation(mind) -> Dictionary:
	var a: Dictionary = mind.affect.values if mind.affect_enabled and mind.policy_mode == "full" else mind.empty_affect()
	var frustration := float(a.frustracao)
	# Commitment shortening concerns the currently obstructed locomotor strategy.
	var blocked: bool = mind.blocked_ticks >= 2 and mind.objetivo_atual in ["explorar", "brincar", "buscar_companhia", "buscar_privacidade", "desenhar"]
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
			"investigar_objeto": 0.0, "ler": 0.0, "usar_terminal": 0.0,
			"desenhar": 0.25 * frustration + 0.35 * float(a.receio) - 0.35 * float(a.entusiasmo)}}

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
	if not sensors.get("objects", []).is_empty():
		result.investigar_objeto = Objects.candidate(mind, creature, sensors, tick).score
	for goal in BASE_GOALS:
		result[goal] = snappedf(float(result[goal]) + mind.memory_bias(goal, tick, sensors) + mind.rng.between(-0.045, 0.045), 0.000001)
	if not sensors.get("boards", []).is_empty() or mind.objetivo_atual == "desenhar":
		var board_cand := Atelier.candidate(mind, creature, sensors, tick)
		result["desenhar"] = snappedf(float(board_cand.score) + mind.rng.between(-0.045, 0.045), 0.000001)
	if not sensors.get("books", []).is_empty() or mind.objetivo_atual == "ler":
		result["ler"] = mind.Reading.candidate(mind, creature, sensors).score
	if not sensors.get("terminals", []).is_empty() or mind.objetivo_atual == "usar_terminal":
		result["usar_terminal"] = mind.TerminalLearning.candidate(mind, creature, sensors, tick).score
	return result

static func scores(creature, mind, tick: int, sensors: Dictionary) -> Dictionary:
	var result := utilities(creature, mind, tick, sensors)
	var thresholds: Dictionary = modulation(mind).thresholds
	for goal in result.keys():
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
	var reading: Dictionary = mind.Reading.candidate(mind, creature, sensors) if scores_now.has("ler") else {"id": 0}
	var terminal_candidate: Dictionary = mind.TerminalLearning.candidate(mind, creature, sensors, tick) if scores_now.has("usar_terminal") else {"id": 0}
	var control := modulation(mind)
	var release: bool = control.release_blocked or (mind.objetivo_atual == "ler" and int(reading.id) == 0)
	if mind.objetivo_atual == "usar_terminal" and int(terminal_candidate.id) == 0: release = true
	var object_candidate := Objects.candidate(mind, creature, sensors, tick)
	var has_boards: bool = scores_now.has("desenhar")
	var board_candidate: Dictionary = Atelier.candidate(mind, creature, sensors, tick) if has_boards else {"score": -4.0, "id": 0, "novelty": 0.0}
	if mind.objetivo_atual == "investigar_objeto" and int(object_candidate.id) == 0:
		release = true
	if mind.objetivo_atual == "desenhar" and int(board_candidate.id) == 0:
		release = true
	if mind.objetivo_atual != "" and elapsed < int(control.minimum) and not release:
		return mind.objetivo_atual
	var timeout: bool = mind.objetivo_atual != "" and elapsed >= int(control.maximum)
	var winner := ""
	var highest := -INF
	for goal in scores_now.keys():
		if goal == "usar_terminal" and int(terminal_candidate.id) == 0: continue
		if (goal == "ler" and int(reading.id) == 0) or (goal == "investigar_objeto" and int(object_candidate.id) == 0) or (goal == "desenhar" and int(board_candidate.id) == 0) or (goal == "beber" and not creature.personality_water_enabled) or (goal == "buscar_privacidade" and sensors.get("creatures", []).is_empty()):
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
	var reason := "mind.timeout" if timeout else "mind.score"
	if winner == "investigar_objeto":
		Objects.state(mind).target = int(object_candidate.id)
		reason = "mind.iniciativa.novidade" if float(object_candidate.novelty) > 0.7 else "mind.iniciativa.lacuna"
	elif winner == "ler":
		reason = "mind.iniciativa.ler"
	elif winner == "usar_terminal":
		reason = "mind.iniciativa.terminal"
	elif winner == "desenhar":
		Objects.state(mind).target = int(board_candidate.id)
		reason = "mind.iniciativa.desenhar"
	elif mind.objetivo_atual in ["investigar_objeto", "desenhar"] and timeout:
		var state := Objects.state(mind)
		var key := str(state.target)
		if state.cooldowns.size() >= Objects.LIMIT: state.cooldowns.erase(state.cooldowns.keys()[0])
		state.cooldowns[key] = tick + 180
		if state.entries.has(key): state.entries[key].retry_tick = tick + 180
	mind.set_goal(winner, tick, reason)
	return mind.objetivo_atual
