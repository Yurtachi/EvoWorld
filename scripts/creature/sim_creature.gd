class_name SimCreature
extends RefCounted

const Genes = preload("res://scripts/creature/genome.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const Brains = preload("res://scripts/behavior/brains.gd")
const Signals = preload("res://scripts/communication/signal_channel.gd")
const MEMORY_LIMIT := 16

var id: int = 0
var name: String = ""
var pos := Vector2.ZERO
var heading: float = 0.0
var energy: float = 80.0
var max_energy: float = 100.0
var age: int = 0
var reproduction_cooldown: int = 0
var alive: bool = true
var genome: Genes = Genes.new()
var last_action: String = "rest"
var last_reason: String = "Newly spawned"
var memory: Array = []
var last_signal: Dictionary = {}
## Optional pluggable policy (see scripts/behavior/brains.gd); null = built-in heuristic.
var brain = null
var hunger: float:
	get:
		return clampf(1.0 - energy / max_energy, 0.0, 1.0)

func remember(event: Dictionary) -> void:
	memory.append(event.duplicate(true))
	if memory.size() > MEMORY_LIMIT:
		memory.pop_front()

func to_dict() -> Dictionary:
	var result := {
		"version": 1, "id": id, "name": name, "pos": Data.pack_vector(pos),
		"heading": heading, "energy": energy, "max_energy": max_energy,
		"age": age, "reproduction_cooldown": reproduction_cooldown, "alive": alive, "genome": genome.to_dict(),
		"last_action": last_action, "last_reason": last_reason, "memory": Data.restore_precision(memory)
	}
	# Optional key: heuristic creatures keep the original snapshot layout.
	if brain != null:
		result["brain"] = brain.to_dict()
	if not last_signal.is_empty():
		result["last_signal"] = last_signal.duplicate(true)
	return result

static func from_dict(data: Dictionary) -> SimCreature:
	if not Signals.valid_received(data.get("last_signal", {})):
		return null
	if not Data.integer(data.get("reproduction_cooldown", 0)):
		return null
	if not Data.integer(data.get("version")) or int(data["version"]) != 1 or not Data.integer(data.get("id"), 1) or not Data.integer(data.get("age")):
		return null
	if not Data.vector(data.get("pos")) or not Data.number(data.get("heading")):
		return null
	if not Data.number(data.get("energy")) or not Data.number(data.get("max_energy")):
		return null
	if float(data["max_energy"]) < 0.000001 or float(data["max_energy"]) > 10000.0 or float(data["energy"]) < 0.0 or float(data["energy"]) > float(data["max_energy"]):
		return null
	for field in ["name", "last_action", "last_reason"]:
		if not data.get(field) is String or data[field].length() > (64 if field == "name" else 256):
			return null
	if not data.get("alive") is bool or not data.get("genome") is Dictionary:
		return null
	if not data.get("memory") is Array or data["memory"].size() > MEMORY_LIMIT or not Data.json_data(data["memory"]):
		return null
	for entry in data["memory"]:
		if not Data.event(entry) or int(entry["creature_id"]) != int(data["id"]):
			return null
	var genes := Genes.from_dict(data["genome"])
	if genes == null:
		return null
	var saved_brain = null
	if data.has("brain"):
		saved_brain = Brains.from_dict(data["brain"])
		if saved_brain == null:
			return null
	var result = load("res://scripts/creature/sim_creature.gd").new()
	result.brain = saved_brain
	result.id = int(data["id"])
	result.name = data["name"]
	result.pos = Data.unpack_vector(data["pos"])
	result.heading = snappedf(float(data["heading"]), 0.000001)
	result.energy = snappedf(float(data["energy"]), 0.000001)
	result.max_energy = snappedf(float(data["max_energy"]), 0.000001)
	if not is_finite(result.energy) or not is_finite(result.max_energy) or result.max_energy <= 0.0 or result.energy > result.max_energy:
		return null
	result.age = int(data["age"])
	result.reproduction_cooldown = int(data.get("reproduction_cooldown", 0))
	result.alive = data["alive"]
	result.genome = genes
	result.last_action = data["last_action"]
	result.last_reason = data["last_reason"]
	result.memory = Data.restore_precision(data["memory"])
	result.last_signal = Data.restore_precision(data.get("last_signal", {}))
	return result
