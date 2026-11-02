extends RefCounted
## Evidence, hypotheses, local map, blocks and reinforced routes.
## This module never receives a world reference.
const Data = preload("res://scripts/core/sim_data.gd")
const Planner = preload("res://scripts/spatial/spatial_planner.gd")

const LIMIT := 64
const MAP_LIMIT := 512
const BLOCK_LIMIT := 64
const ROUTE_LIMIT := 32
const TTL := 36000
const RETRY := 45
const REASSESS := 1800
const ABANDON_EXPECTATION := 0.25
const REASONS := ["", "spatial.expected", "spatial.explore", "spatial.inspect", "spatial.failure", "spatial.visible", "spatial.blocked", "spatial.replan", "spatial.route_success"]

static func empty(cell_size: float = 40.0) -> Dictionary:
	return {
		"version": 3, "enabled": true, "cell_size": cell_size, "lugares": [],
		"objetivo_atual": "", "motivo": "", "busca_indice": -1, "arrival_tick": -1,
		"buscas": 0, "detour_until": 0, "explore_until": 0, "systematic": false,
		"scan_mask": 0, "mapa": {}, "bloqueios": [], "rotas": [],
		"plano_atual": [], "plano_indice": 0, "current_journey": [],
		"bounds": [1200.0, 800.0]
	}

static func enable_revision(s: Dictionary) -> void:
	if int(s.get("version", 1)) < 3:
		s.version = 3
		if not s.has("scan_mask"): s["scan_mask"] = 0
		if not s.has("mapa"): s["mapa"] = {}
		if not s.has("bloqueios"): s["bloqueios"] = []
		if not s.has("rotas"): s["rotas"] = []
		if not s.has("plano_atual"): s["plano_atual"] = []
		if not s.has("plano_indice"): s["plano_indice"] = 0
		if not s.has("current_journey"): s["current_journey"] = []
		if not s.has("bounds"): s["bounds"] = [1200.0, 800.0]

static func revised(s: Dictionary) -> bool:
	return int(s.get("version", 1)) >= 2

static func has_planning(s: Dictionary) -> bool:
	return int(s.get("version", 1)) >= 3

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
	
	if has_planning(s):
		# Maintain routes with decay and forgetting
		var rotas: Array = s.get("rotas", [])
		for i in range(rotas.size() - 1, -1, -1):
			var r: Dictionary = rotas[i]
			var age: int = tick - int(r.get("ultimo_tick", tick))
			if age > TTL or float(r.get("peso", 1.0)) <= 0.05:
				rotas.remove_at(i)
			else:
				var decay: float = float(age) / 20000.0
				r.peso = snappedf(maxf(0.05, float(r.peso) - decay * 0.01), 0.000001)
		
		# Maintain blocks TTL
		var bloqueios: Array = s.get("bloqueios", [])
		for i in range(bloqueios.size() - 1, -1, -1):
			if tick - int(bloqueios[i].get("ultimo_tick", tick)) > TTL:
				bloqueios.remove_at(i)

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
		return
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

static func observe(s: Dictionary, sensors: Dictionary, tick: int, creature = null) -> void:
	if not s.enabled: return
	for pair in [["foods", "comida"], ["waters", "agua"]]:
		for row in sensors.get(pair[0], []):
			evidence(s, pair[1], row.pos, tick, true)
	if has_planning(s):
		observe_grid(s, creature, sensors, tick)
	maintain(s, tick)

