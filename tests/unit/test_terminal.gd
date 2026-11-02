extends RefCounted
const Terminal = preload("res://scripts/terminal/terminal.gd")
const State = preload("res://scripts/terminal/terminal_estado.gd")
const Parser = preload("res://scripts/terminal/terminal_parser.gd")
const Policy = preload("res://scripts/terminal/terminal_politica.gd")
const Fake = preload("res://scripts/terminal/terminal_mundo_falso.gd")
const C = preload("res://scripts/terminal/terminal_catalogo.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func unlocked():
	var state := State.new()
	for command in State.HELP: state.discover(command, "ajuda")
	state.discover("DESENHAR", "livro")
	state.discover("REPETIR", "livro")
	return state

func run() -> Array:
	var f: Array = []
	_language(f)
	_discovery_and_policy(f)
	_persistence(f)
	_hostile(f)
	_scan("res://scripts/terminal", f)
	return f

func _language(f: Array) -> void:
	var terminal := Terminal.new()
	var state = unlocked()
	var world := Fake.new()
	var result := terminal.execute("OLHAR\nMARCAR -2 3\nMOVER LESTE 2\nDESENHAR CIRCULO\nLER mapa\nREPETIR 2 {\nOLHAR\n}", world, state, 12)
	check(result.ok and result.passos == 8 and result.eventos.size() == 7, "programa valido/AST/custo", f)
	check(world.pos == Vector2i(2, 0) and world.marks == [Vector2i(-2, 3)] and world.drawings == ["CIRCULO"], "argumentos do adaptador", f)
	check(result.eventos[0].dados.pos == [0, 0], "OLHAR nao devolveu dados virtuais", f)
	var before := world.total_calls()
	check(not terminal.execute("OLHAR\nMOVER NORTE 1 extra", world, state).ok and world.total_calls() == before, "validacao atomica da sintaxe", f)
	check(terminal.execute("REPETIR 2 { REPETIR 2 { OLHAR } }", world, state).passos == 7, "AST aninhada/custo", f)
	before = world.total_calls()
	check(terminal.execute("REPETIR 16 { REPETIR 16 { OLHAR } }", world, state).erro == "passos" and world.total_calls() == before, "orcamento expandido antes de efeitos", f)
	check(terminal.execute("OLHAR\nOLHAR", world, state, 0, 1).erro == "passos" and world.total_calls() == before, "orcamento por execucao", f)
	check(terminal.execute("OLHAR", world, state, 0, 128, 0).erro == "tempo" and world.total_calls() == before, "tempo esgotado sem chamadas", f)
	world.reject = true
	var rejected := terminal.execute("MOVER NORTE 1\nOLHAR", world, state)
	check(rejected.erro == "recusado" and rejected.passos == 1, "parar ao recusar acao", f)
	check(terminal.execute("OLHAR", null, state).erro == "adaptador", "adaptador ausente", f)
	for source in ["OLHAR 2", "MOVER NORTE", "MOVER NORTE 0", "MOVER NORTE 9", "MARCAR 65 0", "DESENHAR ESTRELA", "LER segredo", "REPETIR 0 { OLHAR }", "REPETIR 1 {}", "{ OLHAR }", "OLHAR}"]:
		check(not Parser.new().parse(source).ok, "aridade/tipo/limite: " + source, f)
	check(Parser.new().parse("\r\n\tOLHAR\r\n").ok, "espacos e CRLF", f)
	check(Parser.new().parse("OLHAR" + " ".repeat(C.MAX_INPUT - 5)).ok, "limite exato de entrada", f)
	check(Parser.new().parse("OLHAR\n".repeat(C.MAX_NODES)).ok, "limite exato de nos", f)
	check(not Parser.new().parse("OLHAR\n".repeat(C.MAX_NODES + 1)).ok, "limite de nos excedido", f)
	check(Parser.new().parse("REPETIR 1 { ".repeat(C.MAX_DEPTH) + "OLHAR" + " }".repeat(C.MAX_DEPTH)).ok, "limite exato de profundidade", f)
	var exact := "REPETIR 7 { REPETIR 16 { OLHAR } }\n" + "OLHAR\n".repeat(8)
	check(Parser.new().parse(exact).passos == C.MAX_STEPS, "limite exato de passos", f)
	check(Parser.new().parse(exact + "OLHAR").erro == "passos", "um passo excedente", f)

func _discovery_and_policy(f: Array) -> void:
	var terminal := Terminal.new()
	var a := State.new()
	var b := State.new()
	var world := Fake.new()
	check(terminal.execute("MOVER NORTE 1", world, a).erro == "desconhecido" and world.total_calls() == 0, "comando bloqueado", f)
	check(terminal.execute("AJUDA\nMOVER NORTE 1", world, a).erro == "desconhecido", "prevalidacao de conhecidos", f)
	for i in range(3):
		check(terminal.execute("AJUDA", world, a, i).ok, "ajuda gradual", f)
	check(a.conhecidos.has("LER") and a.conhecidos.has("REPETIR") and not b.conhecidos.has("LER"), "conhecidos individuais/pratica", f)
	check(not a.conhecidos.has("DESENHAR"), "ajuda nao concede livro", f)
	terminal.execute("LER livro_desenho", world, a)
	check(a.conhecidos.get("DESENHAR") == "livro", "livro nao desbloqueou desenho", f)
	check(not a.discover("powershell", "livro") and not b.discover("REPETIR", "pratica") and not b.discover("DESENHAR", "ajuda"), "proveniencia invalida", f)
	world.reject = true
	var book_state := State.new()
	for command in State.HELP: book_state.discover(command, "ajuda")
	terminal.execute("LER livro_desenho", world, book_state)
	check(not book_state.conhecidos.has("DESENHAR"), "livro recusado concedeu conhecimento", f)
	var learned := State.new()
	var base_score := Policy.score(learned, "OLHAR", 0.0)
	for i in range(8): learned.record("OLHAR", "ok", i)
	for i in range(8): learned.record("AJUDA", "recusado", i)
	check(Policy.score(learned, "OLHAR", 0.0) > base_score and Policy.score(learned, "AJUDA", 0.0) < base_score, "politica ignora sucesso passado", f)
	check(Policy.choose(learned) == "OLHAR", "politica nao prefere sequencia bem sucedida", f)
	learned.record("OLHAR\nAJUDA\nOLHAR", "ok", 9)
	check("OLHAR\nAJUDA\nOLHAR" in Policy.candidates(learned), "sequencia passada nao recuperada", f)
	learned.record("OLHAR\n".repeat(8), "ok", 10)
	for program in Policy.candidates(learned):
		check(State.valid_program(program), "combinacao de programas excede oito passos", f)
	var programs := Policy.candidates(a)
	check(programs.size() <= Policy.MAX_CANDIDATES and programs == Policy.candidates(a), "candidatos limitados/deterministas", f)
	for program in programs:
		var parsed := Parser.new().parse(program)
		check(parsed.ok and parsed.passos <= 8, "candidato invalido", f)
		for node in parsed.ast:
			check(a.conhecidos.has(node.comando), "candidato usa comando desconhecido", f)

func _persistence(f: Array) -> void:
	var state = unlocked()
	for i in range(80): state.record("OLHAR", "ok" if i % 2 == 0 else "recusado", i)
	check(state.tentativas.size() == State.MAX_ATTEMPTS and state.tentativas[0].tick == 32, "registro limitado", f)
	state.record("MISTERIO;" + "A".repeat(1000), "comando", 80)
	check(state.tentativas.back().comando.begins_with("MISTERIO;") and state.tentativas.back().comando.length() == State.MAX_PROGRAM_LENGTH, "historico de erros/truncamento", f)
	for i in range(40): state.record("MARCAR %d 0" % i, "ok", i)
	check(state.tabela.size() == State.MAX_PROGRAMS, "tabela limitada", f)
	var data := state.to_dict()
	var restored = State.from_dict(JSON.parse_string(JSON.stringify(data)))
	check(restored != null and JSON.stringify(restored.to_dict(), "", true) == JSON.stringify(data, "", true), "round trip JSON", f)
	check(Policy.choose(restored) == Policy.choose(state), "politica nao persistiu", f)
	state.record("MARCAR -1 0", "ok", 90)
	restored.record("MARCAR -1 0", "ok", 90)
	check(JSON.stringify(restored.to_dict(), "", true) == JSON.stringify(state.to_dict(), "", true), "continuacao apos round trip/eviccao", f)
	data.conhecidos.clear()
	check(state.conhecidos.has("OLHAR"), "snapshot compartilha estado", f)
	for value in [null, [], "estado", true, NAN, INF, {}]:
		check(State.from_dict(value) == null, "schema aceita tipo invalido", f)
	for key in ["versao", "sucessos", "conhecidos", "tentativas", "tabela"]:
		for value in [null, true, "bad", NAN, INF, -1, 1e9]:
			var bad := state.to_dict()
			bad[key] = value
			check(State.from_dict(bad) == null, "schema invalido: " + key, f)
	var mutations := [
		{"conhecidos": {"OLHAR": "inicial", "AJUDA": "inicial", "DESENHAR": "ajuda"}},
		{"conhecidos": {"OLHAR": "inicial", "AJUDA": "inicial", "REPETIR": "pratica"}, "sucessos": 0},
		{"tentativas": [{"comando": "OLHAR", "erro": "recusado", "resultado": true, "tick": 0}]},
		{"tentativas": [{"comando": "OLHAR", "erro": "", "resultado": true, "tick": NAN}]},
		{"tabela": {"OLHAR": {"n": 1, "sucessos": 2}}},
		{"tabela": {"OLHAR": {"n": NAN, "sucessos": 0}}},
		{"tabela": {"../": {"n": 1, "sucessos": 0}}},
	]
	for mutation in mutations:
		var bad := state.to_dict()
		bad.merge(mutation, true)
		check(State.from_dict(bad) == null, "schema aninhado/proveniencia", f)
	var huge := state.to_dict()
	huge.tentativas.resize(State.MAX_ATTEMPTS + 1)
	check(State.from_dict(huge) == null, "historico enorme", f)
	var corrupt := State.new()
	corrupt.sucessos = -1
	check(Terminal.new().execute("OLHAR", Fake.new(), corrupt).erro == "estado", "estado corrompido em execucao", f)

func hostile_corpus() -> Array:
	var out: Array = ["powershell", "cmd /c", "rm -rf", "../", "C:\\", "https://example.org", "import os", "OS.execute", "ОLHAR", "ＯＬＨＡＲ", "OLHAR\u200b", "OLHAR\u202e", "MOVER NORTE NaN", "MARCAR NaN 0", "OLHAR\uFFFDX", "MISTERIO", "REPETIR 1000000000 { OLHAR }", "A".repeat(1000000), "REPETIR 1 { ".repeat(100) + "OLHAR" + " }".repeat(100), "OLHAR\n".repeat(1000)]
	for symbol in [";", "|", "&", "\\", ">", "<", "\\\\", "`", "$", "'", '"', "/", ".", "(", ")", "=", "#"]:
		out.append("OLHAR" + symbol)
		out.append("OLHAR\n" + symbol)
	return out

func _hostile(f: Array) -> void:
	var terminal := Terminal.new()
	var cases := hostile_corpus()
	var count := 0
	for source in cases:
		var world := Fake.new()
		var state = unlocked()
		var result := terminal.execute(source, world, state)
		check(not result.ok and world.total_calls() == 0, "entrada hostil executada indice %d" % count, f)
		check(world.forbidden_calls == {"processos": 0, "arquivos": 0, "rede": 0}, "capacidade externa tocada", f)
		check(State.valid(state.to_dict()), "entrada hostil corrompe estado", f)
		count += 1
	for seed_value in [140101, 140102, 140103, 140104]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in range(128):
			var source := ""
			for j in range(rng.randi_range(1, 100)):
				source += String.chr(rng.randi_range(1, 255))
			# Cada mutação tem um símbolo inválido garantido, sem efeitos de prefixo.
			source = "OLHAR\n" + source + ";"
			var world := Fake.new()
			var result := terminal.execute(source, world, unlocked())
			check(not result.ok and world.total_calls() == 0, "fuzz seed=%d caso=%d" % [seed_value, i], f)
			count += 1
		for i in range(128):
			var number := rng.randi_range(-2, 20)
			var depth := rng.randi_range(1, 6)
			var programs := ["MOVER NORTE %d" % number, "REPETIR %d { OLHAR }" % number, "MARCAR %d %d" % [number * 8, number], "REPETIR 1 { ".repeat(depth) + "OLHAR" + " }".repeat(depth)]
			var source: String = programs[i % programs.size()]
			if i % 7 == 0: source = "OLHAR\n" + source + "\nDESENHAR LINHA"
			var parsed := Parser.new().parse(source)
			var world_a := Fake.new()
			var world_b := Fake.new()
			var result_a := terminal.execute(source, world_a, unlocked())
			var result_b := Terminal.new().execute(source, world_b, unlocked())
			check(result_a == result_b and world_a.calls == world_b.calls, "fuzz estruturado nao determinista", f)
			check(parsed.ok or world_a.total_calls() == 0, "fuzz estruturado com efeito antes de validar", f)
			count += 1
	for source in [null, NAN, INF, 5, true, [], {}]:
		check(not terminal.execute(source, Fake.new(), unlocked()).ok, "entrada nao textual", f)
	for raw in [PackedByteArray([79, 76, 72, 65, 82, 0, 88]), PackedByteArray([0]), PackedByteArray([255])]:
		var world := Fake.new()
		check(terminal.execute(raw, world, unlocked()).erro == "simbolo" and world.total_calls() == 0, "bytes NUL/unicode antes de decodificar", f)
	check(terminal.execute("OLHAR".to_ascii_buffer(), Fake.new(), unlocked()).ok, "controle ASCII em bytes", f)
	print("Terminal hostil: %d casos textuais; seeds 140101-140104; zero chamadas nos rejeitados" % count)

func _scan(path: String, f: Array) -> void:
	var dir := DirAccess.open(path)
	check(dir != null, "scanner sem modulo", f)
	if dir == null: return
	for file in dir.get_files():
		if not file.ends_with(".gd"): continue
		var source := FileAccess.get_file_as_string(path + "/" + file)
		for forbidden in ["FileAccess", "DirAccess", "OS.", "HTTPRequest", "HTTPClient", "StreamPeer", "PacketPeer", "TCPServer", "UDPServer", "Expression", "JavaScriptBridge", "Engine.", "ClassDB", "eval(", "get_tree(", "callv(", ".call("]:
			check(not forbidden in source, "API proibida " + forbidden + " em " + file, f)
	for child in dir.get_directories():
		_scan(path + "/" + child, f)
