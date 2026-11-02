extends RefCounted
## Individual lifetime state. Temperament belongs to Genome; none of this is inherited.
## Original implementation from the EvoWorld requirements, with no external code/assets.
const Data = preload("res://scripts/core/sim_data.gd")
const Food = preload("res://scripts/environment/food_catalog.gd")
const EPISODE_LIMIT := 32
const EPISODE_MAX_AGE := 2400
const BOND_LIMIT := 32
const STIMULUS_LIMIT := 24
const CONTEXT_LIMIT := 45 # five food types x three energy x three hydration buckets
const ENCOUNTER_INTERVAL := 30
const EVENTS := ["metabolism", "food", "toxic_food", "water", "rest", "exploration", "contact", "collision", "player_contact", "resource_contention"]
const ROUTINE_SOURCES := ["body", "movement", "rest"]
const SOURCES := ["body", "ingestion", "drinking", "movement", "rest", "encounter", "player"]
const ACTIONS := ["seek_board", "draw_stroke", "seek_object", "investigate_object", "social_approach", "social_follow", "social_avoid", "social_share", "social_compete", "rest", "explore", "seek_contact", "social_contact", "seek_food", "seek_water", "eat", "drink", "forward", "turn_left", "turn_right", "avoid_obstacle", "player_contact", "emit_signal_0", "emit_signal_1", "emit_signal_2", "emit_signal_3", "emit_signal_4", "emit_signal_5", "emit_signal_6", "emit_signal_7"]

var fatigue := 0.0
var boredom := 0.0
var loneliness := 0.0
var event_valence := 0.0
var episodes: Array = []
var preferences: Dictionary = {}
var conditioning: Dictionary = {}
var habituation: Dictionary = {}
var bonds: Dictionary = {}

static func unit(value: Variant) -> bool:
	return Data.number(value) and float(value) >= 0.0 and float(value) <= 1.0

static func signed_unit(value: Variant) -> bool:
	return Data.number(value) and absf(float(value)) <= 1.0

static func context(creature, food_type: String = "legacy") -> Dictionary:
	return {"energy": mini(2, int(creature.energy / creature.max_energy * 3.0)),
		"hydration": mini(2, int(creature.hydration / 100.0 * 3.0)), "food_type": food_type}

static func context_key(value: Dictionary) -> String:
	return "%s:%d:%d" % [value["food_type"], value["energy"], value["hydration"]]

func advance(tick: int, traits: Dictionary) -> void:
	boredom = _unit(boredom + 0.0015 * (0.5 + float(traits["curiosity"])))
	loneliness = _unit(loneliness + 0.001 * (0.25 + float(traits["sociability"])))
	event_valence = snappedf(event_valence * 0.97, 0.000001)
	var expired: Array = []
	for key in habituation:
		var item: Dictionary = habituation[key]
		item["level"] = snappedf(clampf(float(item["level"]) - 0.002, 0.0, 1.0), 0.000001)
		if tick - int(item["last_tick"]) > 600:
			expired.append(key)
	for key in expired:
		habituation.erase(key)
	expired.clear()
	for key in bonds:
		var item: Dictionary = bonds[key]
		item["familiarity"] = snappedf(clampf(float(item["familiarity"]) - 0.00002, 0.0, 1.0), 0.000001)
		item["valence"] = snappedf(float(item["valence"]) * 0.9995, 0.000001)
		if tick - int(item["last_tick"]) > 12000 and float(item["familiarity"]) <= 0.0:
			expired.append(key)
	for key in expired:
		bonds.erase(key)
	# Strong measured outcomes persist longer than ordinary metabolic ticks.
	# Episodes are ordered by tick (validated on load), so everything newer than
	# the ordinary lifetime is retained without inspecting it.
	var oldest_kept := tick - 300
	var index := 0
	while index < episodes.size():
		var item: Dictionary = episodes[index]
		var born := int(item["tick"])
		if born >= oldest_kept:
			break
		var relevant: bool = absf(float(item["consequence"]["energy"])) >= 1.0 or item["reward_source"] in ["encounter", "player", "drinking"]
		if tick - born > (EPISODE_MAX_AGE if relevant else 300):
			episodes.remove_at(index)
		else:
			index += 1

## Repetition changes sensory novelty, never nutritional reward or vital reflexes.
func stimulus(key: String, tick: int) -> float:
	if not habituation.has(key):
		_evict_oldest(habituation, STIMULUS_LIMIT)
		habituation[key] = {"level": 0.0, "last_tick": tick}
	var item: Dictionary = habituation[key]
	var novelty := 1.0 - float(item["level"])
	item["level"] = _unit(float(item["level"]) + 0.08 * novelty)
	item["last_tick"] = tick
	return novelty

func perceive(sensors: Dictionary, tick: int) -> void:
	var seen: Dictionary = {}
	for food in sensors.get("foods", []):
		var key: String = "food:" + food["food_type"]
		if not seen.has(key):
			stimulus(key, tick)
			seen[key] = true
	if not sensors.get("signal", {}).is_empty():
		stimulus("signal:%d" % int(sensors["signal"]["symbol"]), tick)

