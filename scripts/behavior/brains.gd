extends RefCounted
## Brain registry. A brain is a data-only object with:
##   decide(creature, obs: Dictionary, rng) -> int   (an Actions constant)
##   on_death(creature) -> void
##   to_dict() -> Dictionary  (JSON-safe, "kind" + "version")
##   last_reason: String
## Creatures with brain == null use SimWorld's built-in heuristic baseline.

const QBrain = preload("res://scripts/behavior/q_brain.gd")
const RandomBrain = preload("res://scripts/behavior/random_brain.gd")

static func make(kind: String):
	match kind:
		QBrain.KIND:
			return QBrain.new()
		RandomBrain.KIND:
			return RandomBrain.new()
	return null

## Returns null for unknown kinds or malformed data; never loads code from save data.
static func from_dict(data: Variant):
	if not data is Dictionary:
		return null
	match data.get("kind"):
		QBrain.KIND:
			return QBrain.from_dict(data)
		RandomBrain.KIND:
			return RandomBrain.from_dict(data)
	return null
