extends RefCounted
## Fictitious simulation units, not nutritional claims. The only parameter table.
## Legacy energy remains stored per item to preserve earlier saves exactly.
const PARAMETERS := {
	"legacy": {"nutrition": 32.0, "hydration": 0.0, "palatability": 1.0, "toxicity": 0.0},
	"fruta": {"nutrition": 24.0, "hydration": 18.0, "palatability": 0.9, "toxicity": 0.0},
	"semente": {"nutrition": 40.0, "hydration": 2.0, "palatability": 0.7, "toxicity": 0.0},
	"folha": {"nutrition": 12.0, "hydration": 10.0, "palatability": 0.5, "toxicity": 0.0},
	"cogumelo": {"nutrition": 20.0, "hydration": 6.0, "palatability": 0.3, "toxicity": 8.0}
}

static func valid_type(value: Variant) -> bool:
	return value is String and PARAMETERS.has(value)

static func parameters(food_type: String) -> Dictionary:
	return PARAMETERS.get(food_type, {}).duplicate()
