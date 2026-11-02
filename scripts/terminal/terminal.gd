extends RefCounted
const C = preload("res://scripts/terminal/terminal_catalogo.gd")
const T = preload("res://scripts/terminal/terminal_textos.gd")
const P = preload("res://scripts/terminal/terminal_parser.gd")
const S = preload("res://scripts/terminal/terminal_estado.gd")
const Mundo = preload("res://scripts/terminal/terminal_mundo.gd")
var _events: Array = []
var _steps := 0
var _deadline := 0
var _code := "ok"
var _budget := C.MAX_STEPS
var _running := false

# Não recebe AST externo. O adaptador confiável deve retornar prontamente.
func execute(source: Variant, world: Mundo, state: S, tick: int = 0, step_budget: int = C.MAX_STEPS, time_budget_usec: int = C.MAX_TIME_USEC) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	if _running:
		return T.result("adaptador")
	if state == null or not C.integer(tick, 0, S.MAX_TICK) or not state.is_valid():
		return T.result("estado")
	if step_budget < 1 or step_budget > C.MAX_STEPS or time_budget_usec < 0 or time_budget_usec > C.MAX_TIME_USEC:
		return T.result("limite")
	_running = true
	_events = []
	_steps = 0
	_budget = step_budget
	_deadline = started_usec + time_budget_usec
	_code = "ok"
	var parsed := P.new().parse(source)
	if not parsed.ok:
		_code = parsed.erro
	elif parsed.passos > _budget:
		_code = "passos"
	elif not _known(parsed.ast, state):
		_code = "desconhecido"
	elif world == null:
		_code = "adaptador"
	else:
		_run(parsed.ast, world, state)
	var out := T.result(_code)
	out.merge({"versao": C.VERSION, "eventos": _events.duplicate(true), "passos": _steps})
	state.record(source if typeof(source) == TYPE_STRING else "INVALIDO", _code, tick)
	_running = false
	return out

func _known(ast: Array, state: S) -> bool:
	for node in ast:
		if not state.conhecidos.has(node.comando) or not _known(node.corpo, state):
			return false
	return true

func _run(ast: Array, world: Mundo, state: S) -> void:
	for node in ast:
		if _code != "ok": return
		if Time.get_ticks_usec() >= _deadline:
			_code = "tempo"
			return
		if _steps >= _budget:
			_code = "passos"
			return
		_steps += 1
		var command: String = node.comando
		var args: Array = node.args
		if command == "REPETIR":
			for i in range(int(args[0])):
				_run(node.corpo, world, state)
				if _code != "ok": return
			continue
		var response: Dictionary = {}
		var discovered := ""
		match command:
			"OLHAR": response = world.olhar()
			"MARCAR": response = world.marcar(Vector2i(args[0], args[1]))
			"MOVER": response = world.mover(args[0], args[1])
			"DESENHAR": response = world.desenhar(args[0])
			"LER": response = world.ler(args[0])
			"AJUDA":
				response = {"ok": true}
				discovered = state.help_next()
		if typeof(response.get("ok")) != TYPE_BOOL or not response.ok:
			_code = "recusado"
		elif command == "LER":
			var book_command: String = {"livro_desenho": "DESENHAR", "livro_repeticao": "REPETIR"}.get(args[0], "")
			if state.discover(book_command, "livro"):
				discovered = book_command
		# Só dados finitos do contrato atravessam a fronteira de eventos.
		var data: Dictionary = {}
		var pos = response.get("pos")
		if typeof(pos) == TYPE_ARRAY and pos.size() == 2 and C.integer(pos[0], -64, 64) and C.integer(pos[1], -64, 64):
			data.pos = [int(pos[0]), int(pos[1])]
		_events.append({"comando": command, "args": args.duplicate(), "resultado": T.result(_code), "dados": data, "descoberto": discovered})
		if Time.get_ticks_usec() >= _deadline:
			_code = "tempo"
			return
