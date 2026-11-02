extends SceneTree
## X7 new evaluator, opened once only after preregistration and engine freeze.
const Fixture = preload("res://tests/unit/test_sim_m4b.gd")
const World = preload("res://scripts/world/sim_world.gd")
const L = preload("res://scripts/mind/terminal_learning.gd")
const PROTOCOL := "tests/experiments/m4b_terminal_preregistro.md"
const OUTPUT := "reports/M4b_terminal_eval.json"
const FREEZE := "tests/experiments/m4b_freeze.json"
const ARMS := ["completo", "sem_ensino", "aleatorio", "fixo_servo", "sem_memoria"]
var failures: Array = []

func git(args: Array) -> String:
	var output: Array = []
	var status := OS.execute("git", args, output, true)
	if status != 0:
		failures.append("git failed: " + str(args))
		return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func write_result(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("cannot write " + path)
		return
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.flush()
	file.close()

static func canonical_sha(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var source := bytes.get_string_from_utf8()
	# Godot's decoder consumes UTF-8 BOM; Git hashes those original bytes.
	if bytes.size() >= 3 and bytes[0] == 239 and bytes[1] == 187 and bytes[2] == 191 and not source.begins_with("\ufeff"):
		source = "\ufeff" + source
	return source.replace("\r\n", "\n").sha256_text()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var holdout := "--holdout" in args
	var train := "--train" in args
	var path := OUTPUT if holdout else ("builds/m4b_train.json" if train else "builds/m4b_dev.json")
	DirAccess.make_dir_recursive_absolute("builds")
	var meta: Dictionary = {"status": "development", "rows": [], "checks": [], "failures": []}
	if holdout:
		if FileAccess.file_exists(path) or not git(["status", "--porcelain"]).is_empty():
			printerr("X7 refuses existing output or dirty worktree")
			quit(1)
			return
		var frozen = JSON.parse_string(FileAccess.get_file_as_string(FREEZE))
		if not frozen is Dictionary:
			quit(1)
			return
		for file in frozen.files:
			if canonical_sha(file) != frozen.files[file]: failures.append("freeze mismatch " + file)
		if not failures.is_empty():
			printerr(failures)
			quit(1)
			return
		meta.merge({"status": "opened", "preregister_sha256": canonical_sha(PROTOCOL),
			"frozen_commit": git(["rev-parse", "HEAD"]), "preregister_commit": frozen.preregister_commit})
		# Durable marker precedes any access to holdout scenarios.
		write_result(path, meta)
		if not failures.is_empty():
			quit(1)
			return
	var first := 154401 if holdout else (154101 if train else 154201)
	var count := 24 if holdout else (4 if train else 6)
	for seed_value in range(first, first + count):
		for arm in ARMS:
			var memory: Dictionary = L.empty()
			var clock := 0
			for phase in ["acquisition", "same_target", "new_target"]:
				var attempts := 12 if phase == "acquisition" else 6
				for attempt in range(attempts):
					var result := trial(seed_value, arm, phase, attempt, memory, clock)
					clock = int(result.clock)
					memory = result.memory
					result.erase("clock")
					result.erase("memory")
					meta.rows.append(result)
		meta.checks.append(checks(seed_value))
		print("X7 seed ", seed_value, " finished")
	meta.failures = failures
	meta.status = "complete" if failures.is_empty() else "failed"
	meta.summary = summarize(meta.rows, meta.checks)
	write_result(path, meta)
	print("X7 ", meta.summary, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func scenario(seed_value: int, novel: bool = false):
	var w = Fixture.new().studio(seed_value, 0.55 + float(seed_value % 9) * 0.05)
	var c = w.creatures[w.pet_id]
	# New geometry is a scenario fixture, never a production teleport.
	c.pos += Vector2(float(seed_value % 7) * 5.0, float(seed_value % 5) * 4.0)
	if novel: c.pos += Vector2(70, 90)
	w.place_terminal(c.pos)
	return w

func target_for(seed_value: int, novel: bool) -> Vector2i:
	var distance := 2 + seed_value % 5
	var sign_value := 1 if seed_value % 2 == 0 else -1
	return Vector2i(0, distance * sign_value) if novel else Vector2i(distance * sign_value, 0)

func trial(seed_value: int, arm: String, phase: String, attempt: int, memory: Dictionary, clock: int) -> Dictionary:
	var novel := phase == "new_target"
	var w = scenario(seed_value, novel)
	var c = w.creatures[w.pet_id]
	var device: int = w.terminals[0].id
	w.tick = clock + 1
	c.mind.terminal = memory.duplicate(true)
	c.mind.terminal.active = {}
	c.mind.terminal.cooldown = 0
	var target := target_for(seed_value, novel)
	w.terminal_set_task(c, "marcar_mover", target)
	if arm != "sem_ensino" and phase == "acquisition" and attempt == 0:
		Fixture.new().teach(w, c, device)
	if arm == "sem_memoria": c.mind.terminal.table = {}
	var s: Dictionary = c.mind.terminal
	var chosen: String = c.mind.decide(c, w.tick, w.sense(c))
	var source := L.choose(s)
	if arm == "aleatorio":
		var programs := L.candidates(s)
		var r := World.Rng.new(seed_value * 1009 + attempt * 23 + ["acquisition", "same_target", "new_target"].find(phase) * 101)
		source = programs[r.generator.randi_range(0, programs.size() - 1)]
	elif arm == "fixo_servo":
		var direction := "LESTE" if target.x >= 0 else "OESTE"
		if novel: direction = "SUL" if target.y >= 0 else "NORTE"
		var units := maxi(absi(target.x), absi(target.y))
		source = "MARCAR %d %d\nMOVER %s %d\nMOVER %s %d" % [target.x, target.y, direction, units, direction, units]
	var initial_energy: float = c.energy
	var initial_position: Vector2 = c.pos
	var outcomes: int = s.outcomes.size()
	var success := false
	var used_ticks := 0
	var error := "recusa"
	if chosen == "usar_terminal" and w.terminal_start(c, device, source):
		for i in range(40):
			w.step()
			used_ticks += 1
			if s.outcomes.size() > outcomes:
				var last: Dictionary = s.outcomes[-1]
				success = last.success
				error = last.error
				break
	if not s.active.is_empty(): w._terminal_finish(c, "tempo")
	return {"seed": seed_value, "arm": arm, "phase": phase, "attempt": attempt, "program": source,
		"success": success, "error": error, "ticks": used_ticks, "energy_cost": initial_energy - c.energy,
		"displacement": c.pos.distance_to(initial_position), "known": s.state.conhecidos.size(), "clock": w.tick,
		"memory": s.duplicate(true)}

func checks(seed_value: int) -> Dictionary:
	var w = scenario(seed_value)
	var c = w.creatures[w.pet_id]
	var device: int = w.terminals[0].id
	Fixture.new().teach(w, c, device)
	w.terminal_set_task(c, "marcar_mover", Vector2i(3, 0))
	var s: Dictionary = c.mind.terminal
	var program := "MARCAR 3 0\nMOVER LESTE 3"
	# Acquire the prior success through real actions, then present a new collision.
	w.tick += 1
	w.terminal_start(c, device, program)
	w.terminal_step(c, device)
	w.tick += 1
	w.terminal_step(c, device)
	var learned := s.duplicate(true)
	w = scenario(seed_value)
	c = w.creatures[w.pet_id]
	device = int(w.terminals[0].id)
	w.tick = int(learned.last_tick) + 1
	c.mind.terminal = learned
	s = c.mind.terminal
	var before_score := L.score(s, program)
	var before_choice := L.choose(s)
	w.place_obstacle(c.pos + Vector2(10, 0), 1.0)
	w.tick += 1
	w.terminal_start(c, device, program)
	w.terminal_step(c, device)
	w.tick += 1
	w.terminal_step(c, device)
	var after_score := L.score(s, program)
	var after_choice := L.choose(s)
	var error_recorded: bool = not s.state.tentativas.is_empty() and s.state.tentativas[-1].erro == "recusado"
	# Retention/continuation uses a separate unobstructed active program.
	var retain = scenario(seed_value + 10000)
	var actor = retain.creatures[retain.pet_id]
	var rd: int = retain.terminals[0].id
	Fixture.new().teach(retain, actor, rd)
	retain.terminal_set_task(actor, "marcar_mover", Vector2i(6, 0))
	actor.mind.terminal.table = s.table.duplicate(true)
	actor.mind.terminal.outcomes = s.outcomes.duplicate(true)
	retain.tick = w.tick + 1
	actor.mind.terminal.state = s.state.duplicate(true)
	actor.mind.decide(actor, retain.tick, retain.sense(actor))
	retain.terminal_start(actor, rd, "MARCAR 6 0\nMOVER LESTE 3\nMOVER LESTE 3")
	retain.terminal_step(actor, rd)
	var restored = World.from_dict(JSON.parse_string(JSON.stringify(retain.to_dict())))
	var retained: bool = restored != null
	var continuation := retained
	if retained:
		retained = actor.terminal_snapshot() == restored.creatures[restored.pet_id].terminal_snapshot()
		retained = retained and L.choose(actor.mind.terminal) == L.choose(restored.creatures[restored.pet_id].mind.terminal)
		for i in range(20):
			retain.step()
			restored.step()
		continuation = JSON.stringify(retain.to_dict(), "", true, true) == JSON.stringify(restored.to_dict(), "", true, true)
	var a = Fixture.new().studio(seed_value, 0.0)
	var b = Fixture.new().studio(seed_value, 0.0)
	var ac = a.creatures[a.pet_id]
	var bc = b.creatures[b.pet_id]
	a.place_terminal(ac.pos)
	a.terminal_refuse(ac, 1000)
	for i in range(200):
		a.step()
		b.step()
	var autonomy: bool = ac.alive and bc.alive and [ac.pos, ac.energy, ac.hydration] == [bc.pos, bc.energy, bc.hydration] and ac.mind.terminal.state.tentativas.is_empty()
	if not retained or not continuation: failures.append("retention " + str(seed_value))
	return {"seed": seed_value, "error_recorded": error_recorded, "score_before": before_score, "score_after": after_score,
		"choice_before": before_choice, "choice_after": after_choice, "repeat_after_error": after_choice == program,
		"autonomy": autonomy, "retained": retained, "continuation": continuation}

func summarize(rows: Array, observations: Array) -> Dictionary:
	var result: Dictionary = {}
	for arm in ARMS:
		result[arm] = {}
		for phase in ["acquisition", "same_target", "new_target"]:
			var selected := rows.filter(func(r): return r.arm == arm and r.phase == phase)
			result[arm][phase] = {"n": selected.size(), "successes": selected.filter(func(r): return r.success).size(), "errors": selected.filter(func(r): return r.error != "").size()}
	result.checks = {"n": observations.size(), "error_reduction": observations.filter(func(r): return r.error_recorded and r.score_after < r.score_before).size(),
		"autonomy": observations.filter(func(r): return r.autonomy).size(), "retention": observations.filter(func(r): return r.retained and r.continuation).size()}
	var rates: Dictionary = {}
	for arm in ARMS:
		var selected := rows.filter(func(r): return r.arm == arm)
		rates[arm] = float(selected.filter(func(r): return r.success).size()) / maxf(1.0, selected.size())
	var general_seeds: Dictionary = {}
	for row in rows:
		if row.arm == "completo" and row.phase == "new_target" and row.success: general_seeds[row.seed] = true
	result.rates = rates
	result.hypotheses = {"H-a": rates.completo - rates.sem_ensino >= 0.20,
		"H-b": general_seeds.size() >= int(ceil(observations.size() * 0.75)),
		"H-c": rates.completo - rates.aleatorio >= 0.10 and rates.completo - rates.sem_memoria >= 0.10 and rates.completo > rates.fixo_servo,
		"H-d": observations.all(func(r): return r.error_recorded and r.score_after < r.score_before and r.choice_before != r.choice_after and not r.repeat_after_error),
		"H-e": observations.all(func(r): return r.autonomy), "H-f": observations.all(func(r): return r.retained and r.continuation)}
	result.verdict = "FAIL" if not failures.is_empty() else ("PASS" if result.hypotheses.values().all(func(v): return v) else "PARTIAL")
	return result
