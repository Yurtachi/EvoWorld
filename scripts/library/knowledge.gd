extends RefCounted
## Data-only epistemic memory: never writes any bodily field.
const Data = preload("res://scripts/core/sim_data.gd")
const Books = preload("res://scripts/library/book_catalog.gd")
const LIMIT := 48
const TTL := 3600
const COOLDOWN := 180
const CATEGORIES := ["capsula", "pedra", "quadro"]
const GLYPHS := ["anel", "barra", "onda"]

static func empty() -> Dictionary:
	return {"facts": [], "sources": {}, "questions": [], "asked": {}, "reading": {}, "symbols": {}, "next_id": 1, "next_question": 0}

static func state(mind) -> Dictionary:
	if mind.knowledge.is_empty(): mind.knowledge = empty()
	return mind.knowledge

static func add(mind, content: Dictionary, source: String, confidence: float, tick: int, evidence: bool = false) -> void:
	if not mind.memory_enabled or mind.policy_mode != "full": return
	var s := state(mind)
	var sk := Books.source_key(source)
	if not s.sources.has(sk): s.sources[sk] = snappedf(clampf(confidence, 0.05, 0.95), 0.000001)
	# Consolidate repeated statements only within a source: provenance survives.
	for f in s.facts:
		if f.fonte == source and Data.restore_precision(f.conteudo) == Data.restore_precision(content):
			f.tick = tick
			f.validade = tick + TTL
			return
	if s.facts.size() >= LIMIT: s.facts.pop_front()
	s.facts.append({"id": s.next_id, "conteudo": content.duplicate(true), "fonte": source, "confianca": snappedf(clampf(confidence, 0.0, 0.95), 0.000001), "tick": tick, "validade": tick + TTL, "evidencia": evidence})
	s.next_id += 1

static func expectation(mind, category: String, tick: int) -> float:
	if not mind.memory_enabled or mind.policy_mode != "full" or mind.knowledge.is_empty(): return 0.0
	var weighted := 0.0
	var total := 0.0
	var s: Dictionary = mind.knowledge
	for f in s.facts:
		if tick > int(f.validade) or not f.conteudo.has(category): continue
		var weight := float(f.confianca) * float(s.sources.get(Books.source_key(f.fonte), 0.5))
		if f.evidencia: weight *= 4.0
		weighted += float(f.conteudo[category]) * weight
		total += weight
	return weighted / maxf(0.5, total)

static func outcome(mind, category: String, evidence: Dictionary, tick: int) -> void:
	if not mind.memory_enabled or mind.policy_mode != "full": return
	var value := clampf((float(evidence.energy) + float(evidence.hydration)) / 6.0 - float(evidence.toxicity) * 4.0, -1.0, 1.0)
	var s := state(mind)
	var judged: Dictionary = {}
	for f in s.facts:
		if tick > int(f.validade) or not f.conteudo.has(category) or f.evidencia: continue
		var sk := Books.source_key(f.fonte)
		var agrees := absf(float(f.conteudo[category]) - value) < 0.5
		f.confianca = snappedf(clampf(float(f.confianca) + (0.05 if agrees else -0.45), 0.05, 0.95), 0.000001)
		if not judged.has(sk):
			s.sources[sk] = snappedf(clampf(float(s.sources[sk]) + (0.05 if agrees else -0.45), 0.05, 0.95), 0.000001)
			judged[sk] = true
	add(mind, {category: value}, "interagido", 0.95, tick, true)

static func maintain(mind, tick: int) -> void:
	if mind.knowledge.is_empty(): return
	var s: Dictionary = mind.knowledge
	s.facts = s.facts.filter(func(f): return tick <= int(f.validade))
	s.questions = s.questions.filter(func(q): return tick <= int(q.tick) + COOLDOWN)
	for key in s.asked.keys():
		if tick > int(s.asked[key]) + TTL: s.asked.erase(key)

static func gap(mind, creature, sensors: Dictionary, tick: int) -> void:
	if not mind.memory_enabled or mind.policy_mode != "full" or mind.objetivo_atual != "investigar_objeto": return
	var rows: Array = sensors.get("objects", [])
	if rows.is_empty(): return
	var s := state(mind)
	if tick < int(s.next_question) or not s.questions.is_empty(): return
	for row in rows:
		if int(row.id) != int(mind.objects.get("target", 0)): continue
		var known: bool = s.facts.any(func(f): return f.conteudo.has(row.category) and tick <= int(f.validade))
		var context := str(row.id) + ":" + str(row.category)
		if known or s.asked.has(context): continue
		# Low social activation may remain silent. No clock-triggered question.
		if float(mind.traits(creature).sociability) < 0.08: return
		s.questions.append({"id": str(creature.id) + ":" + str(s.next_id), "creature_id": creature.id, "object_id": row.id, "category": row.category, "goal": mind.objetivo_atual, "tick": tick, "text_key": "library.question.unknown"})
		s.next_id += 1
		s.asked[context] = tick
		if s.asked.size() > LIMIT: s.asked.erase(s.asked.keys()[0])
		s.next_question = tick + COOLDOWN
		return

static func answer(mind, creature, question_id: String, option: String, tick: int) -> bool:
	if mind.knowledge.is_empty(): return false
	var s: Dictionary = mind.knowledge
	for q in s.questions:
		if q.id != question_id: continue
		if option not in ["evitar", "seguro", "neutro", "silencio"]: return false
		s.questions.erase(q)
		if option == "silencio" or not mind.memory_enabled: return false
		var t: Dictionary = mind.traits(creature)
		var historical := float(s.sources.get("cuidador", 0.65))
		if float(t.caution) > 0.95 and historical < 0.4: return false
		var confidence := clampf(0.35 + float(t.sociability) * 0.25 + historical * 0.25 - float(t.caution) * 0.1, 0.1, 0.85)
		add(mind, {q.category: -1.0 if option == "evitar" else (1.0 if option == "seguro" else 0.0)}, "cuidador", confidence, tick)
		return true
	return false

