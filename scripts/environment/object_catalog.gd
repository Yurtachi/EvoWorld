extends RefCounted
## Only the physical world reads consequences. Sensors use appearance() alone.
const VERSION := 1
const LIMIT := 128
const TYPES := {
	"capsula_neutra": {"category": "capsula", "appearance": "lisa", "energy": 0.0, "hydration": 0.0, "toxicity": 0.0, "surprise": 0.1},
	"capsula_agradavel": {"category": "capsula", "appearance": "lisa", "energy": 4.0, "hydration": 2.0, "toxicity": 0.0, "surprise": 0.3},
	"capsula_aversiva": {"category": "capsula", "appearance": "lisa", "energy": -4.0, "hydration": -2.0, "toxicity": 0.15, "surprise": 0.5},
	"pedra": {"category": "pedra", "appearance": "rugosa", "energy": 0.0, "hydration": 0.0, "toxicity": 0.0, "surprise": 0.1}}

static func appearance(row: Dictionary) -> Dictionary:
	var spec: Dictionary = TYPES[row.tipo]
	return {"id": row.id, "pos": row.pos, "category": spec.category, "appearance": spec.appearance}
