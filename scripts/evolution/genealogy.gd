extends RefCounted
## Permanent birth records, including dead ancestors. Creature IDs are the links.
const Data = preload("res://scripts/core/sim_data.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const MAX_RECORDS := 100000
var records: Dictionary = {}

func register(creature, birth_tick: int, mutations: Array = [], legacy_root: bool = false) -> void:
	records[creature.id] = {
		"creature_id": creature.id, "name": creature.name, "genome": creature.genome.to_dict(),
		"parents": [] if legacy_root else creature.genome.parents.duplicate(), "generation": creature.genome.generation,
		"birth_tick": birth_tick, "death_tick": -1, "death_reason": "", "mutations": mutations.duplicate(true)
	}
	records[creature.id]["legacy_root"] = legacy_root

func mark_dead(creature_id: int, tick: int, reason: String) -> void:
	if records.has(creature_id):
		records[creature_id]["death_tick"] = tick
		records[creature_id]["death_reason"] = reason

func lineage(creature_id: int) -> Array:
	if not records.has(creature_id):
		return []
	var result: Array = []
	var pending: Array = [creature_id]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var current: int = pending.pop_back()
		if seen.has(current):
			continue
		seen[current] = true
		result.append(records[current].duplicate(true))
		pending.append_array(records[current]["parents"])
	result.sort_custom(func(a, b): return a["creature_id"] < b["creature_id"])
	return result

func descendants(creature_id: int) -> Array:
	var result: Array = []
	var known := {creature_id: true}
	var ordered := records.keys()
	ordered.sort()
	for current in ordered:
		for parent in records[current]["parents"]:
			if known.has(int(parent)):
				known[current] = true
				result.append(records[current].duplicate(true))
				break
	return result

func to_array() -> Array:
	var result: Array = []
	var ordered := records.keys()
	ordered.sort()
	for creature_id in ordered:
		result.append(Data.restore_precision(records[creature_id]))
	return result

static func from_array(entries: Variant, tick: int, next_id: int):
	if not entries is Array or entries.size() > MAX_RECORDS:
		return null
	var result = load("res://scripts/evolution/genealogy.gd").new()
	var used_ids: Dictionary = {}
	for entry in entries:
		if not entry is Dictionary or entry.size() != 10 or not Data.integer(entry.get("creature_id"), 1) or not entry.get("legacy_root") is bool:
			return null
		var creature_id := int(entry["creature_id"])
		if used_ids.has(creature_id) or creature_id >= next_id:
			return null
		if not entry.get("name") is String or entry["name"].length() > 64 or not entry.get("genome") is Dictionary:
			return null
		var genome := Genes.from_dict(entry["genome"])
		if genome == null or genome.id < 1 or genome.id >= next_id or genome.id == creature_id or used_ids.has(genome.id):
			return null
		if not Data.integer(entry.get("birth_tick")) or int(entry["birth_tick"]) > tick or not Data.integer(entry.get("death_tick"), -1):
			return null
		var death_tick := int(entry["death_tick"])
		if death_tick != -1 and (death_tick < int(entry["birth_tick"]) or death_tick > tick):
			return null
		if not entry.get("death_reason") is String or (death_tick == -1 and entry["death_reason"] != "") or (death_tick != -1 and entry["death_reason"] not in ["starvation", "age", "external"]):
			return null
		if not entry.get("parents") is Array or not Data.integer(entry.get("generation")) or int(entry["generation"]) != genome.generation:
			return null
		if entry["legacy_root"]:
			# v1 accepted arbitrary lineage metadata without actual births. Preserve
			# the genome verbatim, but never present those unverified IDs as links.
			if not entry["parents"].is_empty():
				return null
		elif Data.restore_precision(entry["parents"]) != genome.parents:
			return null
		if not entry.get("mutations") is Array or entry["mutations"].size() > Genes.BOUNDS.size() + Genes.TEMPERAMENT_KEYS.size():
			return null
		var mutated: Dictionary = {}
		for mutation in entry["mutations"]:
			if not Data.mutation(mutation) or mutated.has(mutation["gene"]):
				return null
			mutated[mutation["gene"]] = true
		used_ids[creature_id] = true
		used_ids[genome.id] = true
		var normalized: Dictionary = Data.restore_precision(entry)
		normalized["genome"] = genome.to_dict()
		result.records[creature_id] = normalized
	for creature_id in result.records:
		var entry: Dictionary = result.records[creature_id]
		if entry["parents"].is_empty():
			if (int(entry["generation"]) != 0 and not entry["legacy_root"]) or not entry["mutations"].is_empty():
				return null
			continue
		# Asexual (size 1) or voluntary partner (size 2). Strictly older IDs prove
		# acyclicity without recursion, even for lineages deeper than the GDScript stack.
		if entry["parents"].size() not in [1, 2]:
			return null
		var parent_id := int(entry["parents"][0])
		if parent_id >= creature_id or not result.records.has(parent_id):
			return null
		var parent: Dictionary = result.records[parent_id]
		if int(entry["birth_tick"]) < int(parent["birth_tick"]):
			return null
		if int(parent["death_tick"]) != -1 and int(parent["death_tick"]) < int(entry["birth_tick"]):
			return null
		var expected_gen := int(parent["generation"]) + 1
		if entry["parents"].size() == 2:
			var partner_id := int(entry["parents"][1])
			if partner_id == parent_id or partner_id >= creature_id or not result.records.has(partner_id):
				return null
			var partner: Dictionary = result.records[partner_id]
			if int(entry["birth_tick"]) < int(partner["birth_tick"]):
				return null
			if int(partner["death_tick"]) != -1 and int(partner["death_tick"]) < int(entry["birth_tick"]):
				return null
			expected_gen = maxi(expected_gen, int(partner["generation"]) + 1)
		if int(entry["generation"]) != expected_gen:
			return null
		var deltas: Dictionary = {}
		for mutation in entry["mutations"]:
			deltas[mutation["gene"]] = mutation["delta"]
		var traits: Dictionary = entry["genome"].get("temperament", {})
		var parent_traits: Dictionary = parent["genome"].get("temperament", {})
		if traits.is_empty() != parent_traits.is_empty():
			return null
		for changed_gene in deltas:
			if not Genes.BOUNDS.has(changed_gene) and not traits.has(changed_gene):
				return null
		for disposition in traits:
			var change := snappedf(float(traits[disposition]) - float(parent_traits[disposition]), 0.000001)
			if not is_equal_approx(change, float(deltas.get(disposition, 0.0))):
				return null
		for gene in Genes.BOUNDS:
			var actual := snappedf(float(entry["genome"][gene]) - float(parent["genome"][gene]), 0.000001)
			if not is_equal_approx(actual, float(deltas.get(gene, 0.0))):
				return null
	return result
