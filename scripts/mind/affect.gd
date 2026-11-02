extends RefCounted
## Computational affect, original implementation from M1 requirements.
## Receives observed consequences only; has no access to a creature's body.
const Data = preload("res://scripts/core/sim_data.gd")
const STATES := ["frustracao", "tranquilidade", "entusiasmo", "receio", "solidao", "satisfacao", "saturacao_social"]
const CAUSES := ["decay", "blocked_motion", "need_satisfied", "toxic_exposure", "contact", "adverse_contact", "prolonged_contact", "absence_of_contact", "safe_rest", "free_movement", "object_contact", "drawing_completed"]
const LOG_LIMIT := 96
var values: Dictionary = {}
var cause_log: Array = []

func _init() -> void:
	for state in STATES:
		values[state] = 0.0

func change(tick: int, state: String, amount: float, cause: String, traits: Dictionary) -> void:
	var sensitivity := 1.0
	match state:
		"frustracao": sensitivity = 0.65 + float(traits.impulsivity)
		"receio": sensitivity = 0.5 + float(traits.caution)
		"solidao": sensitivity = 0.15 + float(traits.sociability)
		"saturacao_social": sensitivity = 1.4 - float(traits.sociability)
		"entusiasmo": sensitivity = 0.5 + float(traits.curiosity)
		"tranquilidade": sensitivity = 1.25 - 0.5 * float(traits.impulsivity)
		"satisfacao": sensitivity = 0.7 + 0.6 * float(traits.impulsivity)
	var before := float(values[state])
	var after := snappedf(clampf(before + amount * sensitivity, 0.0, 1.0), 0.000001)
	values[state] = after
	if after != before:
		cause_log.append({"tick": tick, "estado": state, "delta": snappedf(after - before, 0.000001), "causa": cause})
		if cause_log.size() > LOG_LIMIT:
			cause_log.pop_front()

func decay(tick: int, traits: Dictionary) -> void:
	for state in STATES:
		var rate := 0.018 + 0.012 * (1.0 - float(traits.caution))
		change(tick, state, -float(values[state]) * rate, "decay", traits)

func to_dict() -> Dictionary:
	return Data.restore_precision({"values": values, "cause_log": cause_log})

static func from_dict(data: Variant, max_tick: int = 2147483647):
	if not data is Dictionary or data.size() != 2 or not data.get("values") is Dictionary or data["values"].size() != STATES.size() or not data.get("cause_log") is Array or data["cause_log"].size() > LOG_LIMIT:
		return null
	for state in STATES:
		if not Data.number(data["values"].get(state)) or float(data["values"][state]) < 0.0 or float(data["values"][state]) > 1.0:
			return null
	var previous := -1
	for row in data["cause_log"]:
		if not row is Dictionary or row.size() != 4 or not Data.integer(row.get("tick")) or int(row["tick"]) < previous or int(row["tick"]) > max_tick or row.get("estado") not in STATES or row.get("causa") not in CAUSES or not Data.number(row.get("delta")) or absf(float(row["delta"])) > 1.0:
			return null
		previous = int(row["tick"])
	var result = load("res://scripts/mind/affect.gd").new()
	result.values = Data.restore_precision(data["values"])
	result.cause_log = Data.restore_precision(data["cause_log"])
	return result
