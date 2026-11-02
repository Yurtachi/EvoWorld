extends RefCounted
## A finite physical dispenser. It has no reference to creatures or their energy.
const Data = preload("res://scripts/core/sim_data.gd")
const Food = preload("res://scripts/environment/food_catalog.gd")
const LIMIT := 64
const MAX_STOCK := 1000000
const MAX_INTERVAL := 10000000
const MAX_RADIUS := 512.0
const RADIUS := 5.0
const DEFAULTS := {"tipo_alimento": "fruta", "estoque": 0, "intervalo_ticks": 100,
	"capacidade_local": 5, "raio": 40.0, "enabled": true}

static func valid_config(cfg: Dictionary) -> bool:
	if cfg.size() != DEFAULTS.size(): return false
	if not cfg.get("tipo_alimento") is String or not Food.valid_type(cfg.tipo_alimento): return false
	if not Data.integer(cfg.get("estoque")) or int(cfg.estoque) > MAX_STOCK: return false
	if not Data.integer(cfg.get("intervalo_ticks"), 1) or int(cfg.intervalo_ticks) > MAX_INTERVAL: return false
	if not Data.integer(cfg.get("capacidade_local"), 1) or int(cfg.capacidade_local) > 10000: return false
	return cfg.get("enabled") is bool and Data.number(cfg.get("raio")) and float(cfg.raio) >= RADIUS and float(cfg.raio) <= MAX_RADIUS

static func config_from(row: Dictionary) -> Dictionary:
	var cfg: Dictionary = {}
	for key in DEFAULTS: cfg[key] = row.get(key)
	return cfg

static func valid_record(row: Variant, tick: int, next_id: int) -> bool:
	if not row is Dictionary or row.size() != 9: return false
	return Data.integer(row.get("id"), 1) and int(row.id) < next_id and Data.vector(row.get("pos")) and Data.integer(row.get("last_tick")) and int(row.last_tick) <= tick and valid_config(config_from(row))

static func step(world, row: Dictionary) -> void:
	if not row.enabled or int(row.estoque) == 0 or world.tick - int(row.last_tick) < int(row.intervalo_ticks): return
	# Failed attempts also start a new interval; stock is spent only on placement.
	row.last_tick = world.tick
	var count := 0
	for food in world.foods:
		if row.pos.distance_squared_to(food.pos) <= float(row.raio) * float(row.raio):
			count += 1
			if count >= int(row.capacidade_local): return
	if world.place_food(row.pos, row.tipo_alimento) != -1:
		row.estoque = int(row.estoque) - 1