func food_weight(creature, food_type: String) -> float:
	var traits: Dictionary = creature.temperament
	var learned := float(preferences.get(food_type, 0.0))
	var expected := float(conditioning.get(context_key(context(creature, food_type)), 0.0))
	var level := float(habituation.get("food:" + food_type, {}).get("level", 0.0))
	var bias := 0.15 * float(traits["curiosity"]) * (1.0 - level)
	var caution := 1.0 + float(traits["caution"]) * (1.0 - float(traits["impulsivity"]))
	return clampf(1.0 + bias + (learned * 0.8 + expected * 0.2) * caution, 0.08, 2.5)

## Rescorla-Wagner updates only after ingestion, using measured benefit/damage.
## Toxic exposure is a physical damage component, even when net nutrition is positive.
func ingest(creature, tick: int, before: Dictionary, food_type: String, delta_energy: float, delta_hydration: float, toxicity: float) -> void:
	var outcome := clampf((delta_energy + 0.25 * delta_hydration) / 32.0 - toxicity / 8.0, -1.0, 1.0)
	var alpha := 0.12 + 0.18 * float(creature.temperament["caution"])
	var prediction := float(preferences.get(food_type, 0.0))
	preferences[food_type] = snappedf(clampf(prediction + alpha * (outcome - prediction), -1.0, 1.0), 0.000001)
	var key := context_key(before)
	prediction = float(conditioning.get(key, 0.0))
	conditioning[key] = snappedf(clampf(prediction + alpha * (outcome - prediction), -1.0, 1.0), 0.000001)
	event_valence = snappedf(outcome, 0.000001)
	record(tick, before, "eat", delta_energy, delta_hydration, 0.0, "toxic_food" if toxicity > 0.0 else "food", "ingestion")

func record(tick: int, where: Dictionary, action: String, de: float, dh: float, df: float, event: String, source: String) -> void:
	episodes.append({"tick": tick, "context": where.duplicate(), "action": action,
		"consequence": {"energy": snappedf(de, 0.000001), "hydration": snappedf(dh, 0.000001), "fatigue": snappedf(df, 0.000001), "event": event}, "reward_source": source})
	if episodes.size() > EPISODE_LIMIT:
		# Keep recent consequential episodes over routine metabolic samples.
		var victim := 0
		for index in range(episodes.size() - 1):
			if episodes[index]["reward_source"] in ROUTINE_SOURCES:
				victim = index
				break
		episodes.remove_at(victim)

func meet(key: String, tick: int, valence: float) -> bool:
	if bonds.has(key) and tick - int(bonds[key]["last_tick"]) < ENCOUNTER_INTERVAL:
		return false
	if not bonds.has(key):
		_evict_oldest(bonds, BOND_LIMIT)
		bonds[key] = {"count": 0, "valence": 0.0, "familiarity": 0.0, "last_tick": tick}
	var item: Dictionary = bonds[key]
	item["count"] = mini(10000, int(item["count"]) + 1)
	item["valence"] = snappedf(clampf(float(item["valence"]) + 0.2 * (valence - float(item["valence"])), -1.0, 1.0), 0.000001)
	item["familiarity"] = _unit(float(item["familiarity"]) + 0.04)
	item["last_tick"] = tick
	loneliness = _unit(loneliness - 0.12 * maxf(0.0, valence + 0.2))
	event_valence = snappedf(valence, 0.000001)
	return true

func motive(traits: Dictionary) -> String:
	if fatigue >= 0.85:
		return "rest"
	var rest := fatigue * (0.55 + 0.6 * float(traits["caution"]))
	var explore := boredom * (0.25 + float(traits["curiosity"]) + 0.25 * float(traits["impulsivity"]))
	var contact := loneliness * (0.2 + 1.1 * float(traits["sociability"]))
	var highest := maxf(rest, maxf(explore, contact))
	if highest < 0.32:
		return ""
	if highest == rest:
		return "rest"
	return "contact" if highest == contact else "explore"

func finish_tick(creature, tick: int, moving: bool, before: Dictionary, started: Dictionary) -> void:
	var old_fatigue := fatigue
	var event := "metabolism"
	var source := "body"
	if creature.last_action == "rest":
		fatigue = _unit(fatigue - 0.025)
		event = "rest"
		source = "rest" if old_fatigue - fatigue > 0.0 else "body"
	else:
		fatigue = _unit(fatigue + (0.007 if moving else 0.002))
	if moving:
		var novelty := stimulus("zone:%d:%d" % [int(creature.pos.x / 64.0), int(creature.pos.y / 64.0)], tick)
		boredom = _unit(boredom - 0.012 * (0.25 + novelty * 0.75))
		event = "exploration"
		source = "movement"
	elif creature.last_action == "avoid_obstacle":
		event = "collision"
		event_valence = -0.2
	# Physiological samples exclude ingest/drink deltas, which have their own episodes.
	record(tick, before, creature.last_action, creature.energy - float(started["energy"]),
		creature.hydration - float(started["hydration"]), fatigue - old_fatigue, event, source)

