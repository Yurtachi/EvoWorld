extends RefCounted
const VERSION := 1
const COMMANDS := ["OLHAR", "MARCAR", "MOVER", "DESENHAR", "REPETIR", "AJUDA", "LER"]
const DIRECTIONS := ["NORTE", "SUL", "LESTE", "OESTE"]
const SHAPES := ["LINHA", "CIRCULO", "QUADRADO"]
const BOOKS := ["livro_desenho", "livro_repeticao", "mapa"]
const MAX_INPUT := 4096
const MAX_TOKENS := 512
const MAX_TOKEN := 32
const MAX_DEPTH := 4
const MAX_NODES := 64
const MAX_REPEAT := 16
const MAX_STEPS := 128
const MAX_TIME_USEC := 50000

static func signature(command: String) -> Array:
	match command:
		"MARCAR": return ["coord", "coord"]
		"MOVER": return ["dir", "steps"]
		"DESENHAR": return ["shape"]
		"LER": return ["book"]
		"REPETIR": return ["repeat"]
	return []

static func integer(value: Variant, low: int, high: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high and float(value) == floor(float(value))

static func argument(kind: String, token: String) -> Variant:
	match kind:
		"dir": return token if token in DIRECTIONS else null
		"shape": return token if token in SHAPES else null
		"book": return token if token in BOOKS else null
	if token.is_empty() or token.length() > 5:
		return null
	var start := 1 if token.begins_with("-") else 0
	if start == token.length():
		return null
	for i in range(start, token.length()):
		if token.unicode_at(i) < 48 or token.unicode_at(i) > 57:
			return null
	var n := token.to_int()
	match kind:
		"coord": return n if n >= -64 and n <= 64 else null
		"steps": return n if n >= 1 and n <= 8 else null
		"repeat": return n if n >= 1 and n <= MAX_REPEAT else null
	return null
