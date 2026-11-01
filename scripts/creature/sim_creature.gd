class_name SimCreature
extends RefCounted

const Genes = preload("res://scripts/creature/genome.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const MEMORY_LIMIT := 16

var id: int = 0
var name: String = ""
var pos := Vector2.ZERO
var heading: float = 0.0
var energy: float = 80.0
var max_energy: float = 100.0
var age: int = 0
var alive: bool = true
var genome: Genes = Genes.new()
var last_action: String = "rest"
var last_reason: String = "Newly spawned"
var memory: Array = []
var hunger: float:
	get:
		return clampf(1.0 - energy / max_energy, 0.0, 1.0)

func remember(event: Dictionary) -> void:
	memory.append(event.duplicate(true))
	if memory.size() > MEMORY_LIMIT:
		memory.pop_front()

func to_dict() -> Dictionary:
	return {
		"version": 1, "id": id, "name": name, "pos": Data.pack_vector(pos),
		"heading": heading, "energy": energy, "max_energy": max_energy,
		"age": age, "alive": alive, "genome": genome.to_dict(),
		"last_action": last_action, "last_reason": last_reason, "memory": Data.restore_precision(memory)
	}

static func from_dict(data: Dictionary) -> SimCreature:
	if data.get("version") != 1 or not Data.integer(data.get("id"), 1) or not Data.integer(data.get("age")):
		return null
	if not Data.vector(data.get("pos")) or not Data.number(data.get("heading")):
		return null
	if not Data.number(data.get("energy")) or not Data.number(data.get("max_energy")):
		return null
	if float(data["max_energy"]) <= 0.0 or float(data["energy"]) < 0.0 or float(data["energy"]) > float(data["max_energy"]):
		return null
	for field in ["name", "last_action", "last_reason"]:
		if not data.get(field) is String:
			return null
	if not data.get("alive") is bool or not data.get("genome") is Dictionary:
		return null
	if not data.get("memory") is Array or data["memory"].size() > MEMORY_LIMIT or not Data.json_data(data["memory"]):
		return null
	var genes := Genes.from_dict(data["genome"])
	if genes == null:
		return null
	var result = load("res://scripts/creature/sim_creature.gd").new()
	result.id = int(data["id"])
	result.name = data["name"]
	result.pos = Data.unpack_vector(data["pos"])
	result.heading = snappedf(float(data["heading"]), 0.000001)
	result.energy = snappedf(float(data["energy"]), 0.000001)
	result.max_energy = snappedf(float(data["max_energy"]), 0.000001)
	result.age = int(data["age"])
	result.alive = data["alive"]
	result.genome = genes
	result.last_action = data["last_action"]
	result.last_reason = data["last_reason"]
	result.memory = Data.restore_precision(data["memory"])
	return result