static func demonstrate(mind, glyph: String, category: String, correct: bool, tick: int) -> bool:
	if glyph not in GLYPHS or category not in CATEGORIES or not mind.memory_enabled: return false
	var s := state(mind)
	var row: Dictionary = s.symbols.get(glyph, {"category": category, "confidence": 0.0, "tick": tick})
	if row.category != category and not correct: return true
	if correct and row.category != category: row.confidence = 0.0
	row.category = category
	row.confidence = snappedf(clampf(float(row.confidence) + (0.3 if correct else -0.4), 0.0, 0.9), 0.000001)
	row.tick = tick
	s.symbols[glyph] = row
	return true

static func association(mind, glyph: String, tick: int) -> String:
	if not mind.memory_enabled or mind.knowledge.is_empty(): return ""
	var row: Dictionary = mind.knowledge.symbols.get(glyph, {})
	return str(row.category) if not row.is_empty() and float(row.confidence) >= 0.5 and tick - int(row.tick) <= TTL else ""

static func valid(s: Variant, tick: int) -> bool:
	if not s is Dictionary: return false
	if s.is_empty(): return true
	if s.size() != 8 or not Data.json_data(s): return false
	if not s.get("facts") is Array or s.facts.size() > LIMIT or not s.get("sources") is Dictionary or s.sources.size() > 8 or not s.get("questions") is Array or s.questions.size() > 1 or not s.get("asked") is Dictionary or s.asked.size() > LIMIT or not s.get("reading") is Dictionary or not s.get("symbols") is Dictionary or s.symbols.size() > 3: return false
	if not Data.integer(s.get("next_id"), 1) or not Data.integer(s.get("next_question")) or int(s.next_question) > tick + COOLDOWN: return false
	var ids: Dictionary = {}
	for f in s.facts:
		if not f is Dictionary or f.size() != 7 or not Data.integer(f.get("id"), 1) or int(f.id) >= int(s.next_id) or ids.has(int(f.id)): return false
		ids[int(f.id)] = true
		if not Books.valid_source(f.get("fonte")) or not unit(f.get("confianca")) or not Data.integer(f.get("tick")) or int(f.tick) > tick or not Data.integer(f.get("validade")) or int(f.validade) != int(f.tick) + TTL or not f.get("evidencia") is bool: return false
		if f.evidencia != (f.fonte == "interagido"): return false
		if not f.get("conteudo") is Dictionary or f.conteudo.size() != 1: return false
		for category in f.conteudo:
			if category not in CATEGORIES or not Data.number(f.conteudo[category]) or absf(float(f.conteudo[category])) > 1.0: return false
		if f.fonte.begins_with("livro:"):
			var parts: PackedStringArray = f.fonte.split(":")
			if Data.restore_precision(f.conteudo) != Data.restore_precision(Books.BOOKS[parts[1]][int(parts[2]) - 1]): return false
		if not s.sources.has(Books.source_key(f.fonte)): return false
	for source in s.sources:
		if source not in ["observado", "interagido", "cuidador", "inferido", "livro:guia_capsulas", "livro:guia_pedras", "livro:guia_enganoso"] or not unit(s.sources[source]): return false
	for context in s.asked:
		var parts: PackedStringArray = context.split(":")
		if parts.size() != 2 or not Data.integer_text(parts[0]) or int(parts[0]) <= 0 or parts[1] not in CATEGORIES or not Data.integer(s.asked[context]) or int(s.asked[context]) > tick: return false
	for q in s.questions:
		if not q is Dictionary or q.size() != 7 or not q.get("id") is String or not Data.integer(q.get("creature_id"), 1) or not Data.integer(q.get("object_id"), 1) or not q.get("category") is String or q.get("category") not in CATEGORIES or not q.get("goal") is String or q.get("goal") != "investigar_objeto" or not q.get("text_key") is String or q.get("text_key") != "library.question.unknown" or not Data.integer(q.get("tick")) or int(q.tick) > tick: return false
		var parts: PackedStringArray = q.id.split(":")
		if parts.size() != 2 or parts[0] != str(int(q.creature_id)) or not Data.integer_text(parts[1]) or int(parts[1]) <= 0 or int(parts[1]) >= int(s.next_id) or ids.has(int(parts[1])): return false
		if not s.asked.has(str(int(q.object_id)) + ":" + str(q.category)): return false
	if not s.reading.is_empty():
		var r: Dictionary = s.reading
		if r.size() != 5 or not Data.integer(r.get("id"), 1) or not Books.BOOKS.has(r.get("book_id", "")) or not Data.integer(r.get("page")) or int(r.page) > Books.BOOKS[r.book_id].size() or not Data.integer(r.get("progress")) or int(r.progress) >= Books.PAGE_TICKS or not Data.integer(r.get("last_tick"), -1) or int(r.last_tick) > tick: return false
	if not s.reading.is_empty() and int(s.reading.page) == Books.BOOKS[s.reading.book_id].size() and int(s.reading.progress) != 0: return false
	for glyph in s.symbols:
		var row = s.symbols[glyph]
		if glyph not in GLYPHS or not row is Dictionary or row.size() != 3 or row.get("category") not in CATEGORIES or not unit(row.get("confidence")) or not Data.integer(row.get("tick")) or int(row.tick) > tick: return false
	return true

static func unit(v: Variant) -> bool:
	return Data.number(v) and float(v) >= 0.0 and float(v) <= 1.0

