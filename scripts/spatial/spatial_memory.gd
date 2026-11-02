extends RefCounted
## Evidence and hypotheses only. This module never receives a world reference.
const Data = preload("res://scripts/core/sim_data.gd")
const LIMIT := 64
const TTL := 36000
const RETRY := 45
const REASSESS := 1800
const ABANDON_EXPECTATION := 0.25
const REASONS := ["", "spatial.expected", "spatial.explore", "spatial.inspect", "spatial.failure", "spatial.visible"]

static func empty(cell_size: float = 80.0) -> Dictionary:
	return {"version": 1, "enabled": true, "cell_size": cell_size, "lugares": [],
		"objetivo_atual": "", "motivo": "", "busca_indice": -1, "arrival_tick": -1,
		"buscas": 0, "detour_until": 0, "explore_until": 0, "systematic": false}

static func enable_revision(s: Dictionary) -> void:
	# Opt-in at new-world creation. Existing v1 saves retain their exact policy.
	s.version = 2
	s["scan_mask"] = 0

static func revised(s: Dictionary) -> bool:
	return int(s.get("version", 1)) == 2

static func key_for(resource: String, pos: Vector2, cell_size: float) -> String:
	return "%s:%d:%d" % [resource, floori(pos.x / cell_size), floori(pos.y / cell_size)]

static func refresh(row: Dictionary, tick: int) -> void:
	row.expectativa = snappedf(float(row.alpha) / (float(row.alpha) + float(row.beta)), 0.000001)
	row.confianca = snappedf(minf(0.98, 0.25 + 0.15 * (float(row.alpha) + float(row.beta))) / (1.0 + maxf(0.0, tick - float(row.ultimo_tick)) / 6000.0), 0.000001)

static func maintain(s: Dictionary, tick: int) -> void:
	for i in range(s.lugares.size() - 1, -1, -1):
		if tick - int(s.lugares[i].ultimo_tick) > TTL:
			s.lugares.remove_at(i)
		else:
			refresh(s.lugares[i], tick)
	if not s.objetivo_atual.is_empty() and find(s, s.objetivo_atual).is_empty():
		s.objetivo_atual = ""
		s.arrival_tick = -1

static func find(s: Dictionary, key: String) -> Dictionary:
	for row in s.lugares:
		if row.id == key: return row
	return {}

static func evidence(s: Dictionary, resource: String, pos: Vector2, tick: int, success: bool, gain: float = 0.0, source: String = "observado", coverage: float = 1.0) -> void:
	if not s.enabled: return
	coverage = clampf(coverage, 0.0, 1.0)
	if not success and revised(s) and coverage <= 0.0: return
	var key := key_for(resource, pos, float(s.cell_size))
	var row := find(s, key)
	if row.is_empty():
		if not success: return
		if s.lugares.size() >= LIMIT:
			s.lugares.sort_custom(func(a, b): return float(a.confianca) < float(b.confianca))
			s.lugares.pop_front()
		row = {"id": key, "recurso": resource, "pos": Data.pack_vector(pos), "visitas": 0,
			"achados": 0, "falhas": 0, "ultimo_tick": tick, "ganho_medio": 10.0,
			"expectativa": 0.5, "confianca": 0.0, "fonte": source,
			"alpha": 0.5, "beta": 0.5, "consecutivas": 0, "retry_tick": 0}
		s.lugares.append(row)
	elif source == "observado" and success and tick - int(row.ultimo_tick) < 60:
		return # One stationary sighting is not hundreds of independent visits.
	row.visitas = mini(1000000, int(row.visitas) + 1)
	row.ultimo_tick = tick
	if success:
		row.achados = mini(1000000, int(row.achados) + 1)
		row.alpha = snappedf(float(row.alpha) * 0.7 + 1.0, 0.000001)
		row.beta = snappedf(float(row.beta) * 0.7, 0.000001)
		row.consecutivas = 0
		row.retry_tick = 0
		row.pos = Data.pack_vector(pos)
		if source == "interagido":
			row.fonte = source
			row.ganho_medio = snappedf(lerpf(float(row.ganho_medio), maxf(0.0, gain), 0.6), 0.000001)
	else:
		row.falhas = mini(1000000, int(row.falhas) + 1)
		row.consecutivas = mini(1000000, int(row.consecutivas) + 1)
		if revised(s):
			# Missing a resource is informative in proportion to inspected area.
			# A full empty survey outweighs a single earlier positive encounter.
			var discount := pow(0.35, coverage)
			row.alpha = snappedf(float(row.alpha) * discount, 0.000001)
			row.beta = snappedf(float(row.beta) * discount + 1.5 * coverage, 0.000001)
			row.retry_tick = tick + RETRY
		else:
			row.alpha = snappedf(float(row.alpha) * 0.45, 0.000001)
			row.beta = snappedf(float(row.beta) * 0.45 + 1.0, 0.000001)
			row.retry_tick = tick + 180 * mini(10, int(row.consecutivas))
	refresh(row, tick)
	if not success and revised(s) and (float(row.expectativa) < ABANDON_EXPECTATION or int(row.consecutivas) >= 3):
		row.retry_tick = tick + REASSESS

static func observe(s: Dictionary, sensors: Dictionary, tick: int) -> void:
	if not s.enabled: return
	for pair in [["foods", "comida"], ["waters", "agua"]]:
		for row in sensors.get(pair[0], []):
			evidence(s, pair[1], row.pos, tick, true)
	maintain(s, tick)

