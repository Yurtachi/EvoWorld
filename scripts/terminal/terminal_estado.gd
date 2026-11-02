extends RefCounted
const C = preload("res://scripts/terminal/terminal_catalogo.gd")
const T = preload("res://scripts/terminal/terminal_textos.gd")
const P = preload("res://scripts/terminal/terminal_parser.gd")
const MAX_ATTEMPTS := 48
const MAX_PROGRAMS := 32
const MAX_PROGRAM_LENGTH := 256
const MAX_COUNT := 10000
const MAX_TICK := 2147483647
const HELP := ["MARCAR", "MOVER", "LER"]
var conhecidos := {"OLHAR": "inicial", "AJUDA": "inicial"}
var tentativas: Array = []
var tabela: Dictionary = {}
var sucessos := 0

func discover(command: String, source: String) -> bool:
	if conhecidos.has(command):
		return false
	var allowed := (source in ["ajuda", "manual"] and command in HELP) or (source == "livro" and command in ["DESENHAR", "REPETIR"]) or (source == "pratica" and command == "REPETIR" and sucessos >= 3)
	if not allowed:
		return false
	conhecidos[command] = source
	return true

func help_next() -> String:
	for command in HELP:
		if discover(command, "ajuda"):
			return command
	return ""

func record(program: String, code: String, tick: int) -> void:
	if not T.MESSAGES.has(code) or not C.integer(tick, 0, MAX_TICK):
		return
	# Histórico é dado opaco, inclusive erros de sintaxe; nunca vira código.
	var label := ""
	for i in range(mini(program.length(), MAX_PROGRAM_LENGTH)):
		var cp := program.unicode_at(i)
		label += program[i] if (cp >= 32 and cp <= 126) or cp in [9, 10, 13] else "?"
	if label.is_empty(): label = "INVALIDO"
	tentativas.append({"comando": label, "erro": "" if code == "ok" else code, "resultado": code == "ok", "tick": tick})
	if tentativas.size() > MAX_ATTEMPTS:
		tentativas.pop_front()
	if code == "ok":
		sucessos = mini(MAX_COUNT, sucessos + 1)
		discover("REPETIR", "pratica")
	if not valid_program(program):
		return
	if not tabela.has(label):
		if tabela.size() >= MAX_PROGRAMS:
			var keys := tabela.keys()
			keys.sort()
			var victim: String = keys[0]
			for key in keys:
				if tabela[key].n < tabela[victim].n: victim = key
			tabela.erase(victim)
		tabela[label] = {"n": 0, "sucessos": 0}
	var entry: Dictionary = tabela[label]
	if entry.n < MAX_COUNT:
		entry.n += 1
		entry.sucessos += 1 if code == "ok" else 0

static func valid_program(program: Variant) -> bool:
	if typeof(program) != TYPE_STRING or program.length() > MAX_PROGRAM_LENGTH:
		return false
	var parsed := P.new().parse(program)
	return parsed.ok and parsed.passos <= 8

func is_valid() -> bool:
	return valid({"versao": C.VERSION, "conhecidos": conhecidos, "tentativas": tentativas, "tabela": tabela, "sucessos": sucessos})

func to_dict() -> Dictionary:
	return {"versao": C.VERSION, "conhecidos": conhecidos.duplicate(true), "tentativas": tentativas.duplicate(true), "tabela": tabela.duplicate(true), "sucessos": sucessos}

static func valid(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.size() != 5:
		return false
	for key in ["versao", "conhecidos", "tentativas", "tabela", "sucessos"]:
		if not data.has(key):
			return false
	if not C.integer(data.versao, C.VERSION, C.VERSION) or not C.integer(data.sucessos, 0, MAX_COUNT):
		return false
	if typeof(data.conhecidos) != TYPE_DICTIONARY or data.conhecidos.size() > C.COMMANDS.size():
		return false
	if data.conhecidos.get("OLHAR") != "inicial" or data.conhecidos.get("AJUDA") != "inicial":
		return false
	for command in data.conhecidos:
		if command not in C.COMMANDS:
			return false
		var source = data.conhecidos[command]
		if command in ["OLHAR", "AJUDA"]:
			if source != "inicial": return false
		elif command in HELP:
			if source not in ["ajuda", "manual"]: return false
		elif command == "DESENHAR":
			if source != "livro": return false
		elif source != "livro" and not (source == "pratica" and data.sucessos >= 3):
			return false
	if typeof(data.tentativas) != TYPE_ARRAY or data.tentativas.size() > MAX_ATTEMPTS:
		return false
	for entry in data.tentativas:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 4:
			return false
		for key in ["comando", "erro", "resultado", "tick"]:
			if not entry.has(key): return false
		if typeof(entry.comando) != TYPE_STRING or entry.comando.is_empty() or entry.comando.length() > MAX_PROGRAM_LENGTH:
			return false
		for i in range(entry.comando.length()):
			var cp: int = entry.comando.unicode_at(i)
			if not ((cp >= 32 and cp <= 126) or cp in [9, 10, 13]): return false
		if typeof(entry.erro) != TYPE_STRING or typeof(entry.resultado) != TYPE_BOOL or not C.integer(entry.tick, 0, MAX_TICK):
			return false
		if (entry.resultado and entry.erro != "") or (not entry.resultado and (not T.MESSAGES.has(entry.erro) or entry.erro == "ok")):
			return false
	if typeof(data.tabela) != TYPE_DICTIONARY or data.tabela.size() > MAX_PROGRAMS:
		return false
	for program in data.tabela:
		if not valid_program(program):
			return false
		var entry = data.tabela[program]
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 2 or not entry.has("n") or not entry.has("sucessos"):
			return false
		if not C.integer(entry.n, 1, MAX_COUNT) or not C.integer(entry.sucessos, 0, int(entry.n)):
			return false
	return true

static func from_dict(data: Variant):
	if not valid(data):
		return null
	var state = load("res://scripts/terminal/terminal_estado.gd").new()
	state.conhecidos = data.conhecidos.duplicate(true)
	state.tentativas = data.tentativas.duplicate(true)
	state.tabela = data.tabela.duplicate(true)
	state.sucessos = int(data.sucessos)
	for entry in state.tentativas:
		entry.tick = int(entry.tick)
	for entry in state.tabela.values():
		entry.n = int(entry.n)
		entry.sucessos = int(entry.sucessos)
	return state
