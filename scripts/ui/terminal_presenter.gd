extends RefCounted
## Read-only formatting of the public terminal snapshot. No claim of comprehension.
const Texto = preload("res://scripts/core/textos.gd")

static func describe(creature, world) -> String:
	if creature == null or creature.mind == null:
		return Texto.texto("m1_disabled")
	var s: Dictionary = creature.terminal_snapshot() if creature.has_method("terminal_snapshot") else (world.terminal_snapshot(creature) if world != null else {})
	if s.is_empty():
		return Texto.texto("m4b_status_idle")
	var tick: int = world.tick if world != null else 0
	var rows: Array[String] = []

	# 1. Comandos conhecidos e como foram descobertos
	rows.append(Texto.texto("m4b_commands_known"))
	var known: Dictionary = s.get("state", {}).get("conhecidos", {})
	if known.is_empty():
		rows.append(Texto.texto("m4b_no_commands"))
	else:
		for cmd in known:
			var origin: String = str(known[cmd])
			var origin_text := Texto.texto("m4b_cmd_" + origin) if Texto.M4B_UI.has("m4b_cmd_" + origin) else origin
			rows.append(Texto.texto("m4b_cmd_row", [cmd, origin_text]))

	# 2. Objetivo atual e sessão ativa
	var task: Dictionary = s.get("task", {})
	if not task.is_empty():
		var target = task.get("target", [0, 0])
		var target_str := "(%d, %d)" % [int(target[0]), int(target[1])] if target is Array and target.size() >= 2 else str(target)
		rows.append(Texto.texto("m4b_task_info", [str(task.get("kind", "")), target_str]))

	var active: Dictionary = s.get("active", {})
	if not active.is_empty():
		var idx: int = int(active.get("index", 0)) + 1
		var insts: Array = active.get("instructions", [])
		var curr := str(insts[idx - 1]) if idx <= insts.size() else ""
		rows.append(Texto.texto("m4b_status_active", [idx, insts.size(), curr]))

	# 3. Recusas / adiamentos
	var refusal_until: int = int(s.get("refusal_until", 0))
	if refusal_until > tick:
		rows.append(Texto.texto("m4b_refusal_status", [refusal_until, refusal_until - tick]))
	var cooldown: int = int(s.get("cooldown", 0))
	if cooldown > tick:
		rows.append(Texto.texto("m4b_cooldown_status", [cooldown]))

	# 4. Sequência que funciona por objetivo (tabela de memória)
	rows.append(Texto.texto("m4b_sequences_by_goal"))
	var table: Dictionary = s.get("table", {})
	if table.is_empty():
		rows.append(Texto.texto("m4b_no_sequences"))
	else:
		for k in table:
			var parts: PackedStringArray = str(k).split(":")
			var goal := parts[0] if parts.size() > 0 else ""
			var seq := parts[1] if parts.size() > 1 else ""
			var row: Dictionary = table[k]
			var n: int = int(row.get("n", 0))
			var succ: int = int(row.get("sucessos", 0))
			var sc: float = (float(succ) + 1.0) / (float(n) + 2.0) + 0.2 / sqrt(float(n) + 1.0)
			rows.append(Texto.texto("m4b_sequence_row", [goal, seq, n, succ, Texto.numero(sc, 3)]))

	# 5. Tentativas recentes com sucesso / erro
	var attempts: Array = s.get("state", {}).get("tentativas", [])
	rows.append(Texto.texto("m4b_recent_attempts", [mini(attempts.size(), 12)]))
	if attempts.is_empty():
		rows.append(Texto.texto("m4b_no_attempts"))
	else:
		for i in range(attempts.size() - 1, maxi(-1, attempts.size() - 13), -1):
			var a: Dictionary = attempts[i]
			var outcome := Texto.texto("m4b_attempt_ok") if a.get("resultado", false) else Texto.texto("m4b_attempt_err", [str(a.get("erro", ""))])
			rows.append(Texto.texto("m4b_attempt_row", [int(a.get("tick", 0)), str(a.get("comando", "")), outcome]))

	# 6. Texto honesto do X7
	rows.append(Texto.texto("m4b_x7_honest_title"))
	rows.append(Texto.texto("m4b_x7_honest_text"))

	return "\n\n".join(rows)

static func status_line(creature, world) -> String:
	if creature == null or creature.mind == null:
		return ""
	var s: Dictionary = creature.terminal_snapshot() if creature.has_method("terminal_snapshot") else (world.terminal_snapshot(creature) if world != null else {})
	if s.is_empty():
		return Texto.texto("m4b_status_idle")
	var tick: int = world.tick if world != null else 0
	var refusal_until: int = int(s.get("refusal_until", 0))
	if refusal_until > tick:
		return Texto.texto("m4b_refusal_status", [refusal_until, refusal_until - tick])
	if creature.last_action == "seek_terminal":
		return Texto.texto("m4b_status_approaching")
	if creature.last_action == "use_terminal":
		return Texto.texto("m4b_status_using")
	if creature.last_action == "read_terminal_manual":
		return Texto.texto("m4b_status_reading_manual")
	var active: Dictionary = s.get("active", {})
	if not active.is_empty():
		var idx: int = int(active.get("index", 0)) + 1
		var insts: Array = active.get("instructions", [])
		var curr := str(insts[idx - 1]) if idx <= insts.size() else ""
		return Texto.texto("m4b_status_active", [idx, insts.size(), curr])
	return Texto.texto("m4b_status_idle")