static func best(s: Dictionary, resource: String, pos: Vector2, tick: int) -> Dictionary:
	var winner: Dictionary = {}
	var verification: Dictionary = {}
	var verification_value := -1.0
	var highest := 0.015 # Exploration has a small positive opportunity value.
	# Water regions persist physically; one observed shore is usable evidence.
	# When thirst asks for water, a known shore beats blind wandering even at
	# a distance. Food still requires repeated rewards before habitual recall.
	var shore := revised(s) and resource == "agua"
	if shore: highest = 0.0
	if not s.enabled or tick < int(s.explore_until): return winner
	for row in s.lugares:
		if row.recurso != resource or int(row.retry_tick) > tick or int(row.achados) < (1 if shore else 3): continue
		if not revised(s) and int(row.consecutivas) >= 3: continue
		var expectation := float(row.expectativa)
		# An abandoned formerly rewarding site merits a bounded future probe,
		# not a fabricated positive observation. Its posterior stays unchanged.
		if revised(s) and int(row.consecutivas) > 0 and (expectation < ABANDON_EXPECTATION or int(row.consecutivas) >= 3):
			expectation = 0.5
		var value := expectation * float(row.confianca) * float(row.ganho_medio) / (40.0 + pos.distance_to(Data.unpack_vector(row.pos)))
		# A first inconclusive absence creates a short confirmation task. Its
		# information value must not disappear merely because expected food value
		# fell below exploration's reward threshold; abandonment ends this task.
		if revised(s) and int(row.consecutivas) in [1, 2] and float(row.expectativa) >= ABANDON_EXPECTATION and value > verification_value:
			verification = row
			verification_value = value
		if value > highest:
			highest = value
			winner = row
	return verification if winner.is_empty() else winner

static func snapshot(s: Dictionary) -> Dictionary:
	var rows: Array = []
	for row in s.get("lugares", []):
		var copy: Dictionary = {}
		for key in ["id", "pos", "recurso", "expectativa", "confianca", "visitas", "achados", "falhas", "ultimo_tick", "ganho_medio", "fonte"]:
			copy[key] = Data.restore_precision(row[key])
		rows.append(copy)
	return {"lugares": rows, "objetivo_atual": s.get("objetivo_atual", ""), "motivo": s.get("motivo", "")}

static func valid(s: Variant, max_tick: int = 2147483647, size: Vector2 = Vector2(100000, 100000)) -> bool:
	if not s is Dictionary: return false
	if s.is_empty(): return true # Legacy minds keep their historical policy until enabled.
	if not Data.integer(s.get("version"), 1) or int(s.version) not in [1, 2]: return false
	if s.size() != (13 if revised(s) else 12) or not s.get("enabled") is bool or not s.get("systematic") is bool: return false
	if revised(s) and (not Data.integer(s.get("scan_mask")) or int(s.scan_mask) > 131071): return false
	if not Data.integer(s.get("detour_until")) or int(s.detour_until) > max_tick + 30: return false
	if not Data.integer(s.get("explore_until")) or int(s.explore_until) > max_tick + 90: return false
	if not Data.number(s.get("cell_size")) or float(s.cell_size) < 22.5 or float(s.cell_size) > 120.0: return false
	if not s.get("lugares") is Array or s.lugares.size() > LIMIT or not s.get("objetivo_atual") is String or s.objetivo_atual.length() > 64 or s.get("motivo") not in REASONS: return false
	if not Data.integer(s.get("busca_indice"), -1) or int(s.busca_indice) > 100000000 or not Data.integer(s.get("arrival_tick"), -1) or int(s.arrival_tick) > max_tick or not Data.integer(s.get("buscas")): return false
	var ids: Dictionary = {}
	for row in s.lugares:
		if not row is Dictionary or row.size() != 15 or not row.get("id") is String or row.get("recurso") not in ["comida", "agua"] or not Data.vector(row.get("pos")): return false
		var pos := Data.unpack_vector(row.pos)
		if pos.x < 0.0 or pos.y < 0.0 or pos.x > size.x or pos.y > size.y or row.id != key_for(row.recurso, pos, float(s.cell_size)) or ids.has(row.id): return false
		ids[row.id] = true
		for key in ["visitas", "achados", "falhas", "consecutivas"]:
			if not Data.integer(row.get(key)) or int(row[key]) > 1000000: return false
		if int(row.visitas) != int(row.achados) + int(row.falhas) or int(row.consecutivas) > int(row.falhas): return false
		if not Data.integer(row.get("ultimo_tick")) or int(row.ultimo_tick) > max_tick or not Data.integer(row.get("retry_tick")) or int(row.retry_tick) > max_tick + 1800: return false
		if row.get("fonte") not in ["observado", "interagido"]: return false
		for key in ["expectativa", "confianca", "ganho_medio", "alpha", "beta"]:
			if not Data.number(row.get(key)) or float(row[key]) < 0.0: return false
		if float(row.expectativa) > 1.0 or float(row.confianca) > 1.0 or float(row.ganho_medio) > 10000.0 or float(row.alpha) > 4.0 or float(row.beta) > 4.0 or float(row.alpha) + float(row.beta) <= 0.0: return false
		var calculated: Dictionary = row.duplicate()
		refresh(calculated, max_tick)
		if absf(float(row.expectativa) - float(calculated.expectativa)) > 0.000002: return false
	return s.objetivo_atual.is_empty() or ids.has(s.objetivo_atual)