static func observe_grid(s: Dictionary, creature, sensors: Dictionary, tick: int) -> void:
	var cell_size: float = float(s.cell_size)
	if cell_size <= 0.0: cell_size = 40.0
	var mapa: Dictionary = s.mapa
	var obstacles: Array = sensors.get("obstacles", [])
	
	var b_arr: Array = s.get("bounds", [1200.0, 800.0])
	var max_c := maxi(1, ceili(float(b_arr[0]) / cell_size))
	var max_r := maxi(1, ceili(float(b_arr[1]) / cell_size))
	# 1. Update blocked cells from visible obstacles
	for obs in obstacles:
		var center: Vector2 = obs.pos
		var rad: float = float(obs.radius)
		var min_x := clampi(floori((center.x - rad) / cell_size), 0, max_c - 1)
		var max_x := clampi(floori((center.x + rad) / cell_size), 0, max_c - 1)
		var min_y := clampi(floori((center.y - rad) / cell_size), 0, max_r - 1)
		var max_y := clampi(floori((center.y + rad) / cell_size), 0, max_r - 1)
		for gx in range(min_x, max_x + 1):
			for gy in range(min_y, max_y + 1):
				var k := "%d:%d" % [gx, gy]
				if mapa.size() < MAP_LIMIT or mapa.has(k):
					mapa[k] = {"pos": [gx, gy], "estado": "bloqueada", "confianca": 1.0, "tick": tick}
	
	# 2. Update free space from sensory FOV
	if creature != null:
		var vision: float = creature.genome.vision_range
		var fov: float = creature.genome.vision_fov
		var c_pos: Vector2 = creature.pos
		var c_heading: float = creature.heading
		var min_gx := clampi(floori((c_pos.x - vision) / cell_size), 0, max_c - 1)
		var max_gx := clampi(floori((c_pos.x + vision) / cell_size), 0, max_c - 1)
		var min_gy := clampi(floori((c_pos.y - vision) / cell_size), 0, max_r - 1)
		var max_gy := clampi(floori((c_pos.y + vision) / cell_size), 0, max_r - 1)
		for gx in range(min_gx, max_gx + 1):
			for gy in range(min_gy, max_gy + 1):
				var k := "%d:%d" % [gx, gy]
				var c_center := Vector2((float(gx) + 0.5) * cell_size, (float(gy) + 0.5) * cell_size)
				var delta := c_center - c_pos
				var dist := delta.length()
				if dist > vision or dist < 2.0: continue
				var ang_diff := absf(wrapf(delta.angle() - c_heading, -PI, PI))
				if ang_diff > fov * 0.5: continue
				
				# Ensure line from creature to cell center is not occluded by visible obstacles
				var clear := true
				for obs in obstacles:
					var closest := Geometry2D.get_closest_point_to_segment(obs.pos, c_pos, c_center)
					if closest.distance_to(obs.pos) < float(obs.radius):
						clear = false
						break
				if clear:
					if not mapa.has(k) or mapa[k].estado != "bloqueada":
						if mapa.size() < MAP_LIMIT or mapa.has(k):
							mapa[k] = {"pos": [gx, gy], "estado": "livre", "confianca": 0.9, "tick": tick}
	
	# Check if current planned path has any newly blocked cells
	var plan: Array = s.get("plano_atual", [])
	var plan_idx: int = int(s.get("plano_indice", 0))
	for i in range(plan_idx, plan.size()):
		var pt = plan[i]
		if not Data.vector(pt): continue
		var wp := Data.unpack_vector(pt)
		var gx := floori(wp.x / cell_size)
		var gy := floori(wp.y / cell_size)
		var k := "%d:%d" % [gx, gy]
		if mapa.get(k, {}).get("estado", "") == "bloqueada":
			s.plano_atual = []
			s.plano_indice = 0
			break

static func record_block(s: Dictionary, creature, tick: int) -> void:
	if not s.enabled or not has_planning(s) or creature == null: return
	var cell_size: float = float(s.cell_size)
	if cell_size <= 0.0: cell_size = 40.0
	var speed_dt: float = creature.genome.speed * 0.1
	var ahead: Vector2 = creature.pos + Vector2.from_angle(creature.heading) * (speed_dt + creature.genome.size + 4.0)
	var b_arr: Array = s.get("bounds", [1200.0, 800.0])
	var max_c := maxi(1, ceili(float(b_arr[0]) / cell_size))
	var max_r := maxi(1, ceili(float(b_arr[1]) / cell_size))
	var gx := clampi(floori(ahead.x / cell_size), 0, max_c - 1)
	var gy := clampi(floori(ahead.y / cell_size), 0, max_r - 1)
	var k := "%d:%d" % [gx, gy]
	
	if s.mapa.size() < MAP_LIMIT or s.mapa.has(k):
		s.mapa[k] = {"pos": [gx, gy], "estado": "bloqueada", "confianca": 1.0, "tick": tick}
	
	var found := false
	for b in s.bloqueios:
		if int(b.pos[0]) == gx and int(b.pos[1]) == gy:
			b.tentativas = mini(1000000, int(b.tentativas) + 1)
			b.ultimo_tick = tick
			found = true
			break
	if not found and s.bloqueios.size() < BLOCK_LIMIT:
		s.bloqueios.append({"pos": [gx, gy], "tentativas": 1, "ultimo_tick": tick})
	
	s.plano_atual = []
	s.plano_indice = 0

