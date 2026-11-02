extends "res://scripts/terminal/terminal_mundo.gd"
var calls := {"olhar": 0, "marcar": 0, "mover": 0, "desenhar": 0, "ler": 0}
var forbidden_calls := {"processos": 0, "arquivos": 0, "rede": 0}
var pos := Vector2i.ZERO
var marks: Array = []
var drawings: Array = []
var reject := false

func olhar() -> Dictionary:
	calls.olhar += 1
	return {"ok": not reject, "pos": [pos.x, pos.y]}

func marcar(point: Vector2i) -> Dictionary:
	calls.marcar += 1
	if not reject:
		marks.append(point)
	return {"ok": not reject}

func mover(dir: String, n: int) -> Dictionary:
	calls.mover += 1
	var dirs := {"NORTE": Vector2i(0, -1), "SUL": Vector2i(0, 1), "LESTE": Vector2i(1, 0), "OESTE": Vector2i(-1, 0)}
	var next: Vector2i = pos + dirs[dir] * n
	if reject or absi(next.x) > 64 or absi(next.y) > 64:
		return {"ok": false}
	pos = next
	return {"ok": true}

func desenhar(shape: String) -> Dictionary:
	calls.desenhar += 1
	if not reject:
		drawings.append(shape)
	return {"ok": not reject}

func ler(_id: String) -> Dictionary:
	calls.ler += 1
	return {"ok": not reject}

func total_calls() -> int:
	var total := 0
	for value in calls.values():
		total += value
	return total
