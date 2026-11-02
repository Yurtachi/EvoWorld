extends RefCounted
## Physical obstacle catalog. Properties are simulation parameters.
## Modification is disabled in P2 (deferred to P3).
const VERSION := 1

const TYPES := {
	"parede": {"material": "alvenaria", "dureza": 10.0, "modificavel": false},
	"cerca": {"material": "madeira", "dureza": 3.0, "modificavel": false},
	"pedra": {"material": "rocha", "dureza": 8.0, "modificavel": false}
}

static func valid_type(value: Variant) -> bool:
	return value is String and TYPES.has(value)

static func properties(tipo: String) -> Dictionary:
	return TYPES.get(tipo, TYPES["pedra"]).duplicate()