static func step_journey(s: Dictionary, creature) -> void:
	if not s.enabled or not has_planning(s) or creature == null: return
	var cell_size: float = float(s.cell_size)
	if cell_size <= 0.0: cell_size = 40.0
	var b_arr: Array = s.get("bounds", [1200.0, 800.0])
	var max_c := maxi(1, ceili(float(b_arr[0]) / cell_size))
	var max_r := maxi(1, ceili(float(b_arr[1]) / cell_size))
	var gx := clampi(floori(creature.pos.x / cell_size), 0, max_c - 1)
	var gy := clampi(floori(creature.pos.y / cell_size), 0, max_r - 1)
	var journey: Array = s.get("current_journey", [])
	if journey.is_empty() or journey.back()[0] != gx or journey.back()[1] != gy:
		if journey.size() < 128:
			journey.append([gx, gy])

static func record_route_success(s: Dictionary, resource: String, tick: int) -> void:
	if not s.enabled or not has_planning(s): return
	var journey: Array = s.get("current_journey", [])
	if journey.size() >= 2:
		var orig = journey.front()
		var dest = journey.back()
		var found := false
		for route in s.rotas:
			if route.recurso == resource and int(route.origem[0]) == int(orig[0]) and int(route.origem[1]) == int(orig[1]) and int(route.destino[0]) == int(dest[0]) and int(route.destino[1]) == int(dest[1]):
				route.usos = mini(1000000, int(route.usos) + 1)
				route.sucessos = mini(1000000, int(route.sucessos) + 1)
				route.ultimo_tick = tick
				route.peso = snappedf(minf(5.0, float(route.peso) + 0.4), 0.000001)
				if journey.size() <= route.celulas.size():
					route.celulas = journey.duplicate(true)
				found = true
				break
		if not found and s.rotas.size() < ROUTE_LIMIT:
			s.rotas.append({
				"id": "rota_%d" % [s.rotas.size() + 1],
				"origem": [int(orig[0]), int(orig[1])],
				"destino": [int(dest[0]), int(dest[1])],
				"recurso": resource,
				"celulas": journey.duplicate(true),
				"usos": 1,
				"sucessos": 1,
				"ultimo_tick": tick,
				"peso": 1.0
			})
	s.current_journey = []
	s.plano_atual = []
	s.plano_indice = 0

