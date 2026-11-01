class_name SimRng
extends RefCounted
## The world owns this generator. Store 64-bit state as text: JSON numbers lose bits.

var generator := RandomNumberGenerator.new()

func _init(world_seed: int = 1) -> void:
	generator.seed = world_seed

func between(low: float, high: float) -> float:
	return generator.randf_range(low, high)

func gaussian(deviation: float) -> float:
	return generator.randfn(0.0, deviation)

func to_dict() -> Dictionary:
	return {"state": str(generator.state)}

func restore(data: Dictionary) -> void:
	generator.state = int(data["state"])
