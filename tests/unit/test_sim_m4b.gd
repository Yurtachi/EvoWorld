extends RefCounted
const Fixture = preload("res://tests/unit/test_sim_m3.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Learning = preload("res://scripts/mind/terminal_learning.gd")
const Pure = preload("res://scripts/terminal/terminal.gd")
const Adapter = preload("res://scripts/terminal/terminal_mundo_real.gd")
const State = preload("res://scripts/terminal/terminal_estado.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func check(ok: bool, message: String, failures: Array) -> void:
	if not ok: failures.append(message)

func studio(seed_value: int = 154001, curiosity: float = 0.85):
	return Fixture.new().studio(seed_value, curiosity)

func teach(w, c, device: int) -> void:
	for i in range(3):
		w.tick += 1
		w.terminal_offer_manual(c, device)

func run() -> Array:
	var f: Array = []
	_physics_and_budget(f)
	_autonomy(f)
	_save_and_hostile(f)
	_migrations(f)
	_drawing(f)
	return f

func _physics_and_budget(f: Array) -> void:
	var w = studio()
	var c = w.creatures[w.pet_id]
	var device: int = w.place_terminal(c.pos)
	check(device > 0 and w.terminals.size() == 1, "terminal fisico ausente", f)
	check(w.place_terminal(Vector2(NAN, 0)) == -1, "terminal NaN aceito", f)
	check(w.sense(c).terminals.size() == 1, "terminal nao percebido", f)
	var before := [c.pos, c.energy, c.hydration]
	check(not w.terminal_start(c, device, "MOVER LESTE 3"), "comando sem descoberta aceito", f)
	check(before == [c.pos, c.energy, c.hydration], "programa recusado alterou corpo", f)
	teach(w, c, device)
	check(w.terminal_snapshot(c).state.conhecidos.has("MOVER"), "manual nao descobriu comandos", f)
	w.tick += 1
	check(w.terminal_start(c, device, "MARCAR 3 0\nMOVER LESTE 3"), "programa conhecido recusado", f)
	w.terminal_step(c, device)
	check(c.pos == before[0] and w.terminal_markers.size() == 1, "mais de uma instrucao no tick", f)
	var mid_energy: float = c.energy
	w.terminal_step(c, device)
	check(c.energy == mid_energy and c.pos == before[0], "reentrada no tick cobrou/executou", f)
	w.tick += 1
	w.terminal_step(c, device)
	check(c.pos.x > before[0].x and c.pos.distance_to(before[0]) <= c.genome.speed * w.TICK_DT and c.energy < mid_energy, "movimento sem fisica/custo", f)
	check(c.mind.terminal.outcomes[-1].success, "sucesso fisico nao registrado", f)
	var observation: Dictionary = w.terminal_observe(c, device)
	check(observation.has("limits") and observation.has("obstacles") and observation.energy == c.energy, "OLHAR nao usa sensores reais", f)
	# Full-source validation must refuse a hostile suffix before any marker.
	for attack in ["MARCAR 1 1\npowershell", "cmd /c dir", "OLHAR; whoami", "LER ../segredo", "REPETIR 999999 { OLHAR }", "OS.execute(x)"]:
		var snapshot: String = JSON.stringify(w.to_dict())
		var count: int = w.terminal_markers.size()
		check(not w.terminal_start(c, device, attack) and count == w.terminal_markers.size(), "hostil teve efeito: " + attack, f)
		check(c.pos.x > before[0].x and not snapshot.is_empty(), "hostil alterou corpo", f)
	# Swept contact blocks even unseen obstacles.
	w.place_obstacle(c.pos + Vector2(10, 0), 1.0)
	var p: Vector2 = c.pos
	check(not w.terminal_move(c, device, "LESTE", 8) and c.pos == p, "terminal atravessou colisao", f)
	var s: Dictionary = c.mind.terminal
	var program := "MOVER LESTE 8"
	var score_before := Learning.score(s, program)
	Learning.feedback(s, program, false, "recusado", w.tick)
	check(Learning.score(s, program) < score_before, "erro nao reduz score", f)
	# The existing recursive security scanner includes the real adapter.
	preload("res://tests/unit/test_terminal.gd").new()._scan("res://scripts/terminal", f)

func _autonomy(f: Array) -> void:
	var w = studio(154002)
	var c = w.creatures[w.pet_id]
	var device: int = w.place_terminal(c.pos + Vector2(50, 0))
	var start: Vector2 = c.pos
	for i in range(60): w.step()
	check(c.pos != start and not c.mind.terminal.state.tentativas.is_empty(), "iniciativa nao aproximou/usou terminal", f)
	c.energy = c.max_energy * 0.3
	c.mind.set_goal("usar_terminal", w.tick, "mind.iniciativa.terminal")
	w.step()
	check(c.mind.objetivo_atual == "comer" and c.last_action != "use_terminal", "fome critica nao prevaleceu", f)
	c.energy = c.max_energy * 0.95
	c.hydration = 30
	w.step()
	check(c.mind.objetivo_atual == "beber", "sede critica nao prevaleceu", f)
	var a = studio(154003, 0.0)
	var b = studio(154003, 0.0)
	var ac = a.creatures[a.pet_id]
	var bc = b.creatures[b.pet_id]
	a.place_terminal(ac.pos)
	a.terminal_refuse(ac, 1000)
	for i in range(200):
		a.step()
		b.step()
	check(ac.alive and bc.alive and [ac.energy, ac.hydration, ac.pos] == [bc.energy, bc.hydration, bc.pos], "recusa prejudicou sobrevivencia", f)
	check(ac.mind.terminal.state.tentativas.is_empty(), "recusa ignorada", f)
	check(not w.terminal_offer_manual(c, device), "manual atravessou sede critica", f)

func _save_and_hostile(f: Array) -> void:
	var w = studio(154004)
	var c = w.creatures[w.pet_id]
	var device: int = w.place_terminal(c.pos)
	teach(w, c, device)
	w.tick += 1
	w.terminal_start(c, device, "MARCAR 6 0\nMOVER LESTE 3\nMOVER LESTE 3")
	w.terminal_step(c, device)
	var d: Dictionary = w.to_dict()
	check(Learning.valid(c.mind.terminal, w.tick), "estado terminal invalido", f)
	var loaded = World.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(loaded != null, "save v13 com sessao ativa recusado", f)
	if loaded != null:
		for i in range(20):
			w.step()
			loaded.step()
		check(Fixture.new().snapshot(w) == Fixture.new().snapshot(loaded), "continuacao terminal divergiu", f)
	var store := Store.new("user://m4b_unit_" + str(OS.get_process_id()))
	var saved: Dictionary = store.save_world(w)
	check(saved.ok and store.load_world().ok, "save em disco v13 falhou: " + str(saved), f)
	for mutation in ["nan", "type", "duplicate", "book_duplicate", "huge", "history", "known", "cursor", "instructions", "future", "identity"]:
		var bad: Dictionary = d.duplicate(true)
		var s: Dictionary = bad.creatures[0].mind.terminal
		match mutation:
			"nan": bad.terminals[0].pos[0] = NAN
			"type": s.last_tick = true
			"duplicate": bad.terminals.append(bad.terminals[0].duplicate(true))
			"book_duplicate": bad.terminals[0].books.append("mapa")
			"huge": bad.terminals.resize(100001)
			"history": s.state.tentativas.resize(100001)
			"known": s.state.conhecidos.MOVER = "inicial"
			"cursor": s.active.index = 99
			"instructions": s.active.instructions = ["MOVER LESTE 8"]
			"future": s.state.tentativas[0].tick = d.tick + 1
			"identity": s.active.terminal_id = bad.creatures[0].id
		check(World.from_dict(bad) == null, "save hostil aceito: " + mutation, f)
	var legacy: Dictionary = studio(154005).to_dict()
	for version in [11, 12]:
		legacy.save_version = version
		var migrated = World.from_dict(legacy)
		check(migrated != null and migrated.to_dict().save_version == 13 and migrated.terminals.is_empty() and migrated.creatures[migrated.pet_id].mind.terminal.is_empty(), "migracao inventou terminal", f)
	legacy.save_version = 12
	check(World._migrate_v12(World._migrate_v12(legacy)) == World._migrate_v12(legacy), "migracao v12 nao idempotente", f)
	legacy.creatures[0].mind.terminal = Learning.empty()
	check(World.from_dict(legacy) == null, "v12 aceitou dados futuros", f)

func _drawing(f: Array) -> void:
	var w = studio(154006)
	var c = w.creatures[w.pet_id]
	var device: int = w.place_terminal(c.pos)
	var board: int = w.place_board(c.pos + Vector2(10, 0))
	w.demonstrar_forma(board, "linha")
	w.terminal_offer_manual(c, device, "livro_desenho")
	check(c.mind.terminal.state.conhecidos.has("DESENHAR"), "manual desenho nao desbloqueou", f)
	var energy: float = c.energy
	for i in range(8):
		w.tick += 1
		w.terminal_start(c, device, "DESENHAR LINHA")
		w.terminal_step(c, device)
	check(c.energy < energy and c.atelier != null and not c.atelier.artifacts.is_empty(), "DESENHAR nao usou primitivas reais", f)
	check(World.from_dict(w.to_dict()) != null, "save com desenho terminal invalido", f)

func _migrations(f: Array) -> void:
	for version in range(1, 13):
		var old: Dictionary
		if version <= 7:
			old = preload("res://tests/unit/test_save_robustez.gd").new()._fixture(version)
			if version == 7:
				# The legacy helper now returns a current world: reconstruct v7.
				old.save_version = 7
				old.config.erase("mind_all")
				old.config.erase("mind_enabled_ids")
				for body in old.creatures: body.erase("mind")
		else:
			old = studio(154007).to_dict()
			old.save_version = version
		var untouched := JSON.stringify(old, "", true, true)
		var migrated = World.from_dict(old)
		check(migrated != null, "fixture migracao v%d invalida" % version, f)
		if migrated == null: continue
		var stable: Dictionary = migrated.to_dict()
		var twice = World.from_dict(stable)
		check(twice != null and twice.to_dict() == stable and migrated.terminals.is_empty(), "roundtrip migracao v%d nao idempotente" % version, f)
		check(untouched == JSON.stringify(old, "", true, true) and migrated.ids.next_id == int(old.next_id) and migrated.rng.to_dict() == old.rng_state, "migracao v%d alterou entrada/RNG/ID" % version, f)
		var bad: Dictionary = old.duplicate(true)
		bad.terminals = []
		check(World.from_dict(bad) == null, "v%d aceitou schema terminal futuro" % version, f)
