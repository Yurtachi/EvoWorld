extends RefCounted
const C = preload("res://scripts/terminal/terminal_catalogo.gd")
const T = preload("res://scripts/terminal/terminal_textos.gd")
var _tokens: Array = []
var _at := 0
var _nodes := 0
var _error := ""

func parse(source: Variant) -> Dictionary:
	_tokens = []
	_at = 0
	_nodes = 0
	_error = ""
	# Fronteira opcional para bytes de UI/persistência: nunca decodificar NUL.
	if typeof(source) == TYPE_PACKED_BYTE_ARRAY:
		if source.size() > C.MAX_INPUT or source.is_empty():
			return T.result("entrada")
		for byte in source:
			if byte == 0 or byte > 127:
				return T.result("simbolo")
		source = source.get_string_from_ascii()
	if typeof(source) != TYPE_STRING or source.length() > C.MAX_INPUT or source.is_empty():
		return T.result("entrada")
	var token := ""
	for i in range(source.length()):
		var ch: int = source.unicode_at(i)
		if (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or (ch >= 48 and ch <= 57) or ch == 95 or ch == 45:
			token += source[i]
			if token.length() > C.MAX_TOKEN:
				return T.result("limite")
		elif ch in [32, 9, 10, 13, 123, 125]:
			if not token.is_empty():
				_tokens.append(token)
				token = ""
			if ch in [10, 123, 125]:
				_tokens.append(source[i])
		else:
			return T.result("simbolo")
		if _tokens.size() > C.MAX_TOKENS:
			return T.result("limite")
	if not token.is_empty():
		_tokens.append(token)
	if _tokens.size() > C.MAX_TOKENS:
		return T.result("limite")
	var ast := _block(0)
	if not _error.is_empty():
		return T.result(_error)
	if _at != _tokens.size() or ast.is_empty():
		return T.result("sintaxe")
	var cost := _cost(ast)
	if cost > C.MAX_STEPS:
		return T.result("passos")
	var out := T.result("ok")
	out.merge({"versao": C.VERSION, "ast": ast, "passos": cost})
	return out

func _peek() -> String:
	return str(_tokens[_at]) if _at < _tokens.size() else ""

func _block(depth: int) -> Array:
	var ast: Array = []
	while _at < _tokens.size() and _error.is_empty():
		if _peek() == "\n":
			_at += 1
			continue
		if _peek() == "}":
			break
		var command := _peek()
		_at += 1
		if command not in C.COMMANDS:
			_error = "comando"
			break
		_nodes += 1
		if _nodes > C.MAX_NODES:
			_error = "limite"
			break
		var args: Array = []
		for kind in C.signature(command):
			var arg = C.argument(kind, _peek())
			if arg == null:
				_error = "argumento"
				return []
			args.append(arg)
			_at += 1
		var node := {"comando": command, "args": args, "corpo": []}
		if command == "REPETIR":
			if depth >= C.MAX_DEPTH:
				_error = "limite"
				return []
			if _peek() != "{":
				_error = "sintaxe"
				return []
			_at += 1
			node.corpo = _block(depth + 1)
			if _peek() != "}" or node.corpo.is_empty():
				_error = "sintaxe" if _error.is_empty() else _error
				return []
			_at += 1
		ast.append(node)
		if _peek() not in ["", "\n", "}"]:
			_error = "sintaxe"
			return []
	return ast

func _cost(ast: Array) -> int:
	var cost := 0
	for node in ast:
		cost += 1
		if node.comando == "REPETIR":
			cost += int(node.args[0]) * _cost(node.corpo)
		if cost > C.MAX_STEPS:
			return C.MAX_STEPS + 1
	return cost
