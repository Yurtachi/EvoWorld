class_name SimWorld
extends RefCounted
## Fixed-step baseline ecology. Decisions use sensors; collision uses physical geometry.

const Rng = preload("res://scripts/core/sim_rng.gd")
const Ids = preload("res://scripts/core/sim_ids.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Creature = preload("res://scripts/creature/sim_creature.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Grid = preload("res://scripts/core/spatial_grid.gd")
const Inheritance = preload("res://scripts/evolution/inheritance.gd")
const Genealogy = preload("res://scripts/evolution/genealogy.gd")
const Text = preload("res://scripts/core/textos.gd")
const Signals = preload("res://scripts/communication/signal_channel.gd")
const Commands = preload("res://scripts/communication/comandos.gd")
const FoodCatalog = preload("res://scripts/environment/food_catalog.gd")
const Water = preload("res://scripts/environment/water_rules.gd")
const Personality = preload("res://scripts/behavior/personality.gd")
const Ensino = preload("res://scripts/interaction/ensino.gd")
const QBrain = preload("res://scripts/behavior/q_brain.gd")
const Social = preload("res://scripts/social/social_dynamics.gd")
const Mind = preload("res://scripts/mind/creature_mind.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const SAVE_VERSION := 13 # Cooperative physical terminal and individual policy.
const Terminal = preload("res://scripts/terminal/terminal.gd")
const TerminalAdapter = preload("res://scripts/terminal/terminal_mundo_real.gd")
const TerminalState = preload("res://scripts/terminal/terminal_estado.gd")
const TerminalLearning = preload("res://scripts/mind/terminal_learning.gd")
const TERMINAL_LIMIT := 16
const TERMINAL_COST := 0.004
var terminals: Array = []
var terminal_markers: Array = []
const Books = preload("res://scripts/library/book_catalog.gd")
const ObjectCatalog = preload("res://scripts/environment/object_catalog.gd")
const NEW_WORLD_CREATURE_COUNT := 12
const EVOLUTION_DEFAULTS := {
	"reproduction_enabled": true, "max_population": 150, "min_reproduction_age": 300,
	"reproduction_cooldown": 300, "max_age": 12000, "mutation_rate": 0.3, "mutation_scale": 0.025
}
const REPRODUCTION_ENERGY_FRACTION := 0.9
const OFFSPRING_ENERGY_FRACTION := 0.4
const TICK_DT := 0.1
const EVENT_LIMIT := 256
const FOOD_ENERGY := FoodCatalog.PARAMETERS.legacy.nutrition

var tick: int = 0
var seed: int = 1
var size := Vector2(1200.0, 760.0)
var creatures: Dictionary = {}
var foods: Array = []
var objects: Array = []
var library: Dictionary = {"version": Books.VERSION, "books": []}
var pending_questions: Array:
	get:
		var out: Array = []
		for c in creatures.values():
			if c.mind != null and not c.mind.knowledge.is_empty():
				out.append_array(c.mind.knowledge.questions.duplicate(true))
		return out
var boards: Array = []
var gallery: Array = []
var galeria: Array:
	get:
		return Data.restore_precision(gallery)
var quadros: Array:
	get:
		return Data.restore_precision(boards)
var obstacles: Array = []
var waters: Array = []
var water_enabled := false
var personality_enabled := false
var mind_all := false
var mind_enabled_ids: Array = []
var events: Array = []
var pet_id: int = -1
var food_regrow: bool = true
var food_capacity: int = 100
var food_regrow_interval: int = 10
var food_regrow_batch: int = 2
var reproduction_enabled := true
var max_population := 150
var min_reproduction_age := 300
var reproduction_cooldown := 300
var max_age := 12000
var mutation_rate := 0.3
var mutation_scale := 0.025
var genealogy := Genealogy.new()
var comandos := Commands.new()
var signal_enabled := false
var signal_count := 4
var signal_range := 180.0
var signal_noise := 0.05
var signal_cost := 0.3
var signal_ttl := 10
var signal_log: Array = []
var rng: Rng
var ids := Ids.new()
var _food_grid := Grid.new()
var _water_grid := Grid.new()
var _water_by_id: Dictionary = {}
var _max_water_radius := 0.0
var _creature_grid := Grid.new()
var _obstacle_grid := Grid.new()
var _food_by_id: Dictionary = {}
var _max_obstacle_radius := 0.0
var _in_step := false


## Product entry point. The low-level constructor retains historical experiment defaults.
static func new_world(world_seed: int = 1, config: Dictionary = {}) -> SimWorld:
	var initial := config.duplicate(true)
	initial.merge({"creature_count": NEW_WORLD_CREATURE_COUNT, "water_enabled": true, "water_count": 3, "personality_enabled": true}, false)
	initial["_mind_pet_default"] = not config.has("mind_enabled_ids") and not config.get("mind_all", false)
	return load("res://scripts/world/sim_world.gd").new(world_seed, initial)

func _init(world_seed: int = 1, config: Dictionary = {}) -> void:
	seed = world_seed
	rng = Rng.new(seed)
	var signal_config: Dictionary = Signals.DEFAULTS.duplicate()
	for key in Signals.DEFAULTS:
		signal_config[key] = config.get(key, Signals.DEFAULTS[key])
	if not Signals.valid_config(signal_config):
		signal_config = Signals.DEFAULTS.duplicate()
	for key in Signals.DEFAULTS:
		set(key, signal_config[key])
	for key in ["signal_range", "signal_noise", "signal_cost"]:
		set(key, snappedf(float(get(key)), 0.000001))
	if config.get("size") is Vector2:
		size = config["size"]
		if not size.is_finite():
			size = Vector2(1200.0, 760.0)
		size = size.clamp(Vector2(64.0, 64.0), Vector2(100000.0, 100000.0))
	food_regrow = bool(config.get("food_regrow", true))
	food_capacity = clampi(int(config.get("food_capacity", 100)), 0, 10000)
	food_regrow_interval = maxi(1, int(config.get("food_regrow_interval", 10)))
	food_regrow_batch = clampi(int(config.get("food_regrow_batch", 2)), 0, 1000)
	for key in EVOLUTION_DEFAULTS:
		set(key, config.get(key, EVOLUTION_DEFAULTS[key]))
	max_population = clampi(max_population, 1, 10000)
	min_reproduction_age = clampi(min_reproduction_age, 1, 10000000)
	reproduction_cooldown = clampi(reproduction_cooldown, 1, 10000000)
	max_age = clampi(max_age, 1, 10000000)
	mutation_rate = snappedf(clampf(mutation_rate, 0.0, 1.0), 0.000001)
	mutation_scale = snappedf(clampf(mutation_scale, 0.0, 0.1), 0.000001)
	water_enabled = config.get("water_enabled", false) == true
	personality_enabled = config.get("personality_enabled", false) == true
	mind_all = config.get("mind_all", false) == true
	for index in range(clampi(int(config.get("water_count", 0)), 0, Water.MAX_REGIONS)):
		var radius := minf(rng.between(18.0, 48.0), minf(size.x, size.y) * 0.2)
		place_water(_random_position(radius), radius)
	for index in range(clampi(int(config.get("obstacle_count", 8)), 0, 1000)):
		place_obstacle(_random_position(30.0), rng.between(16.0, 30.0))
	for index in range(clampi(int(config.get("food_count", 80)), 0, food_capacity)):
		var food_type: String = ["fruta", "semente", "folha", "cogumelo"][index % 4] if water_enabled else "legacy"
		place_food(_free_position(3.0), food_type)
	for index in range(clampi(int(config.get("creature_count", 16)), 0, max_population)):
		var creature_id := spawn_creature(_free_position(16.0))
		if pet_id == -1:
			pet_id = creature_id

	if config.get("_mind_pet_default", false) and pet_id != -1:
		enable_mind(pet_id)
	if config.get("mind_enabled_ids", []) is Array:
		for creature_id in config.get("mind_enabled_ids", []):
			if Data.integer(creature_id, 1):
				enable_mind(int(creature_id))

## Explicit opt-in never consumes the biological world RNG or changes physiology.
func enable_mind(creature_id: int) -> bool:
	if not creatures.has(creature_id) or not creatures[creature_id].alive:
		return false
	if creatures[creature_id].mind == null:
		creatures[creature_id].mind = Mind.new(seed ^ (creature_id * 104729))
		creatures[creature_id].personality_water_enabled = water_enabled
	if creature_id not in mind_enabled_ids:
		mind_enabled_ids.append(creature_id)
		mind_enabled_ids.sort()
	return true

func disable_mind(creature_id: int) -> bool:
	if not creatures.has(creature_id):
		return false
	creatures[creature_id].mind = null
	mind_enabled_ids.erase(creature_id)
	return true

func spawn_creature(pos: Vector2, creature_name: String = "", genome = null) -> int:
	if not pos.is_finite() or creatures.size() >= max_population or genealogy.records.size() >= Genealogy.MAX_RECORDS:
		return -1
	var genes: Genes
	if genome == null:
		genes = Genes.new()
		for gene in Genes.BOUNDS:
			genes.set(gene, snappedf(rng.between(Genes.BOUNDS[gene][0], Genes.BOUNDS[gene][1]), 0.000001))
	else:
		if not genome is Genes:
			return -1
		genes = Genes.from_dict(genome.to_dict())
		if genes == null:
			return -1
	if personality_enabled and genes.temperament.is_empty():
		for disposition in Genes.TEMPERAMENT_KEYS:
			genes.temperament[disposition] = snappedf(rng.between(0.0, 1.0), 0.000001)
	genes.bound_genes()
	# Introductions are founders; reproductive ancestry only comes from reproduce().
	genes.parents = []
	genes.generation = 0
	return _spawn(pos, creature_name, genes)

func _spawn(pos: Vector2, creature_name: String, genes: Genes, initial_energy: float = -1.0, mutations: Array = []) -> int:
	var location := _inside(pos, genes.size)
	if not _clear(location, genes.size):
		location = _free_position(genes.size)
	if not _clear(location, genes.size):
		return -1
	genes.id = ids.take()
	var creature := Creature.new()
	creature.id = ids.take()
	creature.genome = genes
	if personality_enabled:
		creature.personality = Personality.new()
		creature.personality_water_enabled = water_enabled
	creature.name = creature_name.left(64) if not creature_name.is_empty() else Text.texto("creature_default", [creature.id])
	creature.pos = location
	creature.heading = snappedf(rng.between(-PI, PI), 0.000001)
	creature.max_energy = snappedf(80.0 + genes.size * 2.0, 0.000001)
	creature.energy = snappedf(creature.max_energy * 0.8, 0.000001) if initial_energy < 0.0 else initial_energy
	creatures[creature.id] = creature
	if mind_all:
		enable_mind(creature.id)
	genealogy.register(creature, tick, mutations)
	if _in_step:
		_creature_grid.insert(creature.id, creature.pos)
	_record({"type": "spawn", "creature_id": creature.id, "name": creature.name})
	return creature.id

## Returns the newborn ID, or -1 without charging energy when ineligible.
func reproduce(creature_id: int) -> int:
	if not reproduction_enabled or not creatures.has(creature_id) or creatures.size() >= max_population or genealogy.records.size() >= Genealogy.MAX_RECORDS:
		return -1
	var parent: Creature = creatures[creature_id]
	if not parent.alive or parent.age < min_reproduction_age or parent.age >= max_age or parent.reproduction_cooldown > 0 or parent.energy < parent.max_energy * REPRODUCTION_ENERGY_FRACTION:
		return -1
	var inherited: Dictionary = Inheritance.inherit(parent.genome, parent.id, rng, mutation_rate, mutation_scale)
	var genes: Genes = inherited["genome"]
	var child_capacity := snappedf(80.0 + genes.size * 2.0, 0.000001)
	var transferred := snappedf(minf(parent.max_energy * OFFSPRING_ENERGY_FRACTION, child_capacity), 0.000001)
	var position := parent.pos + Vector2.from_angle(rng.between(-PI, PI)) * (parent.genome.size + genes.size + 2.0)
	var child_id := _spawn(position, "", genes, transferred, inherited["mutations"])
	if child_id == -1:
		return -1
	parent.energy = snappedf(parent.energy - transferred, 0.000001)
	parent.reproduction_cooldown = reproduction_cooldown
	_record({"type": "birth", "creature_id": child_id, "parent_id": parent.id, "generation": genes.generation, "energy": transferred})
	creatures[child_id].remember(events.back())
	for mutation in inherited["mutations"]:
		_record({"type": "mutation", "creature_id": child_id, "parent_id": parent.id, "gene": mutation["gene"], "delta": mutation["delta"]})
	return child_id

## Copies protect permanent ancestry against UI/analysis mutations.
func lineage(creature_id: int) -> Array:
	return genealogy.lineage(creature_id)

func descendants(creature_id: int) -> Array:
	return genealogy.descendants(creature_id)

## Population variance of living organisms (zero for empty/singleton populations).
func genetic_diversity() -> Dictionary:
	var result: Dictionary = {}
	for gene in Genes.BOUNDS:
		var mean := 0.0
		var squared := 0.0
		var count := 0
		for creature in creatures.values():
			if not creature.alive:
				continue
			count += 1
			var delta: float = float(creature.genome.get(gene)) - mean
			mean += delta / count
			squared += delta * (float(creature.genome.get(gene)) - mean)
		result[gene] = maxf(0.0, squared / maxi(1, count))
	return result

func place_object(pos: Vector2, tipo: String = "capsula_neutra") -> int:
	if not ObjectCatalog.TYPES.has(tipo) or not pos.is_finite() or objects.size() >= ObjectCatalog.LIMIT:
		return -1
	var location := _inside(pos, 5.0)
	if not _clear(location, 5.0): return -1
	var object_id: int = ids.take()
	objects.append({"id": object_id, "pos": location, "tipo": tipo})
	return object_id

func interact_object(creature: Creature, object_id: int) -> bool:
	if not creature.alive or creature.mind == null: return false
	for row in objects:
		if int(row.id) != object_id: continue
		if creature.pos.distance_to(row.pos) > Obs.reach(creature) or _occluded(creature.pos, row.pos): return false
		var s: Dictionary = Mind.ObjectMemory.state(creature.mind)
		var e: Dictionary = s.entries.get(str(object_id), {})
		if tick < int(s.cooldowns.get(str(object_id), 0)) or tick < int(e.get("retry_tick", 0)): return false
		var params: Dictionary = ObjectCatalog.TYPES[row.tipo]
		var energy_before := creature.energy
		var water_before := creature.hydration
		creature.energy = snappedf(clampf(creature.energy + float(params.energy) - float(params.toxicity) * 4.0, 0.0, creature.max_energy), 0.000001)
		creature.hydration = snappedf(clampf(creature.hydration + float(params.hydration), 0.0, 100.0), 0.000001)
		var evidence := {"energy": snappedf(creature.energy - energy_before, 0.000001), "hydration": snappedf(creature.hydration - water_before, 0.000001), "toxicity": params.toxicity, "surprise": params.surprise}
		Mind.ObjectMemory.interacted(creature.mind, ObjectCatalog.appearance(row), tick, evidence)
		Mind.Knowledge.outcome(creature.mind, str(params.category), evidence, tick)
		if creature.mind.affect_enabled:
			var state := "receio" if float(params.toxicity) > 0.0 else "entusiasmo"
			creature.mind.affect.change(tick, state, float(params.surprise) * 0.4, "object_contact", creature.mind.traits(creature))
		creature.last_action = "investigate_object"
		return true
	return draw_on_board(creature, object_id)

func place_board(pos: Vector2) -> int:
	if not pos.is_finite() or boards.size() >= Atelier.BOARD_LIMIT:
		return -1
	var location := _inside(pos, Atelier.BOARD_RADIUS)
	if not _clear(location, Atelier.BOARD_RADIUS):
		return -1
	var board_id: int = ids.take()
	boards.append(Atelier.make_board(board_id, location, tick))
	return board_id

func demonstrar_forma(board_ref: Variant, forma: String, params: Dictionary = {}) -> bool:
	var target_id := -1
	if board_ref is Dictionary and Data.integer(board_ref.get("id"), 1):
		target_id = int(board_ref.id)
	elif Data.integer(board_ref, 1):
		target_id = int(board_ref)
	if target_id < 1:
		return false
	for board in boards:
		if int(board.id) != target_id:
			continue
		if not Atelier.demonstrate_shape(board, forma, tick, params):
			return false
		if board_ref is Dictionary and board_ref != board:
			board_ref.merge(board, true)
		for creature in creatures.values():
			if creature.mind != null:
				observe_board(creature, board)
			if creature.mind != null and not creature.mind.objects.is_empty():
				var s: Dictionary = Mind.ObjectMemory.state(creature.mind)
				var key := str(target_id)
				s.cooldowns.erase(key)
				if s.entries.has(key):
					s.entries[key].retry_tick = 0
		return true
	return false

func observe_board(creature: Creature, board: Dictionary) -> bool:
	if not creature.alive or board.reference_strokes.is_empty() or not _visible(creature, board.pos) or _occluded(creature.pos, board.pos):
		return false
	if creature.atelier == null:
		creature.atelier = Atelier.new()
	var mem: Dictionary = creature.atelier.shape_memory.get(str(board.reference_shape), {})
	if int(mem.get("last_tick", -1)) == tick:
		return true
	var obs_rng = creature.mind.rng if creature.mind != null else rng
	return creature.atelier.observe_demonstration(str(board.reference_shape), board.reference_strokes, obs_rng, tick)

func draw_on_board(creature: Creature, board_id: int) -> bool:
	if not creature.alive:
		return false
	for board in boards:
		if int(board.id) != board_id:
			continue
		if creature.pos.distance_to(board.pos) > Obs.reach(creature) or _occluded(creature.pos, board.pos):
			return false
		if creature.atelier == null:
			creature.atelier = Atelier.new()
		var a = creature.atelier
		var starting: bool = a.active.is_empty() or a.active.get("status") != "active" or int(a.active.get("board_id", 0)) != board_id or a.active.get("target_shape") != board.reference_shape
		if starting and not board.reference_strokes.is_empty():
			observe_board(creature, board)
		var res: Dictionary = creature.atelier.step_drawing(self, creature, board)
		if not bool(res.get("reproduced", false)):
			return false
		creature.last_action = "draw_stroke"
		if creature.mind != null:
			var evidence := {"energy": snappedf(-Atelier.DRAW_ENERGY_COST, 0.000001), "hydration": 0.0, "toxicity": 0.0, "surprise": 0.25}
			Mind.ObjectMemory.interacted(creature.mind, Atelier.board_appearance(board), tick, evidence)
			var s: Dictionary = Mind.ObjectMemory.state(creature.mind)
			var key := str(board_id)
			if bool(res.get("completed", false)):
				s.cooldowns[key] = tick + 36
				if s.entries.has(key):
					s.entries[key].retry_tick = tick + 36
				if creature.mind.affect_enabled:
					creature.mind.affect.change(tick, "satisfacao", 0.12, "drawing_completed", creature.mind.traits(creature))
					creature.mind.affect.change(tick, "entusiasmo", 0.08, "drawing_completed", creature.mind.traits(creature))
			else:
				s.cooldowns.erase(key)
				if s.entries.has(key):
					s.entries[key].retry_tick = 0
		return true
	return false

func place_food(pos: Vector2, tipo: String = "legacy") -> int:
	if not FoodCatalog.valid_type(tipo) or not pos.is_finite() or foods.size() >= food_capacity:
		return -1
	var location := _inside(pos, 3.0)
	if not _clear(location, 3.0):
		return -1
	var food_id := ids.take()
	foods.append({"id": food_id, "pos": location, "energy": FoodCatalog.PARAMETERS[tipo]["nutrition"], "food_type": tipo})
	return food_id

## Place an offer just beyond ingestion reach; only later physical ingestion has effects.
func oferecer_alimento(creature_id: int, tipo: String = "fruta") -> int:
	if not FoodCatalog.valid_type(tipo) or not creatures.has(creature_id) or not creatures[creature_id].alive:
		return -1
	var creature: Creature = creatures[creature_id]
	var distance := Obs.reach(creature) + creature.genome.speed * TICK_DT + 2.0
	for index in range(16):
		var pos := creature.pos + Vector2.from_angle(creature.heading + index * TAU / 16.0) * distance
		if pos != _inside(pos, 3.0) or _occluded(creature.pos, pos, 3.0):
			continue
		var food_id := place_food(pos, tipo)
		if food_id != -1:
			return food_id
	return -1

## Right/bottom expansion changes only bounds. No RNG, IDs, relocation or generation.
func expand(side: String, amount: Variant) -> bool:
	if not Data.number(amount) or float(amount) <= 0.0 or side not in ["right", "bottom", "direita", "inferior"]:
		return false
	var axis := 0 if side in ["right", "direita"] else 1
	var extent := size[axis] + float(amount)
	if not is_finite(extent) or extent > 100000.0:
		return false
	var expanded := size
	expanded[axis] = extent
	if expanded[axis] <= size[axis]:
		return false
	size = expanded
	return true

func place_water(pos: Vector2, radius: float = 30.0) -> int:
	if not pos.is_finite() or not is_finite(radius) or radius < 1.0 or radius > Water.MAX_RADIUS or waters.size() >= Water.MAX_REGIONS:
		return -1
	if radius * 2.0 > minf(size.x, size.y) or pos != _inside(pos, radius):
		return -1
	var water_id := ids.take()
	waters.append({"id": water_id, "pos": pos, "radius": snappedf(radius, 0.000001)})
	return water_id

func place_obstacle(pos: Vector2, radius: float) -> void:
	if not pos.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	var actual_radius := snappedf(clampf(radius, 1.0, minf(size.x, size.y) * 0.45), 0.000001)
	var location := _inside(pos, actual_radius)
	for creature in creatures.values():
		if creature.pos.distance_to(location) < actual_radius + creature.genome.size:
			return
	for food in foods:
		if food["pos"].distance_to(location) < actual_radius + 3.0:
			return
	for device in terminals:
		if device.pos.distance_to(location) < actual_radius + 5.0: return
	for marker in terminal_markers:
		if Data.unpack_vector(marker.pos).distance_to(location) < actual_radius + 1.0: return
	obstacles.append({"pos": location, "radius": actual_radius})

func step() -> void:
	_rebuild_spatial()
	_in_step = true
	tick += 1
	# Stable ordering also preserves competition outcomes after save/load.
	var creature_ids := creatures.keys()
	creature_ids.sort()
	for creature_id in creature_ids:
		var creature: Creature = creatures[creature_id]
		_update_creature(creature)
		_creature_grid.insert(creature_id, creature.pos)
		if not creature.alive:
			_creature_grid.remove(creature_id)
			creatures.erase(creature_id)
			mind_enabled_ids.erase(creature_id)
			if pet_id == creature_id:
				pet_id = -1
		else:
			reproduce(creature_id)
	_in_step = false
	if food_regrow and tick % food_regrow_interval == 0:
		for index in range(mini(food_regrow_batch, food_capacity - foods.size())):
			var food_type: String = ["fruta", "semente", "folha", "cogumelo"][(tick / food_regrow_interval + index) % 4] if water_enabled else "legacy"
			place_food(_free_position(3.0), food_type)

func _rebuild_spatial() -> void:
	_food_grid = Grid.new()
	_water_grid = Grid.new()
	_water_by_id.clear()
	_max_water_radius = 0.0
	for water in waters:
		_water_grid.insert(int(water["id"]), water["pos"])
		_water_by_id[int(water["id"])] = water
		_max_water_radius = maxf(_max_water_radius, water["radius"])
	_creature_grid = Grid.new()
	_obstacle_grid = Grid.new()
	_food_by_id.clear()
	_max_obstacle_radius = 0.0
	for food in foods:
		_food_grid.insert(int(food["id"]), food["pos"])
		_food_by_id[int(food["id"])] = food
	for other in creatures.values():
		_creature_grid.insert(other.id, other.pos)
	for index in range(obstacles.size()):
		_obstacle_grid.insert(index, obstacles[index]["pos"])
		_max_obstacle_radius = maxf(_max_obstacle_radius, obstacles[index]["radius"])

## External callers may mutate public collections; rebuild outside a simulation step.
## Built-in policies don't consume neighboring creatures, so skip that query for them.
func sense(creature: Creature, include_creatures: bool = true) -> Dictionary:
	if not _in_step:
		_rebuild_spatial()
	var result := {"foods": [], "creatures": [], "obstacles": [], "hunger": creature.hunger}
	if not terminals.is_empty():
		result["terminals"] = []
		var active_device: int = int(creature.mind.terminal.get("active", {}).get("terminal_id", 0)) if creature.mind != null and not creature.mind.terminal.is_empty() else 0
		for row in terminals:
			var remembered: bool = int(row.id) == active_device and creature.pos.distance_to(row.pos) <= creature.genome.vision_range
			if (_visible(creature, row.pos) or remembered) and not _occluded(creature.pos, row.pos): result.terminals.append(row.duplicate(true))
	if not objects.is_empty():
		result["objects"] = []
		for row in objects:
			if _visible(creature, row.pos) and not _occluded(creature.pos, row.pos):
				result.objects.append(ObjectCatalog.appearance(row))
	if not library.books.is_empty():
		result["books"] = []
		for row in library.books:
			if _visible(creature, row.pos) and not _occluded(creature.pos, row.pos): result.books.append(row.duplicate(true))
	if not boards.is_empty():
		result["boards"] = []
		var remembered: Dictionary = creature.mind.objects.get("entries", {}) if creature.mind != null and creature.mind.memory_enabled else {}
		for row in boards:
			var in_range := creature.pos.distance_to(row.pos) <= creature.genome.vision_range
			if in_range and not _occluded(creature.pos, row.pos) and (_visible(creature, row.pos) or remembered.has(str(row.id))):
				result.boards.append(Atelier.board_appearance(row))
	result["signal"] = creature.last_signal.duplicate(true) if signal_enabled and not creature.last_signal.is_empty() and tick - int(creature.last_signal["tick"]) <= signal_ttl else {}
	result["action_count"] = Actions.SIGNAL_FIRST + signal_count if signal_enabled else Actions.SIGNAL_FIRST
	if water_enabled:
		result.merge({"waters": [], "hydration": creature.hydration, "thirst": creature.thirst, "water_enabled": true})
		var allowed: Array = range(int(result["action_count"]))
		allowed.append(Actions.DRINK)
		result["allowed_actions"] = allowed
		result["action_count"] = Actions.COUNT
		var water_extent := Vector2.ONE * (creature.genome.vision_range + _max_water_radius)
		for water_id in _water_grid.query(creature.pos - water_extent, creature.pos + water_extent):
			var water: Dictionary = _water_by_id[water_id]
			var shore := Water.shore(water, creature.pos)
			if _visible(creature, shore) and not _occluded(creature.pos, shore):
				result["waters"].append({"id": water_id, "pos": shore, "center": water["pos"], "radius": water["radius"]})
	var extent := Vector2.ONE * creature.genome.vision_range
	var low := creature.pos - extent
	var high := creature.pos + extent
	for food_id in _food_grid.query(low, high):
		var food: Dictionary = _food_by_id[food_id]
		if _visible(creature, food["pos"]) and not _occluded(creature.pos, food["pos"]):
			result["foods"].append(food.duplicate())
	if include_creatures:
		for other_id in _creature_grid.query(low, high):
			var other: Creature = creatures[other_id]
			if other.id != creature.id and _visible(creature, other.pos) and not _occluded(creature.pos, other.pos):
				result["creatures"].append({"id": other.id, "pos": other.pos})
	for index in _obstacle_grid.query(low, high):
		var obstacle: Dictionary = obstacles[index]
		if _visible(creature, obstacle["pos"]):
			result["obstacles"].append(obstacle.duplicate())
	return result

func _update_creature(creature: Creature) -> void:
	if not creature.alive:
		_die(creature, "external")
		return
	creature.age += 1
	creature.reproduction_cooldown = maxi(0, creature.reproduction_cooldown - 1)
	if creature.age >= max_age:
		_die(creature, "age")
		return
	creature.energy = clampf(creature.energy, 0.0, creature.max_energy)
	creature.hydration = clampf(creature.hydration, 0.0, Water.CAPACITY)
	var before: Dictionary = Personality.context(creature) if personality_enabled else {}
	if personality_enabled:
		creature.personality.advance(tick, creature.temperament)
	var sensors := sense(creature, personality_enabled or creature.mind != null)
	if personality_enabled:
		creature.personality.perceive(sensors, tick)
	var closest: Dictionary = {}
	var closest_distance := INF
	var best_score := INF
	for food in sensors["foods"]:
		var distance: float = creature.pos.distance_to(food["pos"])
		var score: float = Obs.food_score(creature, food, distance)
		if score < best_score:
			best_score = score
			closest = food
			closest_distance = distance
	var moving := false
	var teaching_acted := false
	var order: Dictionary = comandos.acao_pendente(creature, self)
	var teaching_active: bool = creature.ensino != null and creature.ensino.running()
	var mental_goal: String = creature.mind.decide(creature, tick, sensors) if creature.mind != null else ""
	if creature.mind != null and mental_goal != "usar_terminal" and not creature.mind.terminal.is_empty() and not creature.mind.terminal.active.is_empty():
		_terminal_finish(creature, "interrompido")
	var survival := (personality_enabled or teaching_active or creature.mind != null) and (creature.hunger > Commands.FOME_SUSPENDE_ORDEM or (water_enabled and creature.thirst > Water.THIRST_THRESHOLD))
	var social: Dictionary = Social.decide(self, creature, sensors) if personality_enabled and not survival and creature.mind == null else {}
	var motive: String = creature.personality.motive(creature.temperament) if personality_enabled and not survival and creature.mind == null else ""
	if survival:
		_suspend_brain(creature)
		if water_enabled and creature.thirst > Water.THIRST_THRESHOLD and (creature.thirst >= creature.hunger or closest.is_empty()):
			moving = _seek_water(creature, sensors)
		else:
			moving = _personality_seek_food(creature, sensors, closest, closest_distance)
	elif order["ativo"] and not (water_enabled and creature.thirst > Water.THIRST_THRESHOLD):
		# Never assign the consequences of player actions to a pending Q transition.
		if creature.brain != null and creature.brain.has_method("suspend_transition"):
			creature.brain.suspend_transition()
		creature.last_action = Actions.name_of(int(order["acao"]))
		creature.last_reason = order["razao"]
		moving = _apply_action(creature, sensors, int(order["acao"]))
	elif creature.ensino != null and creature.ensino.running() and creature.hunger <= Commands.FOME_SUSPENDE_ORDEM and (not water_enabled or creature.thirst <= Water.THIRST_THRESHOLD):
		moving = _ensino_act(creature, sensors)
		teaching_acted = true
	elif creature.mind != null:
		_suspend_brain(creature)
		moving = _mind_action(creature, sensors, mental_goal, closest, closest_distance)
	elif not social.is_empty() and creature.personality.fatigue < 0.85:
		_suspend_brain(creature)
		moving = _social_action(creature, sensors, social)
	elif not motive.is_empty():
		_suspend_brain(creature)
		moving = _personality_action(creature, sensors, motive)
	elif creature.brain != null and creature.brain.get("teaching_only") != true:
		moving = _act_with_brain(creature, sensors)
	elif water_enabled and creature.thirst > Water.THIRST_THRESHOLD:
		moving = _seek_water(creature, sensors)
	elif not closest.is_empty() and closest_distance <= creature.genome.size + 5.0 and creature.hunger > 0.05:
		_eat(creature, int(closest["id"]))
	elif creature.hunger < 0.12 or (creature.age % 120 < 12 and closest.is_empty()):
		creature.last_action = "rest"
		creature.last_reason = "Satiated; conserving energy" if creature.hunger < 0.12 else "Brief rest; no food perceived"
	else:
		if not closest.is_empty():
			creature.heading = (closest["pos"] - creature.pos).angle()
			creature.last_action = "seek_food"
			creature.last_reason = "Food %d visible at %.1f units" % [closest["id"], closest_distance]
		else:
			if creature.age % 15 == 0:
				creature.heading += rng.between(-0.9, 0.9)
			creature.last_action = "explore"
			creature.last_reason = "No food within vision; exploring"
		moving = _move(creature, sensors["obstacles"])
	if personality_enabled:
		_personality_encounters(creature, sensors)
	Signals.record_reaction(self, creature)
	var started := {"energy": creature.energy, "hydration": creature.hydration}
	# Rest reduces the activity cost, never creates nutritional energy.
	var cost: float = creature.genome.metabolism * (0.52 + creature.genome.size * 0.022) * TICK_DT
	if personality_enabled and creature.last_action == "rest":
		cost *= 0.6
	if moving and creature.last_action != "use_terminal":
		cost += creature.genome.speed * creature.genome.size * 0.0005 * TICK_DT
	if creature.last_action == "draw_stroke":
		cost += Atelier.DRAW_ENERGY_COST
	if water_enabled:
		creature.hydration = snappedf(clampf(creature.hydration - Water.LOSS_PER_SECOND * creature.genome.metabolism * TICK_DT, 0.0, Water.CAPACITY), 0.000001)
		if creature.hydration <= 0.0:
			cost += Water.DEHYDRATION_ENERGY_PER_SECOND * TICK_DT
	creature.energy = snappedf(clampf(creature.energy - cost, 0.0, creature.max_energy), 0.000001)
	creature.heading = snappedf(wrapf(creature.heading, -PI, PI), 0.000001)
	if personality_enabled:
		creature.personality.finish_tick(creature, tick, moving, before, started)
	if creature.mind != null:
		creature.mind.observe(self, creature, sensors, moving)
	if creature.energy <= 0.0:
		_die(creature, "starvation")
	elif creature.ensino != null and creature.ensino.running():
		_ensino_finish_tick(creature, teaching_acted)

func _die(creature: Creature, reason: String) -> void:
	terminal_markers = terminal_markers.filter(func(m): return int(m.owner_id) != creature.id)
	if creature.ensino != null:
		creature.ensino.finish(tick, "death", creature.energy, creature.ensino.active.get("final_distance", 0.0))
	creature.alive = false
	creature.last_action = "dead"
	creature.last_reason = "Starvation: energy exhausted" if reason == "starvation" else "evolution." + reason
	if creature.brain != null:
		creature.brain.on_death(creature)
	genealogy.mark_dead(creature.id, tick, reason)
	_record({"type": "death", "creature_id": creature.id, "reason": reason})

## Pluggable-policy path: the brain chooses a discrete action from discretized limited
## observations; the world applies the same physics/costs as the heuristic. No reflexive
## obstacle avoidance here: blocked moves simply fail and the brain must learn to turn.
func _act_with_brain(creature: Creature, sensors: Dictionary) -> bool:
	var obs: Dictionary = Obs.features(creature, sensors, size)
	var action: int = creature.brain.decide(creature, obs, rng)
	creature.last_action = Actions.name_of(action)
	creature.last_reason = creature.brain.last_reason
	return _apply_action(creature, sensors, action)

func _apply_action(creature: Creature, sensors: Dictionary, action: int) -> bool:
	if action >= Actions.SIGNAL_FIRST and action < Actions.DRINK:
		creature.last_reason = "signal.emitted" if emitir_sinal(creature.id, action - Actions.SIGNAL_FIRST) else "signal.rejected"
		return false
	var obs: Dictionary = Obs.features(creature, sensors, size)
	match action:
		Actions.DRINK:
			if not water_enabled or not _drink(creature, int(obs["water_id"])):
				creature.last_reason = "ecology.drink_empty"
			return false
		Actions.EAT:
			if int(obs["food_id"]) != -1 and float(obs["food_distance"]) <= Obs.reach(creature):
				_eat(creature, int(obs["food_id"]))
			else:
				creature.last_reason = "brain.eat_empty"
			return false
		Actions.REST:
			return false
		Actions.TURN_LEFT:
			creature.heading -= Actions.TURN_STEP
		Actions.TURN_RIGHT:
			creature.heading += Actions.TURN_STEP
		Actions.FORWARD:
			pass
		_:
			return false
	var target := creature.pos + Vector2.from_angle(creature.heading) * creature.genome.speed * TICK_DT
	if target != _inside(target, creature.genome.size) or _occluded(creature.pos, target, creature.genome.size):
		creature.last_reason = "brain.blocked"
		if creature.mind != null:
			creature.mind.consequence(creature, tick, "blocked", 1.0)
		return false
	creature.pos = target
	return true

func emitir_sinal(creature_id: int, symbol: int) -> bool:
	return Signals.emit(self, creature_id, symbol)

func _eat(creature: Creature, food_id: int) -> void:
	if not creature.alive:
		return
	for index in range(foods.size()):
		var food: Dictionary = foods[index]
		if int(food["id"]) != food_id:
			continue
		if creature.pos.distance_to(food["pos"]) > Obs.reach(creature) or _occluded(creature.pos, food["pos"]):
			return
		var params: Dictionary = FoodCatalog.PARAMETERS[food.get("food_type", "legacy")]
		var episode_context: Dictionary = Personality.context(creature, food.get("food_type", "legacy")) if personality_enabled else {}
		var old_hydration := creature.hydration
		var before := creature.energy
		creature.energy = snappedf(clampf(minf(creature.max_energy, creature.energy + float(food["energy"])) - float(params["toxicity"]), 0.0, creature.max_energy), 0.000001)
		if water_enabled:
			creature.hydration = snappedf(clampf(creature.hydration + float(params["hydration"]), 0.0, Water.CAPACITY), 0.000001)
		var gained := creature.energy - before
		if personality_enabled:
			creature.personality.ingest(creature, tick, episode_context, food["food_type"], gained, creature.hydration - old_hydration, float(params["toxicity"]))
		if creature.mind != null:
			creature.mind.consequence(creature, tick, "food", gained)
			if float(params["toxicity"]) > 0.0:
				creature.mind.consequence(creature, tick, "toxic", float(params["toxicity"]))
		foods.remove_at(index)
		_food_grid.remove(food_id)
		_food_by_id.erase(food_id)
		creature.last_action = "eat"
		creature.last_reason = "ecology.food_toxic" if gained < 0.0 else "Ate visible food %d; gained %.1f energy" % [food_id, gained]
		# Zero benefit ingestion consumes the item but is never reported as a meal.
		if gained > 0.0:
			var event := {"type": "eat", "creature_id": creature.id, "food_id": food_id, "energy": snappedf(maxf(0.0, gained), 0.000001)}
			_record(event)
			creature.remember(events.back())
		return

func _seek_water(creature: Creature, sensors: Dictionary) -> bool:
	var nearest: Dictionary = {}
	var distance := INF
	for water in sensors.get("waters", []):
		var candidate: float = creature.pos.distance_to(water["pos"])
		if candidate < distance:
			nearest = water
			distance = candidate
	if not nearest.is_empty():
		if distance <= Obs.reach(creature):
			_drink(creature, int(nearest["id"]))
			return false
		creature.heading = (nearest["pos"] - creature.pos).angle()
		creature.last_action = "seek_water"
		creature.last_reason = "ecology.seek_water"
	else:
		if creature.age % 15 == 0:
			creature.heading += rng.between(-0.9, 0.9)
		creature.last_action = "explore"
		creature.last_reason = "ecology.no_water"
	return _move(creature, sensors["obstacles"])

## Sensors select the resource, but physiology always checks physical reach again.
func _drink(creature: Creature, water_id: int) -> bool:
	if not water_enabled or not creature.alive:
		return false
	for water in waters:
		if int(water["id"]) != water_id:
			continue
		var shore := Water.shore(water, creature.pos)
		if creature.pos.distance_to(shore) > Obs.reach(creature) or _occluded(creature.pos, shore):
			return false
		var gained := snappedf(minf(Water.DRINK_AMOUNT, Water.CAPACITY - creature.hydration), 0.000001)
		if gained <= 0.0:
			return false
		var episode_context: Dictionary = Personality.context(creature) if personality_enabled else {}
		creature.hydration = snappedf(creature.hydration + gained, 0.000001)
		if personality_enabled:
			creature.personality.event_valence = 0.5
			creature.personality.record(tick, episode_context, "drink", 0.0, gained, 0.0, "water", "drinking")
		if creature.mind != null:
			creature.mind.consequence(creature, tick, "water", gained)
		creature.last_action = "drink"
		creature.last_reason = "ecology.drink"
		_record({"type": "drink", "creature_id": creature.id, "water_id": water_id, "hydration": gained})
		creature.remember(events.back())
		return true
	return false

func _move(creature: Creature, visible_obstacles: Array) -> bool:
	var distance: float = creature.genome.speed * TICK_DT
	var direction := Vector2.from_angle(creature.heading)
	for obstacle in visible_obstacles:
		var ahead := creature.pos + direction * (distance + creature.genome.size + 8.0)
		if _segment_hits(creature.pos, ahead, obstacle["pos"], obstacle["radius"] + creature.genome.size):
			creature.heading += PI * 0.5
			creature.last_action = "avoid_obstacle"
			creature.last_reason = "Obstacle perceived ahead; turning"
			direction = Vector2.from_angle(creature.heading)
			break
	var target := creature.pos + direction * distance
	if target != _inside(target, creature.genome.size) or _occluded(creature.pos, target, creature.genome.size):
		creature.heading += rng.between(1.0, 2.2)
		creature.last_action = "avoid_obstacle"
		creature.last_reason = "Physical boundary contact; turning"
		if creature.mind != null:
			creature.mind.consequence(creature, tick, "blocked", 1.0)
		return false
	creature.pos = target
	return true

func _visible(creature: Creature, target: Vector2) -> bool:
	var offset := target - creature.pos
	if offset.length_squared() > creature.genome.vision_range * creature.genome.vision_range:
		return false
	return offset.is_zero_approx() or absf(wrapf(offset.angle() - creature.heading, -PI, PI)) <= creature.genome.vision_fov * 0.5

func _occluded(start: Vector2, finish: Vector2, margin: float = 0.0) -> bool:
	if _in_step:
		var extent := Vector2.ONE * (_max_obstacle_radius + margin)
		for index in _obstacle_grid.query(start.min(finish) - extent, start.max(finish) + extent):
			var obstacle: Dictionary = obstacles[index]
			if _segment_hits(start, finish, obstacle["pos"], obstacle["radius"] + margin):
				return true
	else:
		for obstacle in obstacles:
			if _segment_hits(start, finish, obstacle["pos"], obstacle["radius"] + margin):
				return true
	return false

func _segment_hits(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var delta := finish - start
	var fraction := 0.0 if delta.is_zero_approx() else clampf((center - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return (start + delta * fraction).distance_squared_to(center) < radius * radius

func _inside(pos: Vector2, margin: float) -> Vector2:
	return pos.clamp(Vector2.ONE * margin, size - Vector2.ONE * margin)

func _clear(pos: Vector2, radius: float) -> bool:
	return not _occluded(pos, pos, radius)

func _random_position(margin: float) -> Vector2:
	return Vector2(rng.between(margin, size.x - margin), rng.between(margin, size.y - margin))

func _free_position(radius: float) -> Vector2:
	var location := _random_position(radius)
	for attempt in range(64):
		if _clear(location, radius):
			return location
		location = _random_position(radius)
	return location

func _record(event: Dictionary) -> void:
	var entry := event.duplicate(true)
	entry["tick"] = tick
	events.append(entry)
	if events.size() > EVENT_LIMIT:
		events.pop_front()

func to_dict() -> Dictionary:
	var saved_creatures: Array = []
	var creature_ids := creatures.keys()
	creature_ids.sort()
	for creature_id in creature_ids:
		saved_creatures.append(creatures[creature_id].to_dict())
	var saved_foods: Array = []
	for food in foods:
		saved_foods.append({"id": food["id"], "pos": Data.pack_vector(food["pos"]), "energy": food["energy"], "food_type": food["food_type"]})
	var saved_obstacles: Array = []
	for obstacle in obstacles:
		saved_obstacles.append({"pos": Data.pack_vector(obstacle["pos"]), "radius": obstacle["radius"]})
	var saved_waters: Array = []
	var saved_objects: Array = []
	for row in objects:
		saved_objects.append({"id": row.id, "pos": Data.pack_vector(row.pos), "tipo": row.tipo})
	for water in waters:
		saved_waters.append({"id": water["id"], "pos": Data.pack_vector(water["pos"]), "radius": water["radius"]})
	var saved_config := {"food_regrow": food_regrow, "food_capacity": food_capacity,
		"food_regrow_interval": food_regrow_interval, "food_regrow_batch": food_regrow_batch, "water_enabled": water_enabled, "personality_enabled": personality_enabled}
	saved_config["mind_all"] = mind_all
	saved_config["mind_enabled_ids"] = mind_enabled_ids.duplicate()
	for key in EVOLUTION_DEFAULTS:
		saved_config[key] = get(key)
	for key in Signals.DEFAULTS:
		saved_config[key] = get(key)
	var out := {
		"save_version": SAVE_VERSION, "world_seed": str(seed), "tick": tick,
		"size": Data.pack_vector(size), "pet_id": pet_id, "next_id": ids.next_id,
		"rng_state": rng.to_dict(), "creatures": saved_creatures, "foods": saved_foods,
		"obstacles": saved_obstacles, "waters": saved_waters, "objects": saved_objects, "object_catalog_version": ObjectCatalog.VERSION, "events": Data.restore_precision(events),
		"config": saved_config, "genealogy": genealogy.to_array(),
		"signal_log": Data.restore_precision(signal_log), "commands": comandos.to_dict(self)
	}
	if not boards.is_empty() or not gallery.is_empty():
		var saved_boards: Array = []
		for b in boards:
			var b_copy: Dictionary = Data.restore_precision(b)
			b_copy["pos"] = Data.pack_vector(b.pos)
			saved_boards.append(b_copy)
		out["boards"] = saved_boards
		out["gallery"] = Data.restore_precision(gallery)
	if not library.books.is_empty():
		out["library"] = {"version": Books.VERSION, "books": []}
		for b in library.books: out.library.books.append({"id": b.id, "book_id": b.book_id, "pos": Data.pack_vector(b.pos)})
	if not terminals.is_empty():
		out["terminals"] = []
		for device in terminals:
			out.terminals.append({"id": device.id, "pos": Data.pack_vector(device.pos), "books": device.books.duplicate()})
	if not terminal_markers.is_empty(): out["terminal_markers"] = Data.restore_precision(terminal_markers)
	return out

static func _migrate_v12(data: Dictionary) -> Dictionary:
	if data.get("save_version") == SAVE_VERSION: return data.duplicate(true)
	if data.get("save_version") != 12 or data.has("terminals") or data.has("terminal_markers"): return {}
	if not data.get("creatures") is Array: return {}
	for c in data.creatures:
		if not c is Dictionary or (c.get("mind") is Dictionary and c.mind.has("terminal")): return {}
	var migrated := data.duplicate(true)
	migrated.save_version = SAVE_VERSION
	return migrated

func place_terminal(pos: Vector2) -> int:
	if not pos.is_finite() or terminals.size() >= TERMINAL_LIMIT: return -1
	var location := _inside(pos, 5.0)
	if not _clear(location, 5.0): return -1
	var device_id: int = ids.take()
	terminals.append({"id": device_id, "pos": location, "books": ["mapa", "livro_desenho", "livro_repeticao"]})
	return device_id

func _terminal_device(device_id: int) -> Dictionary:
	for device in terminals:
		if int(device.id) == device_id: return device
	return {}

func _terminal_ready(creature: Creature, device_id: int) -> bool:
	if creature == null or creatures.get(creature.id) != creature or not creature.alive or creature.mind == null: return false
	if creature.hunger > 0.55 or (water_enabled and creature.thirst > 0.55): return false
	var device := _terminal_device(device_id)
	if device.is_empty() or creature.pos.distance_to(device.pos) > Obs.reach(creature) or _occluded(creature.pos, device.pos): return false
	var s := TerminalLearning.state(creature.mind)
	return s.enabled and tick >= int(s.refusal_until)

func terminal_snapshot(creature: Variant) -> Dictionary:
	var actor = creatures.get(creature) if creature is int else creature
	if actor == null or actor.mind == null: return TerminalLearning.empty()
	return Data.restore_precision(actor.mind.terminal) if not actor.mind.terminal.is_empty() else TerminalLearning.empty()

func terminal_set_task(creature: Creature, kind: String, target: Vector2i) -> bool:
	var task := {"kind": kind, "target": [target.x, target.y]}
	if creature == null or creature.mind == null or not TerminalLearning.valid_task(task): return false
	var s := TerminalLearning.state(creature.mind)
	if not s.active.is_empty(): _terminal_finish(creature, "interrompido")
	s.task = task
	return true

func terminal_refuse(creature: Creature, duration: int = 180) -> bool:
	if creature == null or creature.mind == null or duration < 1 or duration > 10000: return false
	var s := TerminalLearning.state(creature.mind)
	if not s.active.is_empty(): _terminal_finish(creature, "interrompido")
	s.refusal_until = tick + duration
	return true

func terminal_observe(creature: Creature, device_id: int) -> Dictionary:
	if not _terminal_ready(creature, device_id): return {}
	var device := _terminal_device(device_id)
	var seen := sense(creature)
	var relative: Vector2 = creature.pos - device.pos
	# Only sensed objects, public physical boundaries and body state.
	return {"pos": [roundi(relative.x), roundi(relative.y)], "limits": [Data.pack_vector(-device.pos), Data.pack_vector(size - device.pos)],
		"foods": seen.foods, "obstacles": seen.obstacles, "books": seen.get("books", []), "manuals": device.books.duplicate(), "boards": seen.get("boards", []), "energy": creature.energy, "hydration": creature.hydration}

func terminal_mark(creature: Creature, device_id: int, target: Vector2i) -> bool:
	if not _terminal_ready(creature, device_id) or absi(target.x) > 64 or absi(target.y) > 64: return false
	var location: Vector2 = _terminal_device(device_id).pos + Vector2(target)
	if location != _inside(location, 1.0) or not _clear(location, 1.0): return false
	# One current marker per creature/device; bounded independently of history.
	for marker in terminal_markers:
		if int(marker.owner_id) == creature.id and int(marker.terminal_id) == device_id:
			marker.pos = Data.pack_vector(location)
			marker.tick = tick
			return true
	if terminal_markers.size() >= 48: terminal_markers.pop_front()
	terminal_markers.append({"owner_id": creature.id, "terminal_id": device_id, "pos": Data.pack_vector(location), "tick": tick})
	return true

func terminal_move(creature: Creature, device_id: int, direction: String, units: int) -> bool:
	if not _terminal_ready(creature, device_id) or units < 1 or units > 8: return false
	var directions := {"NORTE": Vector2.UP, "SUL": Vector2.DOWN, "LESTE": Vector2.RIGHT, "OESTE": Vector2.LEFT}
	if not directions.has(direction): return false
	var delta: Vector2 = directions[direction] * minf(float(units), creature.genome.speed * TICK_DT)
	var target := creature.pos + delta
	# Same swept collision and speed cap as ordinary locomotion; never a teleport.
	if target != _inside(target, creature.genome.size) or _occluded(creature.pos, target, creature.genome.size): return false
	creature.heading = delta.angle()
	creature.pos = target
	creature.energy = snappedf(maxf(0.0, creature.energy - creature.genome.speed * creature.genome.size * 0.0005 * TICK_DT), 0.000001)
	return true

func terminal_draw(creature: Creature, device_id: int, shape: String) -> bool:
	if not _terminal_ready(creature, device_id): return false
	var requested: String = {"LINHA": "linha", "CIRCULO": "circulo", "QUADRADO": "quadrado"}.get(shape, "")
	if requested.is_empty(): return false
	for board in boards:
		if creature.pos.distance_to(board.pos) <= Obs.reach(creature) and not _occluded(creature.pos, board.pos) and board.reference_shape == requested:
			var drawn := draw_on_board(creature, int(board.id))
			if drawn: creature.energy = snappedf(maxf(0.0, creature.energy - Atelier.DRAW_ENERGY_COST), 0.000001)
			return drawn
	return false

func terminal_read(creature: Creature, device_id: int, book: String) -> bool:
	if not _terminal_ready(creature, device_id) or book not in _terminal_device(device_id).books: return false
	# Authored physical manual attached to this device, one bounded page/action.
	return book in ["mapa", "livro_desenho", "livro_repeticao"]

func terminal_offer_manual(creature: Creature, device_id: int, book: String = "mapa") -> bool:
	if not _terminal_ready(creature, device_id) or not terminal_read(creature, device_id, book): return false
	if creature.mind.traits(creature).curiosity < 0.15 and creature.personality != null and creature.personality.boredom < 0.5: return false
	var s := TerminalLearning.state(creature.mind)
	if int(s.last_tick) == tick: return false
	s.last_tick = tick
	var known = TerminalState.from_dict(s.state)
	if book == "mapa":
		for command in TerminalState.HELP:
			if known.discover(command, "manual"): break
	elif book == "livro_desenho": known.discover("DESENHAR", "livro")
	else: known.discover("REPETIR", "livro")
	s.state = known.to_dict()
	creature.energy = snappedf(maxf(0.0, creature.energy - TERMINAL_COST), 0.000001)
	creature.last_action = "read_terminal_manual"
	return true

func terminal_start(creature: Creature, device_id: int, program: String) -> bool:
	if not _terminal_ready(creature, device_id): return false
	var s := TerminalLearning.state(creature.mind)
	if not s.active.is_empty(): return false
	var lines := TerminalLearning.instructions(program, s.state)
	if lines.is_empty():
		var known = TerminalState.from_dict(s.state)
		Terminal.new().execute(program, null, known, tick, 8)
		# The standalone module permits 256-character program keys; the global
		# checkpoint format permits 128. Keep opaque error history, but do not
		# retain an unexecutable long key that could invalidate the whole save.
		for remembered in known.tabela.keys():
			if remembered.length() > 128: known.tabela.erase(remembered)
		s.state = known.to_dict()
		return false
	s.active = {"program": program, "instructions": lines, "index": 0, "terminal_id": device_id, "started": tick, "origin": Data.pack_vector(creature.pos)}
	return true

func _terminal_achieved(creature: Creature, device_id: int) -> bool:
	var s := TerminalLearning.state(creature.mind)
	if s.task.kind == "desenhar":
		return creature.atelier != null and creature.atelier.artifacts.any(func(a): return int(a.created_tick) >= int(s.active.started) and a.target_shape == "linha")
	var location: Vector2 = _terminal_device(device_id).pos + Vector2(float(s.task.target[0]), float(s.task.target[1]))
	return creature.pos.distance_to(location) <= 1.5 and creature.pos.distance_to(Data.unpack_vector(s.active.origin)) > 0.01 and terminal_markers.any(func(m): return int(m.owner_id) == creature.id and int(m.terminal_id) == device_id and int(m.tick) >= int(s.active.started) and Data.unpack_vector(m.pos).distance_to(location) < 0.01)

func _terminal_finish(creature: Creature, error: String = "") -> void:
	var s := TerminalLearning.state(creature.mind)
	if s.active.is_empty(): return
	var success := error.is_empty() and _terminal_achieved(creature, int(s.active.terminal_id))
	TerminalLearning.feedback(s, s.active.program, success, error if not error.is_empty() else ("" if success else "objetivo"), tick, creature.mind.memory_enabled)
	s.active = {}
	s.cooldown = tick + 2

func terminal_step(creature: Creature, device_id: int) -> bool:
	if creature == null or creature.mind == null: return false
	var s := TerminalLearning.state(creature.mind)
	if int(s.last_tick) == tick: return false
	if not _terminal_ready(creature, device_id):
		_terminal_finish(creature, "interrompido")
		return false
	if s.active.is_empty() and (tick < int(s.cooldown) or not terminal_start(creature, device_id, TerminalLearning.choose(s))): return false
	if int(s.active.terminal_id) != device_id: return false
	if tick - int(s.active.started) >= 40:
		_terminal_finish(creature, "tempo")
		return false
	s.last_tick = tick
	var adapter := TerminalAdapter.new(self, creature, device_id)
	var known = TerminalState.from_dict(s.state)
	var result := Terminal.new().execute(s.active.instructions[int(s.active.index)], adapter, known, tick, 1)
	s.state = known.to_dict()
	creature.energy = snappedf(maxf(0.0, creature.energy - TERMINAL_COST), 0.000001)
	creature.last_action = "use_terminal"
	if not result.ok:
		_terminal_finish(creature, "recusado")
	else:
		s.active.index += 1
		if int(s.active.index) >= s.active.instructions.size() or _terminal_achieved(creature, device_id): _terminal_finish(creature)
	return adapter.moved

func _restore_terminals(data: Dictionary, used_ids: Dictionary) -> bool:
	for raw in data.get("terminals", []):
		if not raw is Dictionary or raw.size() != 3 or not Data.integer(raw.get("id"), 1) or int(raw.id) >= int(data.next_id) or used_ids.has(int(raw.id)) or not Data.vector(raw.get("pos")) or not raw.get("books") is Array or raw.books.size() > 3: return false
		var books_seen: Dictionary = {}
		for book in raw.books:
			if book not in ["mapa", "livro_desenho", "livro_repeticao"] or books_seen.has(book): return false
			books_seen[book] = true
		var pos := Data.unpack_vector(raw.pos)
		if pos != _inside(pos, 5.0) or not _clear(pos, 5.0): return false
		used_ids[int(raw.id)] = true
		terminals.append({"id": int(raw.id), "pos": pos, "books": raw.books.duplicate()})
	var marker_ids: Dictionary = {}
	for m in data.get("terminal_markers", []):
		if not m is Dictionary or m.size() != 4 or not Data.integer(m.get("owner_id"), 1) or not creatures.has(int(m.owner_id)) or not Data.integer(m.get("terminal_id"), 1) or _terminal_device(int(m.terminal_id)).is_empty() or not Data.vector(m.get("pos")) or not Data.integer(m.get("tick")) or int(m.tick) > tick: return false
		var k := str(int(m.owner_id)) + ":" + str(int(m.terminal_id))
		if marker_ids.has(k): return false
		marker_ids[k] = true
		var pos := Data.unpack_vector(m.pos)
		var delta: Vector2 = pos - _terminal_device(int(m.terminal_id)).pos
		# Reconstruct the actual float32 operation used by terminal_mark. Exact
		# integer subtraction fails at exponent boundaries for valid fractional bases.
		var offset := Vector2i(roundi(delta.x), roundi(delta.y))
		var expected: Vector2 = _terminal_device(int(m.terminal_id)).pos + Vector2(offset)
		if absi(offset.x) > 64 or absi(offset.y) > 64 or pos != expected or pos != _inside(pos, 1.0) or not _clear(pos, 1.0): return false
		terminal_markers.append(Data.restore_precision(m))
	for c in creatures.values():
		if c.mind == null or c.mind.terminal.is_empty(): continue
		if not TerminalLearning.valid(c.mind.terminal, tick): return false
		var a: Dictionary = c.mind.terminal.active
		if not a.is_empty():
			if _terminal_device(int(a.terminal_id)).is_empty() or Data.unpack_vector(a.origin) != _inside(Data.unpack_vector(a.origin), c.genome.size): return false
	return true

static func from_dict(data: Dictionary) -> SimWorld:
	# Reject invalid input, returning null rather than creating a partial world.
	# Migration must not duplicate unbounded structures or silently discard
	# hostile data in fields introduced by later versions.
	if not Data.json_data(data):
		return null
	if not Data.integer(data.get("save_version")) or int(data["save_version"]) not in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, SAVE_VERSION]:
		return null
	if int(data.save_version) < 13:
		if data.has("terminals") or data.has("terminal_markers"): return null
		if data.get("creatures") is Array:
			for c in data.creatures:
				if c is Dictionary and c.get("mind") is Dictionary and (c.mind.has("terminal") or c.mind.get("objetivo_atual") == "usar_terminal"): return null
	if int(data["save_version"]) == 1:
		data = _migrate_v1(data)
		if data.is_empty():
			return null
	if int(data["save_version"]) == 2:
		data = _migrate_v2(data)
		if data.is_empty():
			return null
	if int(data["save_version"]) == 3:
		data = _migrate_v3(data)
		if data.is_empty():
			return null
	if int(data["save_version"]) == 4:
		data = _migrate_v4(data)
		if data.is_empty():
			return null
	if int(data["save_version"]) == 5:
		data = _migrate_v5(data)
	if int(data["save_version"]) == 6:
		data = _migrate_v6(data)
	if int(data["save_version"]) == 7:
		data = _migrate_v7(data)
		if data.is_empty():
			return null
	if int(data["save_version"]) == 8:
		data = _migrate_v8(data)
		if data.is_empty(): return null
	if int(data["save_version"]) == 9:
		data = _migrate_v9(data)
		if data.is_empty(): return null
	if int(data["save_version"]) == 10:
		data = _migrate_v10(data)
		if data.is_empty(): return null
	if int(data["save_version"]) == 11:
		data = _migrate_v11(data)
		if data.is_empty(): return null
	if int(data["save_version"]) == 12:
		data = _migrate_v12(data)
		if data.is_empty(): return null
	if not data.get("terminals", []) is Array or data.get("terminals", []).size() > TERMINAL_LIMIT or not data.get("terminal_markers", []) is Array or data.get("terminal_markers", []).size() > 48: return null
	if not Data.integer(data.get("object_catalog_version"), 1) or int(data.object_catalog_version) != ObjectCatalog.VERSION or not data.get("objects") is Array or data.objects.size() > ObjectCatalog.LIMIT:
		return null
	if (data.has("boards") and not data.get("boards") is Array) or (data.has("gallery") and not data.get("gallery") is Array):
		return null
	var raw_boards: Array = data.get("boards", [])
	var raw_gallery: Array = data.get("gallery", [])
	if raw_boards.size() > Atelier.BOARD_LIMIT or raw_gallery.size() > Atelier.GALLERY_LIMIT:
		return null
	if not Data.integer_text(data.get("world_seed")):
		return null
	if not Data.integer(data.get("tick")) or not Data.integer(data.get("next_id"), 1) or not Data.integer(data.get("pet_id"), -1):
		return null
	if not Data.vector(data.get("size")):
		return null
	var saved_size := Data.unpack_vector(data["size"])
	if not saved_size.is_finite() or saved_size.x < 64.0 or saved_size.y < 64.0 or saved_size.x > 100000.0 or saved_size.y > 100000.0:
		return null
	if not data.get("config") is Dictionary or not data.get("rng_state") is Dictionary:
		return null
	var config: Dictionary = data["config"].duplicate()
	if not Signals.valid_config(config) or not Signals.valid_log(data.get("signal_log"), int(data["tick"]), int(data["next_id"]), int(config["signal_count"])):
		return null
	if not config.get("reproduction_enabled") is bool:
		return null
	for key in ["max_population", "min_reproduction_age", "reproduction_cooldown", "max_age"]:
		if not Data.integer(config.get(key), 1) or int(config[key]) > (10000 if key == "max_population" else 10000000):
			return null
	for key in ["mutation_rate", "mutation_scale"]:
		if not Data.number(config.get(key)) or float(config[key]) < 0.0 or float(config[key]) > (1.0 if key == "mutation_rate" else 0.1):
			return null
	if not config.get("mind_all") is bool or not config.get("mind_enabled_ids") is Array or config["mind_enabled_ids"].size() > 10000:
		return null
	var unique_minds: Dictionary = {}
	for creature_id in config["mind_enabled_ids"]:
		if not Data.integer(creature_id, 1) or unique_minds.has(int(creature_id)):
			return null
		unique_minds[int(creature_id)] = true
	if not config.get("personality_enabled") is bool:
		return null
	if not config.get("water_enabled") is bool:
		return null
	if not config.get("food_regrow") is bool:
		return null
	if not Data.integer(config.get("food_capacity")) or int(config["food_capacity"]) > 10000:
		return null
	if not Data.integer(config.get("food_regrow_interval"), 1) or not Data.integer(config.get("food_regrow_batch")) or int(config["food_regrow_batch"]) > 1000:
		return null
	if not Data.integer_text(data["rng_state"].get("state")):
		return null
	for field in ["creatures", "foods", "obstacles", "events", "waters"]:
		if not data.get(field) is Array:
			return null
	if data["creatures"].size() > int(config["max_population"]) or data["foods"].size() > int(config["food_capacity"]) or data["obstacles"].size() > 1000:
		return null
	if data["waters"].size() > Water.MAX_REGIONS:
		return null
	if data["events"].size() > EVENT_LIMIT or not Data.json_data(data["events"]):
		return null
	for event in data["events"]:
		if not Data.event(event, int(data["tick"]), int(data["next_id"])):
			return null
	config.merge({"size": saved_size, "creature_count": 0, "food_count": 0, "obstacle_count": 0, "water_count": 0}, true)
	var result = load("res://scripts/world/sim_world.gd").new(int(data["world_seed"]), config)
	result.tick = int(data["tick"])
	result.pet_id = int(data["pet_id"])
	var ancestry = Genealogy.from_array(data.get("genealogy"), result.tick, int(data["next_id"]))
	if ancestry == null:
		return null
	result.genealogy = ancestry
	var used_ids: Dictionary = {}
	for obstacle in data["obstacles"]:
		if not obstacle is Dictionary or not Data.vector(obstacle.get("pos")) or not Data.number(obstacle.get("radius")):
			return null
		var radius := snappedf(float(obstacle["radius"]), 0.000001)
		var pos := Data.unpack_vector(obstacle["pos"])
		if radius <= 0.0 or radius > minf(saved_size.x, saved_size.y) * 0.45 or pos != result._inside(pos, radius):
			return null
		result.obstacles.append({"pos": pos, "radius": radius})
	for entry in data["creatures"]:
		if not entry is Dictionary:
			return null
		if not entry.has("hydration"):
			return null
		var creature := Creature.from_dict(entry)
		if creature == null or not creature.alive or used_ids.has(creature.id) or used_ids.has(creature.genome.id) or creature.id == creature.genome.id or creature.genome.id < 1:
			return null
		if (creature.mind != null) != unique_minds.has(creature.id):
			return null
		if creature.mind != null:
			if Mind.from_dict(entry["mind"], result.tick) == null:
				return null
			creature.personality_water_enabled = result.water_enabled
		if creature.ensino != null:
			if Ensino.from_dict(entry["ensino"], result.tick) == null:
				return null
			if not creature.ensino.active.is_empty():
				var target := Data.unpack_vector(creature.ensino.active.target)
				if not Commands._alvo_valido(target, result):
					return null
		if creature.atelier != null:
			if Atelier.from_dict(entry["atelier"], result.tick, int(data["next_id"])) == null:
				return null
		if result.personality_enabled:
			if creature.personality == null or Personality.from_dict(entry.get("personality"), result.tick) == null:
				return null
			creature.personality_water_enabled = result.water_enabled
		elif creature.personality != null or not creature.genome.temperament.is_empty():
			return null
		if not Signals.valid_received(creature.last_signal, result.tick, int(data["next_id"]), result.signal_count):
			return null
		if creature.pos != result._inside(creature.pos, creature.genome.size) or not result._clear(creature.pos, creature.genome.size):
			return null
		for event in creature.memory:
			if not Data.event(event, result.tick, int(data["next_id"])):
				return null
		used_ids[creature.id] = true
		used_ids[creature.genome.id] = true
		result.creatures[creature.id] = creature
	if unique_minds.size() != result.creatures.values().filter(func(c): return c.mind != null).size():
		return null
	result.mind_enabled_ids = unique_minds.keys()
	result.mind_enabled_ids.sort()
	for ancestor_id in ancestry.records:
		var ancestor: Dictionary = ancestry.records[ancestor_id]
		var genome_id := int(ancestor["genome"]["id"])
		if result.creatures.has(ancestor_id):
			if int(ancestor["death_tick"]) != -1 or ancestor["genome"] != result.creatures[ancestor_id].genome.to_dict():
				return null
		else:
			if int(ancestor["death_tick"]) == -1 or used_ids.has(ancestor_id) or used_ids.has(genome_id):
				return null
			used_ids[ancestor_id] = true
			used_ids[genome_id] = true
	for creature_id in result.creatures:
		if not ancestry.records.has(creature_id):
			return null
		if result.personality_enabled:
			for key in result.creatures[creature_id].personality.bonds:
				if key != "player" and (int(key) == creature_id or not ancestry.records.has(int(key))):
					return null
		if result.creatures[creature_id].mind != null:
			for episode in result.creatures[creature_id].mind.experiences:
				if episode.kind == "contact" and (int(episode.source) == creature_id or not ancestry.records.has(int(episode.source))):
					return null
				if episode.kind != "contact" and int(episode.source) != 0:
					return null
		var heard: Dictionary = result.creatures[creature_id].last_signal
		if not heard.is_empty() and (int(heard["emitter"]) == creature_id or not ancestry.records.has(int(heard["emitter"]))):
			return null
	for row in data["signal_log"]:
		if not ancestry.records.has(int(row["emitter"])):
			return null
		for receiver_id in row["receivers"]:
			if not ancestry.records.has(int(receiver_id)):
				return null
	for water in data["waters"]:
		if not water is Dictionary or water.size() != 3 or not Data.integer(water.get("id"), 1) or used_ids.has(int(water.get("id", -1))) or not Data.vector(water.get("pos")) or not Data.number(water.get("radius")):
			return null
		var pos := Data.unpack_vector(water["pos"])
		var radius := float(water["radius"])
		if radius < 1.0 or radius > Water.MAX_RADIUS or radius * 2.0 > minf(saved_size.x, saved_size.y) or pos != result._inside(pos, radius):
			return null
		used_ids[int(water["id"])] = true
		result.waters.append({"id": int(water["id"]), "pos": pos, "radius": snappedf(radius, 0.000001)})
	for food in data["foods"]:
		if not food is Dictionary or not Data.integer(food.get("id"), 1) or used_ids.has(int(food.get("id", -1))) or not Data.vector(food.get("pos")) or not Data.number(food.get("energy")):
			return null
		if not FoodCatalog.valid_type(food.get("food_type")):
			return null
		if food["food_type"] != "legacy" and float(food["energy"]) != float(FoodCatalog.PARAMETERS[food["food_type"]]["nutrition"]):
			return null
		var pos := Data.unpack_vector(food["pos"])
		if float(food["energy"]) < 0.000001 or float(food["energy"]) > 10000.0 or pos != result._inside(pos, 3.0) or not result._clear(pos, 3.0):
			return null
		used_ids[int(food["id"])] = true
		result.foods.append({"id": int(food["id"]), "pos": pos, "energy": snappedf(float(food["energy"]), 0.000001), "food_type": food["food_type"]})
	for row in data.objects:
		if not row is Dictionary or row.size() != 3 or not Data.integer(row.get("id"), 1) or used_ids.has(int(row.get("id", -1))) or not Data.vector(row.get("pos")) or not ObjectCatalog.TYPES.has(row.get("tipo", "")): return null
		var pos := Data.unpack_vector(row.pos)
		if pos != result._inside(pos, 5.0) or not result._clear(pos, 5.0): return null
		used_ids[int(row.id)] = true
		result.objects.append({"id": int(row.id), "pos": pos, "tipo": row.tipo})
	if data.has("library"):
		var lib = data.library
		if not lib is Dictionary or lib.size() != 2 or lib.get("version") != Books.VERSION or not Data.integer(lib.get("version"), 1) or not lib.get("books") is Array or lib.books.size() > Books.LIMIT: return null
		for b in lib.books:
			if not b is Dictionary or b.size() != 3 or not Data.integer(b.get("id"), 1) or used_ids.has(int(b.id)) or not Books.BOOKS.has(b.get("book_id", "")) or not Data.vector(b.get("pos")): return null
			var pos := Data.unpack_vector(b.pos)
			if pos != result._inside(pos, 5.0) or not result._clear(pos, 5.0): return null
			used_ids[int(b.id)] = true
			result.library.books.append({"id": int(b.id), "book_id": b.book_id, "pos": pos})
	var board_ids: Dictionary = {}
	for board in raw_boards:
		if not Atelier.valid_board(board, result.tick, int(data["next_id"])) or used_ids.has(int(board.id)):
			return null
		var b_pos := Data.unpack_vector(board.pos)
		if b_pos != result._inside(b_pos, Atelier.BOARD_RADIUS) or not result._clear(b_pos, Atelier.BOARD_RADIUS):
			return null
		if int(board.owner_id) != 0 and not ancestry.records.has(int(board.owner_id)):
			return null
		used_ids[int(board.id)] = true
		board_ids[int(board.id)] = true
		var b_copy: Dictionary = Data.restore_precision(board)
		b_copy["pos"] = b_pos
		result.boards.append(b_copy)
	var artifact_registry: Dictionary = {}
	var artifact_collections: Array = []
	for board in result.boards:
		artifact_collections.append(board.artifacts)
		for art in board.artifacts:
			if int(art.board_id) != int(board.id) or used_ids.has(int(art.id)) or not ancestry.records.has(int(art.owner_id)):
				return null
	if not Atelier.unique_artifacts(raw_gallery): return null
	artifact_collections.append(raw_gallery)
	for art in raw_gallery:
		if not Atelier.valid_artifact(art, result.tick, int(data["next_id"])) or used_ids.has(int(art.id)) or not ancestry.records.has(int(art.owner_id)) or not board_ids.has(int(art.board_id)):
			return null
		result.gallery.append(Data.restore_precision(art))
	for creature in result.creatures.values():
		if creature.atelier != null:
			artifact_collections.append(creature.atelier.artifacts)
			for art in creature.atelier.artifacts:
				if used_ids.has(int(art.id)) or int(art.owner_id) != creature.id:
					return null
		if creature.mind != null and not creature.mind.knowledge.is_empty():
			var k: Dictionary = creature.mind.knowledge
			if not Mind.Knowledge.valid(k, result.tick): return null
			for q in k.questions:
				if int(q.creature_id) != creature.id or int(q.object_id) >= int(data.next_id): return null
				if not result.objects.any(func(o): return int(o.id) == int(q.object_id) and ObjectCatalog.TYPES[o.tipo].category == q.category): return null
			for context in k.asked:
				if int(context.split(":")[0]) >= int(data.next_id): return null
			if not k.reading.is_empty():
				if not result.library.books.any(func(b): return int(b.id) == int(k.reading.id) and b.book_id == k.reading.book_id): return null
		if creature.mind != null and not creature.mind.objects.is_empty():
			if int(creature.mind.objects.target) >= int(data.next_id): return null
			for key in creature.mind.objects.entries:
				if int(key) >= int(data.next_id): return null
	# Shared replicas across collections are intentional, but must agree.
	for collection in artifact_collections:
		for art in collection:
			var aid: int = int(art.id)
			var canonical: Dictionary = Data.restore_precision(art)
			if artifact_registry.has(aid) and artifact_registry[aid] != canonical: return null
			artifact_registry[aid] = canonical
	# New physical devices share the same global identity namespace as drawings.
	for artifact_id in artifact_registry: used_ids[artifact_id] = true
	for used_id in used_ids:
		if used_id >= int(data["next_id"]):
			return null
	if not result._restore_terminals(data, used_ids): return null
	if result.pet_id != -1 and not result.creatures.has(result.pet_id):
		return null
	result.events = Data.restore_precision(data["events"])
	result.ids.next_id = int(data["next_id"])
	result.rng.restore(data["rng_state"])
	result.signal_log = Data.restore_precision(data["signal_log"])
	if not result.comandos.restore(data.get("commands"), result):
		return null
	return result

## v1 had no reproductive history: reconstruct the surviving founders only.
## Preserve all old fields, including brains/RNG; no dead ancestors are invented.
static func _migrate_v1(data: Dictionary) -> Dictionary:
	if not data.get("config") is Dictionary or not data.get("creatures") is Array or not Data.integer(data.get("tick")):
		return {}
	var migrated := data.duplicate(true)
	var history := Genealogy.new()
	for entry in migrated["creatures"]:
		if not entry is Dictionary:
			return {}
		var creature := Creature.from_dict(entry)
		if creature == null:
			return {}
		entry["reproduction_cooldown"] = creature.reproduction_cooldown
		history.register(creature, maxi(0, int(data["tick"]) - creature.age), [], not creature.genome.parents.is_empty() or creature.genome.generation != 0)
	migrated["config"].merge(EVOLUTION_DEFAULTS, false)
	# v1 allowed up to 10000 imported creatures, so migration must retain them.
	if not Data.integer(migrated["config"]["max_population"], 1):
		return {}
	migrated["config"]["max_population"] = maxi(int(migrated["config"]["max_population"]), migrated["creatures"].size())
	migrated["genealogy"] = history.to_array()
	migrated["save_version"] = 2
	return migrated

## Earlier worlds keep the channel disabled until explicitly enabled by the player.
static func _migrate_v2(data: Dictionary) -> Dictionary:
	if not data.get("config") is Dictionary:
		return {}
	var migrated := data.duplicate(true)
	migrated["config"].merge(Signals.DEFAULTS, false)
	migrated["config"]["signal_enabled"] = false
	migrated["signal_log"] = []
	migrated["commands"] = {"order": {}, "protection_requested": false}
	migrated["save_version"] = 3
	return migrated

## Migration never consumes RNG/IDs and never invents water in historical worlds.
static func _migrate_v3(data: Dictionary) -> Dictionary:
	if Data.integer(data.get("save_version")) and int(data["save_version"]) >= 4:
		return data.duplicate(true)
	if not data.get("config") is Dictionary or not data.get("creatures") is Array or not data.get("foods") is Array:
		return {}
	var migrated := data.duplicate(true)
	migrated["config"]["water_enabled"] = false
	migrated["waters"] = []
	for entry in migrated["creatures"]:
		if not entry is Dictionary:
			return {}
		entry["hydration"] = Water.INITIAL
	for food in migrated["foods"]:
		if not food is Dictionary:
			return {}
		food["food_type"] = "legacy"
	migrated["save_version"] = 4
	return migrated

## Old worlds retain identical decisions, physiological rules and RNG consumption.
static func _migrate_v4(data: Dictionary) -> Dictionary:
	if Data.integer(data.get("save_version")) and int(data["save_version"]) >= 5:
		return data.duplicate(true)
	if not data.get("config") is Dictionary:
		return {}
	var migrated := data.duplicate(true)
	migrated["config"]["personality_enabled"] = false
	migrated["save_version"] = 5
	return migrated

## Teaching is opt-in; no invented experience, RNG draws or Q updates on migration.
static func _migrate_v5(data: Dictionary) -> Dictionary:
	if Data.integer(data.get("save_version")) and int(data["save_version"]) >= 6:
		return data.duplicate(true)
	var migrated := data.duplicate(true)
	migrated["save_version"] = 6
	return migrated

## Only the allowed vocabulary changed; retain every existing event and bond.
static func _migrate_v6(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	if data.get("save_version") == 6:
		migrated["save_version"] = 7
	return migrated

## Idempotent migration never activates M1 or invents an acquired experience.
static func _migrate_v7(data: Dictionary) -> Dictionary:
	if data.get("save_version") in [8, 9, 10, 11, 12, SAVE_VERSION]:
		return data.duplicate(true)
	if not data.get("config") is Dictionary or not data.get("creatures") is Array:
		return {}
	var migrated := data.duplicate(true)
	migrated["config"]["mind_all"] = false
	migrated["config"]["mind_enabled_ids"] = []
	for entry in migrated["creatures"]:
		if not entry is Dictionary or entry.has("mind"):
			return {}
	migrated["save_version"] = 8
	return migrated

static func _migrate_v8(data: Dictionary) -> Dictionary:
	if data.get("save_version") in [9, 10, 11, 12, SAVE_VERSION]: return data.duplicate(true)
	if data.get("save_version") != 8 or not data.get("creatures") is Array: return {}
	# Legacy fixtures may retain empty modern metadata; never discard acquired data.
	if data.has("objects") and (not data.objects is Array or not data.objects.is_empty()): return {}
	if data.has("object_catalog_version") and (not Data.integer(data.object_catalog_version, 1) or int(data.object_catalog_version) != ObjectCatalog.VERSION): return {}
	for c in data.creatures:
		if not c is Dictionary: return {}
		if c.has("mind") and (not c.mind is Dictionary or not c.mind.get("objects") is Dictionary or not c.mind.objects.is_empty()): return {}
	var migrated := data.duplicate(true)
	migrated["objects"] = []
	migrated["object_catalog_version"] = ObjectCatalog.VERSION
	migrated["save_version"] = 9
	return migrated

static func _migrate_v9(data: Dictionary) -> Dictionary:
	if data.get("save_version") in [10, 11, 12, SAVE_VERSION]: return data.duplicate(true)
	if data.get("save_version") != 9 or not data.get("creatures") is Array: return {}
	if data.has("boards") and (not data.boards is Array or not data.boards.is_empty()): return {}
	if data.has("gallery") and (not data.gallery is Array or not data.gallery.is_empty()): return {}
	for c in data.creatures:
		if not c is Dictionary or c.has("atelier"): return {}
	var migrated := data.duplicate(true)
	migrated["save_version"] = 11
	return migrated

static func _migrate_v10(data: Dictionary) -> Dictionary:
	if data.get("save_version") in [11, 12, SAVE_VERSION]: return data.duplicate(true)
	if data.get("save_version") != 10 or not data.get("creatures") is Array: return {}
	var migrated := data.duplicate(true)
	for c in migrated.creatures:
		if not c is Dictionary: return {}
		if c.has("atelier"):
			if not c.atelier is Dictionary or c.atelier.get("version") != 1: return {}
			c["atelier"] = Atelier.migrate_v1(c.atelier)
			if c.atelier.is_empty(): return {}
	migrated["save_version"] = 11
	return migrated

func _suspend_brain(creature: Creature) -> void:
	if creature.brain != null and creature.brain.has_method("suspend_transition"):
		creature.brain.suspend_transition()

func _personality_seek_food(creature: Creature, sensors: Dictionary, closest: Dictionary, distance: float) -> bool:
	if not closest.is_empty():
		if distance <= Obs.reach(creature):
			_eat(creature, int(closest["id"]))
			return false
		creature.heading = (closest["pos"] - creature.pos).angle()
		creature.last_action = "seek_food"
		creature.last_reason = "personality.survival"
	else:
		if creature.age % 15 == 0:
			creature.heading += rng.between(-0.9, 0.9)
		creature.last_action = "explore"
		creature.last_reason = "personality.survival"
	return _move(creature, sensors["obstacles"])

func _personality_action(creature: Creature, sensors: Dictionary, motive: String) -> bool:
	if motive == "rest":
		creature.last_action = "rest"
		creature.last_reason = "personality.fatigue"
		return false
	if motive == "contact":
		var nearest: Dictionary = {}
		var best := INF
		for other in sensors["creatures"]:
			var bond: Dictionary = creature.personality.bonds.get(str(other["id"]), {})
			var score: float = creature.pos.distance_to(other["pos"]) / (1.0 + float(bond.get("familiarity", 0.0)) * maxf(0.0, float(bond.get("valence", 0.0))))
			if score < best:
				best = score
				nearest = other
		if not nearest.is_empty():
			var other: Creature = creatures[int(nearest["id"])]
			creature.last_reason = "personality.contact"
			if creature.pos.distance_to(other.pos) <= creature.genome.size + other.genome.size + 8.0:
				creature.last_action = "social_contact"
				return false
			creature.heading = (other.pos - creature.pos).angle()
			creature.last_action = "seek_contact"
			return _move(creature, sensors["obstacles"])
	# Searching without a perceived neighbor is an actual exploration, not free contact.
	creature.last_action = "explore"
	creature.last_reason = "personality.curiosity"
	if creature.age % 15 == 0:
		var turn: float = 0.2 + 0.8 * float(creature.temperament["impulsivity"])
		creature.heading += rng.between(-turn, turn)
	return _move(creature, sensors["obstacles"])

func _personality_encounters(creature: Creature, sensors: Dictionary) -> void:
	for row in sensors["creatures"]:
		var other: Creature = creatures[int(row["id"])]
		if not other.alive or creature.pos.distance_to(other.pos) > creature.genome.size + other.genome.size + 8.0 or _occluded(creature.pos, other.pos):
			continue
		Social.encounter(self, creature, other, sensors)

## A registered interaction requires actual contact range and line of sight.
## A click far from the organism cannot create familiarity or physical resources.
func interagir_jogador(creature_id: int, position: Vector2, valencia: float = 0.2) -> bool:
	if not personality_enabled or not creatures.has(creature_id) or not position.is_finite() or not is_finite(valencia) or absf(valencia) > 1.0:
		return false
	var creature: Creature = creatures[creature_id]
	if not creature.alive or creature.pos.distance_to(position) > Obs.reach(creature) or _occluded(creature.pos, position):
		return false
	var where := Personality.context(creature)
	if not creature.personality.meet("player", tick, valencia):
		return false
	creature.personality.stimulus("player", tick)
	creature.personality.record(tick, where, "player_contact", 0.0, 0.0, 0.0, "player_contact", "player")
	return true

## E3 public API. Snapshots are detached copies; no physiology changes here.
func ensino_habilidades() -> Array:
	return [
		{"id": "ir_ate_local", "text": Text.E3_CATALOGO.ir_ate_local, "requires_target": true},
		{"id": "buscar_agua", "text": Text.E3_CATALOGO.buscar_agua, "requires_target": false}
	]

func ensino_iniciar(creature_id: int, skill: String, target: Vector2 = Vector2.INF, assisted: bool = false, horizon: int = 200, policy: String = "q") -> Dictionary:
	if not creatures.has(creature_id) or not creatures[creature_id].alive or skill not in Obs.GOAL_SKILLS or policy not in ["q", "heuristica"] or horizon < 1 or horizon > Ensino.TRACE_LIMIT:
		return {"ok": false, "code": "invalid_request"}
	var creature: Creature = creatures[creature_id]
	if skill == "ir_ate_local" and (not Commands._alvo_valido(target, self) or target != _inside(target, creature.genome.size) or not _clear(target, creature.genome.size)):
		return {"ok": false, "code": "invalid_target"}
	if skill == "buscar_agua":
		if not water_enabled:
			return {"ok": false, "code": "water_disabled"}
		target = creature.pos # Actual water target is resolved only from sensors.
	if creature.ensino == null:
		creature.ensino = Ensino.new()
	if creature.ensino.running():
		creature.ensino.finish(tick, "cancelled", creature.energy, creature.ensino.active.final_distance)
	comandos.cancelar_ordem(creature_id)
	if policy == "q" and creature.brain == null:
		creature.brain = QBrain.new()
		creature.brain.teaching_only = true
	_suspend_brain(creature)
	creature.ensino.start(skill, target, tick, creature.energy, assisted, horizon, policy)
	return ensino_observar(creature_id)

## Showing a marker alone does not steer. Assisted routes consume ordinary actions.
func ensino_mostrar(creature_id: int, target: Vector2 = Vector2.INF, assisted: bool = false) -> Dictionary:
	if not creatures.has(creature_id) or creatures[creature_id].ensino == null or not creatures[creature_id].ensino.running():
		return {"ok": false, "code": "no_attempt"}
	var creature: Creature = creatures[creature_id]
	var active: Dictionary = creature.ensino.active
	if target.is_finite():
		if active.skill != "ir_ate_local" or not Commands._alvo_valido(target, self) or target != _inside(target, creature.genome.size) or not _clear(target, creature.genome.size):
			return {"ok": false, "code": "invalid_target"}
		# A different target is a new attempt, preserving honest completion evidence.
		if Data.unpack_vector(active.target) != target:
			return ensino_iniciar(creature_id, active.skill, target, assisted, active.horizon, active.policy)
	active.assisted = assisted
	creature.ensino.record(tick, "show", {}, -1, "active", 0)
	return ensino_observar(creature_id)

func ensino_observar(creature_id: int) -> Dictionary:
	if not creatures.has(creature_id):
		return {"ok": false, "code": "no_creature"}
	var result: Dictionary = Ensino.new().snapshot() if creatures[creature_id].ensino == null else creatures[creature_id].ensino.snapshot()
	result["creature_id"] = creature_id
	return result

func ensino_cancelar(creature_id: int) -> bool:
	if not creatures.has(creature_id) or creatures[creature_id].ensino == null:
		return false
	var creature: Creature = creatures[creature_id]
	creature.ensino.finish(tick, "cancelled", creature.energy, creature.ensino.active.get("final_distance", 0.0))
	return true

func ensino_recompensar(creature_id: int) -> Dictionary:
	if not creatures.has(creature_id) or creatures[creature_id].ensino == null:
		return {"ok": false, "code": "no_attempt", "updates": 0}
	var creature: Creature = creatures[creature_id]
	var teaching = creature.ensino
	var code := "success"
	if teaching.active.is_empty() or teaching.active.status != "success":
		code = "not_completed"
	elif teaching.active.rewarded:
		code = "already_rewarded"
	elif creature.brain == null or not creature.brain.has_method("reward_goal") or not creature.brain.learning:
		code = "frozen"
	if code != "success":
		teaching.record(tick, "reward_rejected", {}, -1, code, 0)
		return {"ok": false, "code": code, "updates": 0}
	var updates: int = creature.brain.reward_goal(teaching.active.trace)
	teaching.active.rewarded = true
	teaching.active.updates = updates
	if not teaching.attempts.is_empty():
		teaching.attempts.back().rewarded = true
		teaching.attempts.back().updates = updates
	teaching.record(tick, "reward", {}, -1, "success", updates)
	return {"ok": true, "code": "success", "updates": updates}

func ensino_reset(creature_id: int) -> bool:
	if not creatures.has(creature_id):
		return false
	var creature: Creature = creatures[creature_id]
	creature.ensino = Ensino.new()
	if creature.brain != null and creature.brain.has_method("reset_goals"):
		creature.brain.reset_goals()
	return true

func _ensino_act(creature: Creature, sensors: Dictionary) -> bool:
	_suspend_brain(creature)
	var teaching = creature.ensino
	var active: Dictionary = teaching.active
	var target := Data.unpack_vector(active.target)
	var visible := true
	if active.skill == "buscar_agua":
		visible = false
		var closest := INF
		for water in sensors.get("waters", []):
			var distance: float = creature.pos.distance_to(water.pos)
			if distance < closest:
				closest = distance
				target = water.pos
				visible = true
		active.target = Data.pack_vector(target)
	var obs := Obs.goal_features(creature, active.skill, target, sensors, size, visible)
	var action := Actions.FORWARD
	var assisted: bool = active.assisted
	if assisted or active.policy == "heuristica":
		if visible and int(obs.distance_bucket) == 0:
			action = Actions.DRINK if active.skill == "buscar_agua" else Actions.REST
		elif visible:
			var angle := wrapf((target - creature.pos).angle() - creature.heading, -PI, PI)
			if absf(angle) > 0.25:
				action = Actions.TURN_LEFT if angle < 0 else Actions.TURN_RIGHT
		elif creature.age % 15 == 0:
			action = Actions.TURN_RIGHT
	elif not visible:
		action = Actions.TURN_RIGHT if creature.age % 15 == 0 else Actions.FORWARD
	elif creature.brain != null and creature.brain.has_method("decide_goal"):
		action = creature.brain.decide_goal(obs, rng)
	elif creature.brain != null:
		var random_obs := Obs.features(creature, sensors, size)
		action = creature.brain.decide(creature, random_obs, rng)
	teaching.step_record(tick, obs, action, assisted, creature.energy)
	creature.last_action = Actions.name_of(action)
	creature.last_reason = "teaching.assisted" if assisted else "teaching.goal"
	var moved := _apply_action(creature, sensors, action)
	teaching.events.back().result = "moved" if moved else ("drink" if creature.last_action == "drink" and creature.last_reason == "ecology.drink" else "no_movement")
	return moved

func _ensino_finish_tick(creature: Creature, acted: bool) -> void:
	var teaching = creature.ensino
	var active: Dictionary = teaching.active
	var target := Data.unpack_vector(active.target)
	var distance: float = creature.pos.distance_to(target)
	var success := false
	if acted and active.skill == "ir_ate_local":
		success = distance <= Obs.reach(creature) and not _occluded(creature.pos, target)
	elif acted and active.skill == "buscar_agua":
		for event in events:
			if event.tick == tick and event.creature_id == creature.id and event.type == "drink" and event.hydration > 0.0:
				success = true
	if success:
		teaching.finish(tick, "success", creature.energy, distance)
	elif tick - int(active.start_tick) >= int(active.horizon):
		teaching.finish(tick, "timeout", creature.energy, distance)

## Detached evidence for UI/dialogue; reading never creates encounters.
func social_observar(creature_id: int) -> Dictionary:
	if not personality_enabled or not creatures.has(creature_id):
		return {"ok": false, "relations": []}
	var result: Array = []
	var keys: Array = creatures[creature_id].personality.bonds.keys()
	keys.sort()
	for key in keys:
		if key != "player":
			result.append(Social.relation(creatures[creature_id].personality, int(key)))
	return {"ok": true, "relations": result, "limit": Personality.BOND_LIMIT}

func _social_action(creature: Creature, sensors: Dictionary, decision: Dictionary) -> bool:
	creature.last_action = "seek_contact" if decision.action == "social_approach" else decision.action
	creature.last_reason = "social." + decision.action.trim_prefix("social_")
	if decision.action == "social_compete" and creature.pos.distance_to(decision.target) <= Obs.reach(creature):
		_eat(creature, int(decision.food_id))
		return false
	if decision.action in ["social_follow", "social_approach"] and float(decision.distance) <= creature.genome.size + creatures[int(decision.other_id)].genome.size + 8.0:
		return false
	if creature.pos.distance_to(decision.target) < 0.01:
		return false
	creature.heading = (decision.target - creature.pos).angle()
	return _move(creature, sensors.obstacles)


## Mental goals execute exclusively through existing physical/cost paths.
func _mind_action(creature: Creature, sensors: Dictionary, goal: String, closest: Dictionary, distance: float) -> bool:
	creature.last_reason = "mind." + goal
	match goal:
		"usar_terminal":
			var selected := TerminalLearning.candidate(creature.mind, creature, sensors, tick)
			for device in sensors.get("terminals", []):
				if int(device.id) != int(selected.id): continue
				if creature.pos.distance_to(device.pos) <= Obs.reach(creature): return terminal_step(creature, int(device.id))
				creature.heading = (device.pos - creature.pos).angle()
				creature.last_action = "seek_terminal"
				return _move(creature, sensors.obstacles)
			return false
		"ler":
			var selected: Dictionary = Mind.Reading.candidate(creature.mind, creature, sensors)
			for b in sensors.get("books", []):
				if int(b.id) != int(selected.id): continue
				if creature.pos.distance_to(b.pos) <= Obs.reach(creature):
					read_book(creature, int(b.id))
					return false
				creature.heading = (b.pos - creature.pos).angle()
				creature.last_action = "seek_book"
				return _move(creature, sensors.obstacles)
			creature.last_action = "rest"
			return false
		"investigar_objeto":
			var target: int = Mind.ObjectMemory.state(creature.mind).target
			for row in sensors.get("objects", []):
				if int(row.id) != target: continue
				if creature.pos.distance_to(row.pos) <= Obs.reach(creature):
					interact_object(creature, target)
					return false
				creature.heading = (row.pos - creature.pos).angle()
				creature.last_action = "seek_object"
				return _move(creature, sensors.obstacles)
			creature.last_action = "rest"
			return false
		"desenhar":
			var board_target: int = Mind.ObjectMemory.state(creature.mind).target
			for row in sensors.get("boards", []):
				if int(row.id) != board_target: continue
				if creature.pos.distance_to(row.pos) <= Obs.reach(creature):
					draw_on_board(creature, board_target)
					return false
				creature.heading = (row.pos - creature.pos).angle()
				creature.last_action = "seek_board"
				return _move(creature, sensors.obstacles)
			creature.last_action = "rest"
			return false
		"comer":
			return _personality_seek_food(creature, sensors, closest, distance)
		"beber":
			return _seek_water(creature, sensors)
		"descansar":
			creature.last_action = "rest"
			return false
		"buscar_companhia", "buscar_privacidade":
			var nearest: Dictionary = {}
			var best := INF
			for row in sensors.get("creatures", []):
				var d: float = creature.pos.distance_to(row.pos)
				if d < best:
					best = d
					nearest = row
			if not nearest.is_empty():
				var other: Creature = creatures[int(nearest.id)]
				if goal == "buscar_companhia":
					if best <= creature.genome.size + other.genome.size + 8.0:
						creature.last_action = "social_contact"
						return false
					creature.heading = (other.pos - creature.pos).angle()
					creature.last_action = "seek_contact"
				else:
					var away := creature.pos - other.pos
					creature.heading = away.angle() if not away.is_zero_approx() else creature.heading + PI
					creature.last_action = "social_avoid"
				return _move(creature, sensors.obstacles)
	# Play is physical locomotion with ordinary movement cost; M2 remains a stub.
	creature.last_action = "explore"
	if creature.age % (8 if goal == "brincar" else 15) == 0:
		creature.heading += creature.mind.rng.between(-0.9, 0.9)
	return _move(creature, sensors.obstacles)

static func _migrate_v11(data: Dictionary) -> Dictionary:
	if data.get("save_version") in [12, SAVE_VERSION]: return data.duplicate(true)
	if data.get("save_version") != 11 or not data.get("creatures") is Array: return {}
	if data.has("library"): return {}
	for c in data.creatures:
		if not c is Dictionary: return {}
		if c.has("mind") and (not c.mind is Dictionary or c.mind.has("knowledge")): return {}
	var migrated := data.duplicate(true)
	migrated["save_version"] = 12
	return migrated

func place_book(pos: Vector2, book_id: String) -> int:
	if not pos.is_finite() or not Books.BOOKS.has(book_id) or library.books.size() >= Books.LIMIT: return -1
	var location := _inside(pos, 5.0)
	if not _clear(location, 5.0): return -1
	var book_ref: int = ids.take()
	library.books.append({"id": book_ref, "pos": location, "book_id": book_id})
	return book_ref

func read_book(creature: Creature, book_ref: int) -> bool:
	if not creature.alive or creature.mind == null or creature.hunger > 0.55 or (water_enabled and creature.thirst > 0.55): return false
	for b in library.books:
		if int(b.id) != book_ref: continue
		if creature.pos.distance_to(b.pos) > Obs.reach(creature) or _occluded(creature.pos, b.pos): return false
		var read: bool = Mind.Reading.page_tick(creature.mind, b, tick)
		if read: creature.last_action = "read_book"
		return read
	return false

func responder_pergunta(question_id: String, option: String) -> bool:
	for c in creatures.values():
		if c.mind != null and not c.mind.knowledge.is_empty() and c.mind.knowledge.questions.any(func(q): return q.id == question_id):
			return Mind.Knowledge.answer(c.mind, c, question_id, option, tick)
	return false

func demonstrar_simbolo(creature_id: int, glyph: String, object_id: int, correct: bool = true) -> bool:
	var c = creatures.get(creature_id)
	if c == null or c.mind == null or not c.alive: return false
	for row in sense(c).get("objects", []):
		if int(row.id) == object_id: return Mind.Knowledge.demonstrate(c.mind, glyph, row.category, correct, tick)
	return false