static func best(s: Dictionary, resource: String, pos: Vector2, tick: int) -> Dictionary:
	var winner: Dictionary = {}
	var verification: Dictionary = {}
	var verification_value := -1.0
	var highest := 0.015
	var shore := revised(s) and resource == "agua"
	if shore: highest = 0.0
	if not s.enabled or tick < int(s.explore_until): return winner
	for row in s.lugares:
		if row.recurso != resource or int(row.retry_tick) > tick or int(row.achados) < (1 if shore else 3): continue
		if not revised(s) and int(row.consecutivas) >= 3: continue
		var expectation := float(row.expectativa)
		if revised(s) and int(row.consecutivas) > 0 and (expectation < ABANDON_EXPECTATION or int(row.consecutivas) >= 3):
			expectation = 0.5
		var value := expectation * float(row.confianca) * float(row.ganho_medio) / (40.0 + pos.distance_to(Data.unpack_vector(row.pos)))
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
	var mapa_rows: Array = []
	for k in s.get("mapa", {}):
		var c = s.mapa[k]
		mapa_rows.append({"pos": [int(c.pos[0]), int(c.pos[1])], "estado": str(c.estado), "confianca": Data.restore_precision(c.confianca), "tick": int(c.tick)})
	var bloqueios_rows: Array = []
	for b in s.get("bloqueios", []):
		bloqueios_rows.append({"pos": [int(b.pos[0]), int(b.pos[1])], "tentativas": int(b.tentativas), "ultimo_tick": int(b.ultimo_tick)})
	var rotas_rows: Array = []
	for r in s.get("rotas", []):
		var cells_copy: Array = []
		for c in r.get("celulas", []):
			cells_copy.append([int(c[0]), int(c[1])])
		rotas_rows.append({
			"id": str(r.id),
			"origem": [int(r.origem[0]), int(r.origem[1])],
			"destino": [int(r.destino[0]), int(r.destino[1])],
			"recurso": str(r.recurso),
			"celulas": cells_copy,
			"usos": int(r.usos),
			"sucessos": int(r.sucessos),
			"ultimo_tick": int(r.ultimo_tick),
			"peso": Data.restore_precision(r.peso)
		})
	return {
		"lugares": rows,
		"objetivo_atual": s.get("objetivo_atual", ""),
		"motivo": s.get("motivo", ""),
		"mapa_local": mapa_rows,
		"bloqueios": bloqueios_rows,
		"rotas": rotas_rows
	}

