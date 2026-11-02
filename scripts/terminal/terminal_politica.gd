extends RefCounted
const S = preload("res://scripts/terminal/terminal_estado.gd")
const C = preload("res://scripts/terminal/terminal_catalogo.gd")
const P = preload("res://scripts/terminal/terminal_parser.gd")
const EXAMPLES := {"OLHAR": "OLHAR", "MARCAR": "MARCAR 0 0", "MOVER": "MOVER NORTE 1", "DESENHAR": "DESENHAR LINHA", "AJUDA": "AJUDA", "LER": "LER livro_desenho", "REPETIR": "REPETIR 2 { OLHAR }"}
const MAX_CANDIDATES := 16

static func candidates(state) -> Array:
	if state == null or not state.is_valid():
		return []
	var out: Array = []
	for command in C.COMMANDS:
		if state.conhecidos.has(command):
			out.append(EXAMPLES[command])
	var remembered: Array = state.tabela.keys()
	remembered.sort()
	for program in remembered:
		if out.size() >= MAX_CANDIDATES: break
		if program not in out and _known(P.new().parse(program).ast, state):
			out.append(program)
	var singles := out.duplicate()
	for first in singles:
		for second in singles:
			if out.size() >= MAX_CANDIDATES:
				return out
			var pair: String = first + "\n" + second
			if pair not in out and S.valid_program(pair): out.append(pair)
	return out

static func score(state, program: String, exploration: float = 0.2) -> float:
	if state == null or not state.is_valid() or not S.valid_program(program) or not is_finite(exploration) or exploration < 0.0 or exploration > 1.0:
		return -1.0
	var entry: Dictionary = state.tabela.get(program, {"n": 0, "sucessos": 0})
	return (float(entry.sucessos) + 1.0) / (float(entry.n) + 2.0) + exploration / sqrt(float(entry.n) + 1.0)

static func _known(ast: Array, state) -> bool:
	for node in ast:
		if not state.conhecidos.has(node.comando) or not _known(node.corpo, state): return false
	return true

static func choose(state) -> String:
	var best := ""
	var best_score := -1.0
	for program in candidates(state):
		var value := score(state, program)
		if value > best_score:
			best_score = value
			best = program
	return best