func expression(creature) -> Dictionary:
	var deficit := maxf(creature.hunger, maxf(creature.thirst if creature.personality_water_enabled else 0.0, fatigue))
	return {"valence": snappedf(clampf(0.25 - deficit * 0.65 - loneliness * 0.15 - boredom * 0.1 + event_valence * 0.45, -1.0, 1.0), 0.000001),
		"arousal": _unit(0.12 + deficit * 0.5 + boredom * float(creature.temperament["curiosity"]) * 0.25 + absf(event_valence) * 0.25 - (0.15 if creature.last_action == "rest" else 0.0))}

func to_dict() -> Dictionary:
	return Data.restore_precision({"fatigue": fatigue, "boredom": boredom, "loneliness": loneliness,
		"event_valence": event_valence, "episodes": episodes, "preferences": preferences,
		"conditioning": conditioning, "habituation": habituation, "bonds": bonds})

static func from_dict(value: Variant, max_tick: int = 2147483647):
	if not value is Dictionary or value.size() != 9:
		return null
	for key in ["fatigue", "boredom", "loneliness"]:
		if not unit(value.get(key)):
			return null
	if not signed_unit(value.get("event_valence")) or not value.get("episodes") is Array or value["episodes"].size() > EPISODE_LIMIT:
		return null
	var last_tick := -1
	for item in value["episodes"]:
		if not valid_episode(item, max_tick) or int(item["tick"]) < last_tick:
			return null
		last_tick = int(item["tick"])
	for key in ["preferences", "conditioning", "habituation", "bonds"]:
		if not value.get(key) is Dictionary:
			return null
	if value["preferences"].size() > Food.PARAMETERS.size() or value["conditioning"].size() > CONTEXT_LIMIT or value["habituation"].size() > STIMULUS_LIMIT or value["bonds"].size() > BOND_LIMIT:
		return null
	for key in value["preferences"]:
		if not Food.valid_type(key) or not signed_unit(value["preferences"][key]):
			return null
	for key in value["conditioning"]:
		if not key is String:
			return null
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 3 or not Food.valid_type(parts[0]) or parts[1] not in ["0", "1", "2"] or parts[2] not in ["0", "1", "2"] or not signed_unit(value["conditioning"][key]):
			return null
	for key in value["habituation"]:
		var item: Variant = value["habituation"][key]
		if not key is String or key.length() > 64 or not item is Dictionary or item.size() != 2 or not unit(item.get("level")) or not Data.integer(item.get("last_tick")) or int(item["last_tick"]) > max_tick:
			return null
	for key in value["bonds"]:
		var item: Variant = value["bonds"][key]
		if not key is String or (key != "player" and (not Data.integer_text(key) or int(key) < 1 or int(key) > 2147483647)):
			return null
		if not item is Dictionary or item.size() != 4 or not Data.integer(item.get("count"), 1) or int(item["count"]) > 10000 or not signed_unit(item.get("valence")) or not unit(item.get("familiarity")) or not Data.integer(item.get("last_tick")) or int(item["last_tick"]) > max_tick:
			return null
	var result = load("res://scripts/behavior/personality.gd").new()
	for key in value:
		result.set(key, Data.restore_precision(value[key]))
	return result

static func valid_episode(item: Variant, max_tick: int) -> bool:
	if not item is Dictionary or item.size() != 5 or not Data.integer(item.get("tick")) or int(item["tick"]) > max_tick or item.get("action") not in ACTIONS or item.get("reward_source") not in SOURCES:
		return false
	var where: Variant = item.get("context")
	if not where is Dictionary or where.size() != 3 or not Data.integer(where.get("energy")) or int(where["energy"]) > 2 or not Data.integer(where.get("hydration")) or int(where["hydration"]) > 2 or not Food.valid_type(where.get("food_type")):
		return false
	var effect: Variant = item.get("consequence")
	if not effect is Dictionary or effect.size() != 4 or effect.get("event") not in EVENTS:
		return false
	for key in ["energy", "hydration", "fatigue"]:
		if not Data.number(effect.get(key)) or absf(float(effect[key])) > (10000.0 if key == "energy" else (100.0 if key == "hydration" else 1.0)):
			return false
	return true

static func _unit(value: float) -> float:
	return snappedf(clampf(value, 0.0, 1.0), 0.000001)

static func _evict_oldest(table: Dictionary, limit: int) -> void:
	if table.size() < limit:
		return
	# Sorted keys make ties deterministic across JSON dictionary reordering.
	var keys := table.keys()
	keys.sort()
	var oldest: String = keys[0]
	for key in keys:
		if int(table[key]["last_tick"]) < int(table[oldest]["last_tick"]):
			oldest = key
	table.erase(oldest)