static func valid(s: Variant, max_tick: int = 2147483647, size: Vector2 = Vector2(100000, 100000)) -> bool:
	if not s is Dictionary: return false
	if s.is_empty(): return true
	if not Data.integer(s.get("version"), 1) or int(s.version) not in [1, 2, 3]: return false
	var ver: int = int(s.version)
	var expected_size := 12 if ver == 1 else (13 if ver == 2 else 20)
	if s.size() != expected_size or not s.get("enabled") is bool or not s.get("systematic") is bool: return false
	if ver >= 2 and (not Data.integer(s.get("scan_mask")) or int(s.scan_mask) > 131071): return false
	if not Data.integer(s.get("detour_until")) or int(s.detour_until) > max_tick + 30: return false
	if not Data.integer(s.get("explore_until")) or int(s.explore_until) > max_tick + 90: return false
	if not Data.number(s.get("cell_size")) or float(s.cell_size) < 22.5 or float(s.cell_size) > 120.0: return false
	var cell_size: float = float(s.cell_size)
	var max_cols := maxi(1, ceili(size.x / cell_size))
	var max_rows := maxi(1, ceili(size.y / cell_size))
	
	if not s.get("lugares") is Array or s.lugares.size() > LIMIT or not s.get("objetivo_atual") is String or s.objetivo_atual.length() > 64 or s.get("motivo") not in REASONS: return false
	if not Data.integer(s.get("busca_indice"), -1) or int(s.busca_indice) > 100000000 or not Data.integer(s.get("arrival_tick"), -1) or int(s.arrival_tick) > max_tick or not Data.integer(s.get("buscas")): return false
	
	var ids: Dictionary = {}
	for row in s.lugares:
		if not row is Dictionary or row.size() != 15 or not row.get("id") is String or row.get("recurso") not in ["comida", "agua"] or not Data.vector(row.get("pos")): return false
		var pos := Data.unpack_vector(row.pos)
		if pos.x < 0.0 or pos.y < 0.0 or pos.x > size.x or pos.y > size.y or row.id != key_for(row.recurso, pos, cell_size) or ids.has(row.id): return false
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
	
	if ver >= 3:
		if not s.get("bounds") is Array or s.bounds.size() != 2 or not Data.number(s.bounds[0]) or not Data.number(s.bounds[1]): return false
		if float(s.bounds[0]) <= 0.0 or float(s.bounds[1]) <= 0.0: return false
		if not s.get("mapa") is Dictionary or s.mapa.size() > MAP_LIMIT: return false
		for k in s.mapa:
			var c = s.mapa[k]
			if not c is Dictionary or c.size() != 4: return false
			var pos_arr = c.get("pos")
			if not pos_arr is Array or pos_arr.size() != 2 or not Data.integer(pos_arr[0]) or not Data.integer(pos_arr[1]): return false
			var gx: int = int(pos_arr[0])
			var gy: int = int(pos_arr[1])
			if gx < 0 or gx >= max_cols or gy < 0 or gy >= max_rows or k != "%d:%d" % [gx, gy]: return false
			if c.get("estado") not in ["desconhecida", "livre", "bloqueada"]: return false
			if not Data.number(c.get("confianca")) or float(c.confianca) < 0.0 or float(c.confianca) > 1.0: return false
			if not Data.integer(c.get("tick")) or int(c.tick) > max_tick: return false
		
		if not s.get("bloqueios") is Array or s.bloqueios.size() > BLOCK_LIMIT: return false
		var used_block_pos: Dictionary = {}
		for b in s.bloqueios:
			if not b is Dictionary or b.size() != 3: return false
			var pos_arr = b.get("pos")
			if not pos_arr is Array or pos_arr.size() != 2 or not Data.integer(pos_arr[0]) or not Data.integer(pos_arr[1]): return false
			var gx: int = int(pos_arr[0])
			var gy: int = int(pos_arr[1])
			if gx < 0 or gx >= max_cols or gy < 0 or gy >= max_rows: return false
			var bk := "%d:%d" % [gx, gy]
			if used_block_pos.has(bk): return false
			used_block_pos[bk] = true
			if not Data.integer(b.get("tentativas"), 1) or int(b.tentativas) > 1000000: return false
			if not Data.integer(b.get("ultimo_tick")) or int(b.ultimo_tick) > max_tick: return false
		
		if not s.get("rotas") is Array or s.rotas.size() > ROUTE_LIMIT: return false
		var used_route_ids: Dictionary = {}
		for r in s.rotas:
			if not r is Dictionary or r.size() != 9: return false
			if not r.get("id") is String or r.id.length() > 64 or used_route_ids.has(r.id): return false
			used_route_ids[r.id] = true
			if r.get("recurso") not in ["comida", "agua"]: return false
			for end_key in ["origem", "destino"]:
				var pt = r.get(end_key)
				if not pt is Array or pt.size() != 2 or not Data.integer(pt[0]) or not Data.integer(pt[1]): return false
				if int(pt[0]) < 0 or int(pt[0]) >= max_cols or int(pt[1]) < 0 or int(pt[1]) >= max_rows: return false
			if not r.get("celulas") is Array or r.celulas.size() > 128: return false
			for cell_item in r.celulas:
				if not cell_item is Array or cell_item.size() != 2 or not Data.integer(cell_item[0]) or not Data.integer(cell_item[1]): return false
				if int(cell_item[0]) < 0 or int(cell_item[0]) >= max_cols or int(cell_item[1]) < 0 or int(cell_item[1]) >= max_rows: return false
			if not Data.integer(r.get("usos")) or not Data.integer(r.get("sucessos")): return false
			if int(r.usos) < int(r.sucessos) or int(r.sucessos) < 0 or int(r.usos) > 1000000: return false
			if not Data.integer(r.get("ultimo_tick")) or int(r.ultimo_tick) > max_tick: return false
			if not Data.number(r.get("peso")) or float(r.peso) < 0.0 or float(r.peso) > 10.0: return false
		
		if not s.get("plano_atual") is Array or s.plano_atual.size() > 128: return false
		for pt in s.plano_atual:
			if not Data.vector(pt): return false
			var wp := Data.unpack_vector(pt)
			if wp.x < 0.0 or wp.x > size.x or wp.y < 0.0 or wp.y > size.y: return false
		if not Data.integer(s.get("plano_indice")) or int(s.plano_indice) < 0 or int(s.plano_indice) > 128: return false
		if not s.get("current_journey") is Array or s.current_journey.size() > 128: return false
		for cell_item in s.current_journey:
			if not cell_item is Array or cell_item.size() != 2 or not Data.integer(cell_item[0]) or not Data.integer(cell_item[1]): return false
			if int(cell_item[0]) < 0 or int(cell_item[0]) >= max_cols or int(cell_item[1]) < 0 or int(cell_item[1]) >= max_rows: return false
	
	return s.objetivo_atual.is_empty() or ids.has(s.objetivo_atual)
