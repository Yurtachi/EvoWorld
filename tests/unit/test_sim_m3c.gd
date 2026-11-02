extends RefCounted
const Fixture = preload("res://tests/unit/test_sim_m3.gd")
const World = preload("res://scripts/world/sim_world.gd")
const K = preload("res://scripts/library/knowledge.gd")
const Books = preload("res://scripts/library/book_catalog.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func run() -> Array:
	var f: Array = []
	var w = Fixture.new().studio(140010)
	var c = w.creatures[w.pet_id]
	var book: int = w.place_book(c.pos + Vector2(45, 0), "guia_capsulas")
	check(book > 0 and not w.read_book(c, book), "leitura remota aceita", f)
	var before := [c.energy, c.hydration, c.pos]
	K.add(c.mind, {"pedra": 0.0}, "observado", 0.35, w.tick)
	K.demonstrate(c.mind, "anel", "pedra", true, w.tick)
	check(before == [c.energy, c.hydration, c.pos], "conhecimento alterou corpo", f)
	for i in range(50): w.step()
	check(c.knowledge_snapshot().facts.any(func(row): return row.fonte == "livro:guia_capsulas:1"), "nao houve leitura autonoma", f)
	check(c.pos != before[2], "nao se aproximou fisicamente", f)
	check(c.mind.knowledge.reading.page == 2, "paginas nao foram lidas", f)
	var d: Dictionary = w.to_dict()
	check(World.from_dict(d) != null, "roundtrip leitura invalido", f)
	var store := Store.new("user://m3c_unit_" + str(OS.get_process_id()))
	check(store.save_world(w, "reading").ok and store.load_world("reading").ok, "SaveStore apos leitura", f)
	var clone = World.from_dict(d)
	if clone != null:
		for i in range(20):
			w.step()
			clone.step()
		check(Fixture.new().snapshot(w) == Fixture.new().snapshot(clone), "continuacao determinista divergiu", f)
	var bad: Dictionary
	for mutation in ["nan", "duplicate", "source", "future", "oversize", "book_content", "book_duplicate", "reading_page", "reading_type", "symbol_type", "question_type"]:
		bad = d.duplicate(true)
		var knowledge: Dictionary = bad.creatures[0].mind.knowledge
		match mutation:
			"nan": knowledge.facts[0].confianca = NAN
			"duplicate": knowledge.facts.append(knowledge.facts[0].duplicate(true))
			"source": knowledge.facts[0].fonte = "internet"
			"future": knowledge.facts[0].tick = d.tick + 1
			"oversize": knowledge.facts.resize(100001)
			"book_content":
				for row in knowledge.facts:
					if row.fonte == "livro:guia_capsulas:1": row.conteudo = {"capsula": 1.0}
			"book_duplicate": bad.library.books.append(bad.library.books[0].duplicate(true))
			"reading_page": knowledge.reading.page = 99
			"reading_type": knowledge.reading.progress = true
			"symbol_type": knowledge.symbols.anel.confidence = "0.5"
			"question_type": knowledge.questions = [false]
		check(World.from_dict(bad) == null, "save hostil aceito: " + mutation, f)
	var legacy: Dictionary = Fixture.new().studio(140011).to_dict()
	legacy.save_version = 11
	var migrated = World.from_dict(legacy)
	check(migrated != null and migrated.to_dict().save_version == World.SAVE_VERSION and migrated.creatures[migrated.pet_id].mind.knowledge.is_empty(), "migracao v11 inventou conhecimento", f)
	check(World._migrate_v11(World._migrate_v11(legacy)) == World._migrate_v11(legacy), "migracao v11 nao idempotente", f)
	legacy.creatures[0].mind.knowledge = K.empty()
	check(World.from_dict(legacy) == null, "schema antigo aceitou conhecimento futuro", f)
	_questions_and_outcomes(f)
	var delayed = Fixture.new().studio(140014)
	var dc = delayed.creatures[delayed.pet_id]
	delayed.place_book(dc.pos + Vector2(210,0), "guia_capsulas")
	dc.mind.set_goal("ler", 0, "mind.iniciativa.ler")
	delayed.tick = 80
	dc.mind.decide(dc, delayed.tick, delayed.sense(dc))
	check(World.from_dict(delayed.to_dict()) != null, "timeout de leitura criou estado invalido", f)
	return f

func _questions_and_outcomes(f: Array) -> void:
	var w = Fixture.new().studio(140012)
	var c = w.creatures[w.pet_id]
	var obj: int = w.place_object(c.pos + Vector2(8, 0), "capsula_aversiva")
	var sensors: Dictionary = w.sense(c)
	c.mind.decide(c, w.tick, sensors)
	check(w.pending_questions.size() == 1, "lacuna nao gerou pergunta", f)
	check(World.from_dict(JSON.parse_string(JSON.stringify(w.to_dict()))) != null, "pergunta pendente nao persiste via JSON", f)
	for i in range(10): K.gap(c.mind, c, sensors, w.tick)
	check(w.pending_questions.size() == 1, "spam de pergunta", f)
	var question_id: String = w.pending_questions[0].id
	check(w.responder_pergunta(question_id, "seguro"), "resposta valida recusada", f)
	var fact: Dictionary = c.mind.knowledge.facts[0].duplicate(true)
	check(fact.fonte == "cuidador" and float(fact.confianca) > 0 and float(fact.confianca) < 1, "cuidador virou verdade absoluta", f)
	var trust: float = c.mind.knowledge.sources.cuidador
	var before := [c.energy, c.hydration]
	check(w.interact_object(c, obj), "contato fisico falhou", f)
	check(c.energy < before[0] and c.hydration < before[1], "mundo nao aplicou dano real", f)
	check(c.mind.knowledge.sources.cuidador < trust and c.mind.knowledge.facts[0].confianca < fact.confianca, "experiencia nao corrigiu fonte e fato", f)
	check(c.mind.knowledge.facts[0].fonte == "cuidador" and c.mind.knowledge.facts[-1].evidencia, "proveniencia foi sobrescrita", f)
	check(World.from_dict(JSON.parse_string(JSON.stringify(w.to_dict()))) != null, "pergunta/respondida nao persiste via JSON", f)
	var safe = Fixture.new().studio(140013)
	var sc = safe.creatures[safe.pet_id]
	for i in range(300): sc.mind.decide(sc, i, safe.sense(sc))
	check(safe.pending_questions.is_empty(), "pergunta sem lacuna", f)
	var book: int = safe.place_book(sc.pos, "guia_enganoso")
	for i in range(8):
		safe.tick += 1
		safe.read_book(sc, book)
		check(not safe.read_book(sc, book), "mesmo tick leu duas vezes", f)
	check(sc.mind.knowledge.facts.size() == 1, "pagina nao codificada", f)
	var aversive: int = safe.place_object(sc.pos, "capsula_aversiva")
	safe.interact_object(sc, aversive)
	check(sc.mind.knowledge.sources["livro:guia_enganoso"] < 0.5 and sc.mind.knowledge.facts[0].confianca < 0.5 and K.expectation(sc.mind, "capsula", safe.tick) < 0.0, "livro enganoso nao corrigido", f)
	K.demonstrate(sc.mind, "anel", "capsula", true, safe.tick)
	K.demonstrate(sc.mind, "anel", "capsula", true, safe.tick)
	check(K.association(sc.mind, "anel", safe.tick) == "capsula" and K.association(sc.mind, "onda", safe.tick) == "", "associacao ou holdout desconhecido invalido", f)
	K.demonstrate(sc.mind, "anel", "capsula", false, safe.tick)
	check(K.association(sc.mind, "anel", safe.tick) == "", "feedback negativo ignorado", f)
	var old_count: int = sc.mind.knowledge.facts.size()
	sc.mind.memory_enabled = false
	K.add(sc.mind, {"quadro": 0.0}, "cuidador", 0.5, safe.tick)
	check(K.expectation(sc.mind, "capsula", safe.tick) == 0.0 and sc.mind.knowledge.facts.size() == old_count, "ablacao memoria nao removeu consulta/codificacao", f)
	K.maintain(sc.mind, safe.tick + K.TTL + 1)
	check(sc.mind.knowledge.facts.is_empty(), "esquecimento nao removeu fatos", f)

