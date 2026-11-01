extends RefCounted
## Water is renewable circular terrain, never a solid obstacle.
const CAPACITY := 100.0
const INITIAL := 100.0
const LOSS_PER_SECOND := 0.8 # multiplied by the creature's metabolic gene
const DRINK_AMOUNT := 35.0
const THIRST_THRESHOLD := 0.6
const DEHYDRATION_ENERGY_PER_SECOND := 2.0 # at zero hydration, on top of metabolism
const MAX_REGIONS := 256
const MAX_RADIUS := 500.0

static func shore(region: Dictionary, position: Vector2) -> Vector2:
	var offset: Vector2 = position - region["pos"]
	if offset.length() <= float(region["radius"]):
		return position
	return region["pos"] + offset.normalized() * float(region["radius"])
