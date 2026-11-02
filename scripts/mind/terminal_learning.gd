extends RefCounted
## Data-only policy. The physical executor alone changes body and world objects.
const Data = preload("res://scripts/core/sim_data.gd")
const State = preload("res://scripts/terminal/terminal_estado.gd")
const Parser = preload("res://scripts/terminal/terminal_parser.gd")
const Policy = preload("res://scripts/terminal/terminal_politica.gd")
const LIMIT := 32
const TASKS := ["marcar_mover", "desenhar"]

static func empty() -> Dictionary:
	return {"state": State.new().to_dict(), "enabled": true, "refusal_until": 0,
		"cooldown": 0, "last_tick": -1, "task": {"kind": "marcar_mover", "target": [3, 0]},
		"active": {}, "table": {}, "outcomes": []}

static func state(mind) -> Dictionary:
	if mind.terminal.is_empty(): mind.terminal = empty()
	return mind.terminal

static func candidate(mind, creature, sensors: Dictionary, tick: int) -> Dictionary:
	var best := {"id": 0, "score": -4.0}
	# No allocation/RNG consumption in worlds without a terminal.
	if sensors.get("terminals", []).is_empty(): return best
	var s := state(mind)
	if not s.enabled or tick < int(s.refusal_until) or tick < int(s.cooldown): return best
	var curiosity: float = mind.traits(creature).curiosity
	var boredom: float = creature.personality.boredom if creature.personality != null else 0.0
	if curiosity < 0.15 and boredom < 0.5: return best
	var gap := 1.0 if s.state.conhecidos.size() < 5 else 0.0
	var nearest := INF
	for row in sensors.terminals:
		var distance: float = creature.pos.distance_squared_to(row.pos)
		if distance < nearest:
			nearest = distance
			best = {"id": row.id, "score": 0.55 + curiosity * 0.7 + boredom * 0.3 + gap * 0.2}
	return best

static func instructions(program: String, known: Dictionary) -> Array:
	if not State.valid_program(program) or not State.valid(known): return []
	var parsed := Parser.new().parse(program)
	if not Policy._known(parsed.ast, State.from_dict(known)): return []
	var out: Array = []
	_flatten(parsed.ast, out)
	return out

static func _flatten(ast: Array, out: Array) -> void:
	for node in ast:
		if node.comando == "REPETIR":
			for i in range(int(node.args[0])): _flatten(node.corpo, out)
		else:
			var line: String = node.comando
			for arg in node.args: line += " " + str(arg)
			out.append(line)

static func candidates(s: Dictionary) -> Array:
	var out: Array = ["OLHAR"]
	var known: Dictionary = s.state.conhecidos
	if known.size() < 5: out.push_front("AJUDA")
	var target := Vector2i(int(s.task.target[0]), int(s.task.target[1]))
	var mark := "MARCAR %d %d" % [target.x, target.y]
	var direction := "LESTE" if target.x >= 0 else "OESTE"
	if absi(target.y) > absi(target.x): direction = "SUL" if target.y >= 0 else "NORTE"
	var move := "MOVER %s %d" % [direction, clampi(maxi(absi(target.x), absi(target.y)), 1, 8)]
	if known.has("MARCAR"): out.append(mark)
	if known.has("MOVER"):
		out.append(move)
		out.append("MOVER NORTE 1")
	if known.has("MARCAR") and known.has("MOVER"):
		# A geometric template is explicit prior knowledge, not learned grammar.
		out.append(mark + "\n" + move + "\n" + move)
		out.append(mark + "\n" + move)
		out.append(move + "\n" + mark)
	if known.has("DESENHAR"):
		out.append("DESENHAR LINHA")
		if known.has("REPETIR"): out.append("REPETIR 7 { DESENHAR LINHA }")
	return out

static func key(s: Dictionary, program: String) -> String:
	# Transfer action structure, not the old literal coordinate, across targets.
	var parsed := Parser.new().parse(program)
	var names: Array = []
	for node in parsed.ast: names.append(node.comando)
	return str(s.task.kind) + ":" + ",".join(names)

