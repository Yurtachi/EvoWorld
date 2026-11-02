extends RefCounted
## Read-only formatting of the public snapshot. No claim of comprehension.
const Texto = preload("res://scripts/core/textos.gd")
const Books = preload("res://scripts/library/book_catalog.gd")

static func source_name(source: String) -> String:
	if source.begins_with("livro:"):
		var parts := source.split(":")
		var title := Texto.texto("book_" + parts[1])
		return Texto.texto("m3c_book_source", [title, int(parts[2])]) if parts.size() == 3 else title
	return Texto.texto("m3c_source_" + source)

static func statement(content: Dictionary) -> String:
	var rows: Array[String] = []
	for category in content:
		var value := float(content[category])
		rows.append(Texto.texto("m3c_statement", [Texto.texto("m3c_category_" + category), Texto.texto("m3c_value_" + ("avoid" if value < -0.25 else ("safe" if value > 0.25 else "neutral"))), Texto.numero(value, 2)]))
	return "\n".join(rows)

static func describe(creature, tick: int) -> String:
	if creature == null or creature.mind == null: return Texto.texto("m1_disabled")
	var s: Dictionary = creature.knowledge_snapshot()
	var rows: Array[String] = [Texto.texto("m3c_scope")]
	if not creature.mind.memory_enabled or creature.mind.policy_mode != "full": rows.append(Texto.texto("m3c_memory_off"))
	rows.append(Texto.texto("m3c_facts"))
	for fact in s.get("facts", []):
		var attributed := statement(fact.conteudo)
		if fact.fonte == "cuidador": attributed = Texto.texto("m3c_caregiver_said", [attributed])
		rows.append(Texto.texto("m3c_fact", [fact.id, attributed, source_name(fact.fonte), Texto.numero(fact.confianca, 2), fact.tick, fact.validade, Texto.texto("m2_valid" if tick <= int(fact.validade) else "m2_expired"), Texto.texto("m3c_evidence" if fact.evidencia else "m3c_hypothesis")]))
	if s.get("facts", []).is_empty(): rows.append(Texto.texto("m3c_no_facts"))
	rows.append(Texto.texto("m3c_sources"))
	for source in s.get("sources", {}):
		var trust := float(s.sources[source])
		rows.append(Texto.texto("m3c_trust", [source_name(source), Texto.numero(trust, 2)]))
		if source.begins_with("livro:") and trust < 0.8 - 0.000001:
			rows.append(Texto.texto("m3c_book_distrusted"))
	if s.get("sources", {}).is_empty(): rows.append(Texto.texto("m3c_no_sources"))
	rows.append(Texto.texto("m3c_symbols"))
	for glyph in ["anel", "barra", "onda"]:
		var entry: Dictionary = s.get("symbols", {}).get(glyph, {})
		var known: bool = not entry.is_empty() and float(entry.confidence) >= 0.5 and tick - int(entry.tick) <= 3600
		rows.append(Texto.texto("m3c_symbol", [Texto.texto("m3c_glyph_" + glyph), Texto.texto("m3c_category_" + str(entry.category)) if known else Texto.texto("m3c_unknown"), Texto.numero(float(entry.get("confidence", 0)), 2)]))
	rows.append(Texto.texto("m3c_symbols_note"))
	return "\n\n".join(rows)

static func reading(creature) -> String:
	if creature == null or creature.mind == null: return ""
	var s: Dictionary = creature.knowledge_snapshot()
	var r: Dictionary = s.get("reading", {})
	if creature.last_action == "seek_book": return Texto.texto("m3c_approaching")
	if r.is_empty(): return Texto.texto("m3c_read_idle")
	var total: int = Books.BOOKS[r.book_id].size()
	var count := 0
	for fact in s.get("facts", []):
		if str(fact.fonte).begins_with("livro:" + str(r.book_id) + ":"): count += 1
	var phase := Texto.texto("m3c_read_done", [total]) if int(r.page) >= total else Texto.texto("m3c_read_page", [int(r.page) + 1, total, r.progress])
	return Texto.texto("m3c_reading", [Texto.texto("m1_goal_ler" if creature.last_action == "read_book" else "m3c_last_reading"), Texto.texto("book_" + str(r.book_id)), phase, count])