static func score(s: Dictionary, program: String) -> float:
	var row: Dictionary = s.table.get(key(s, program), {"n": 0, "sucessos": 0})
	return (float(row.sucessos) + 1.0) / (float(row.n) + 2.0) + 0.2 / sqrt(float(row.n) + 1.0)

static func choose(s: Dictionary) -> String:
	var best := ""
	var highest := -1.0
	for program in candidates(s):
		var value := score(s, program)
		if value > highest:
			highest = value
			best = program
	return best

static func feedback(s: Dictionary, program: String, success: bool, error: String, tick: int, memory: bool = true) -> void:
	s.outcomes.append({"program": program, "goal": s.task.kind, "success": success, "error": error, "tick": tick})
	if s.outcomes.size() > 48: s.outcomes.pop_front()
	if not memory: return
	var k := key(s, program)
	if not s.table.has(k):
		if s.table.size() >= LIMIT:
			var keys: Array = s.table.keys()
			keys.sort()
			s.table.erase(keys[0])
		s.table[k] = {"n": 0, "sucessos": 0}
	var row: Dictionary = s.table[k]
	if int(row.n) < 10000:
		row.n += 1
		row.sucessos += 1 if success else 0

static func valid_task(task: Variant) -> bool:
	return task is Dictionary and task.size() == 2 and task.get("kind") in TASKS and Data.vector(task.get("target")) and Data.integer(task.target[0], -64) and Data.integer(task.target[1], -64) and absf(task.target[0]) <= 64 and absf(task.target[1]) <= 64

static func valid(s: Variant, tick: int) -> bool:
	if not s is Dictionary: return false
	if s.is_empty(): return true
	if s.size() != 9 or not State.valid(s.get("state")) or not s.get("enabled") is bool or not valid_task(s.get("task")): return false
	for field in ["refusal_until", "cooldown"]:
		if not Data.integer(s.get(field)) or int(s[field]) > tick + 10000: return false
	if not Data.integer(s.get("last_tick"), -1) or int(s.last_tick) > tick: return false
	var previous := -1
	for row in s.state.tentativas:
		if int(row.tick) > tick or int(row.tick) < previous: return false
		previous = int(row.tick)
	if not s.get("table") is Dictionary or s.table.size() > LIMIT: return false
	for k in s.table:
		if not k is String or k.length() > 128: return false
		var parts: PackedStringArray = k.split(":")
		if parts.size() != 2 or parts[0] not in TASKS: return false
		var names: PackedStringArray = parts[1].split(",")
		if names.size() > 8: return false
		for command in names:
			if command not in s.state.conhecidos: return false
		var row = s.table[k]
		if not row is Dictionary or row.size() != 2 or not Data.integer(row.get("n"), 1) or int(row.n) > 10000 or not Data.integer(row.get("sucessos")) or int(row.sucessos) > int(row.n): return false
	if not s.get("outcomes") is Array or s.outcomes.size() > 48: return false
	previous = -1
	for row in s.outcomes:
		if not row is Dictionary or row.size() != 5 or not State.valid_program(row.get("program")) or row.get("goal") not in TASKS or not row.get("success") is bool or row.get("error") not in ["", "recusado", "objetivo", "interrompido", "tempo"] or not Data.integer(row.get("tick")) or int(row.tick) > tick or int(row.tick) < previous: return false
		previous = int(row.tick)
	if not s.get("active") is Dictionary: return false
	if not s.active.is_empty():
		var a: Dictionary = s.active
		if a.size() != 6 or not State.valid_program(a.get("program")) or not Data.integer(a.get("terminal_id"), 1) or not Data.integer(a.get("started")) or int(a.started) > tick or not Data.integer(a.get("index")) or not Data.vector(a.get("origin")) or not a.get("instructions") is Array or a.instructions.size() > 8: return false
		var expected := instructions(a.program, s.state)
		if expected.is_empty() or expected != a.instructions or int(a.index) >= expected.size(): return false
	return true
