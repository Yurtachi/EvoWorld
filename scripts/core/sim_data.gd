class_name SimData
extends RefCounted
## Data-only validation shared by save readers. No resources or scripts are loaded.
const GENE_SPANS := {"size": 10.0, "speed": 47.0, "vision_range": 195.0,
	"vision_fov": TAU - PI / 3.0, "metabolism": 1.3, "hue": 1.0,
	"curiosity": 1.0, "caution": 1.0, "sociability": 1.0, "impulsivity": 1.0}

static func mutation(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and value.get("gene") is String and GENE_SPANS.has(value["gene"]) and number(value.get("delta")) and float(value["delta"]) != 0.0 and absf(float(value["delta"])) <= float(GENE_SPANS[value["gene"]])

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 2147483647.0

static func integer(value: Variant, minimum: int = 0) -> bool:
	return number(value) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= 2147483647.0

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

static func integer_text(value: Variant) -> bool:
	if not value is String or not value.is_valid_int():
		return false
	var digits: String = value.trim_prefix("-")
	var limit := "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	if digits.length() > 19 or (digits.length() == 19 and digits > limit):
		return false
	return str(int(value)) == value

static func pack_vector(value: Vector2) -> Array:
	return [value.x, value.y]

static func unpack_vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func restore_precision(value: Variant) -> Variant:
	# Runtime decimal values use this same grid. Reapply it after JSON parsing,
	# which can choose the adjacent double for long decimal representations.
	if value is float:
		if value == floor(value) and absf(value) <= 2147483647.0:
			return int(value)
		return snappedf(value, 0.000001)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(restore_precision(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = restore_precision(value[key])
		return result
	return value

static func json_data(value: Variant, depth: int = 0, budget: Array = []) -> bool:
	# Bound hostile/unknown fields before any migration duplicates them. The node
	# budget is shared by recursion, including repeated references and cycles.
	if budget.is_empty():
		budget = [8000000]
	budget[0] -= 1
	if depth > 12 or budget[0] < 0:
		return false
	if value is String:
		return value.length() <= 4096
	if value == null or value is bool:
		return true
	if number(value):
		return true
	if value is Array:
		if value.size() > 100000:
			return false
		for item in value:
			if not json_data(item, depth + 1, budget):
				return false
		return true
	if value is Dictionary:
		if value.size() > 128:
			return false
		for key in value:
			if not key is String or key.length() > 128 or not json_data(value[key], depth + 1, budget):
				return false
		return true
	return false

## Closed event schema: consumers may safely access fields after load.
static func event(value: Variant, max_tick: int = 2147483647, next_id: int = 2147483647) -> bool:
	if not value is Dictionary or not value.get("type") is String:
		return false
	if not integer(value.get("tick")) or int(value["tick"]) > max_tick:
		return false
	if not integer(value.get("creature_id"), 1) or int(value["creature_id"]) >= next_id:
		return false
	match value["type"]:
		"spawn":
			return value.size() == 4 and value.get("name") is String and value["name"].length() <= 64
		"eat":
			return value.size() == 5 and integer(value.get("food_id"), 1) and int(value["food_id"]) < next_id and number(value.get("energy")) and float(value["energy"]) >= 0.0 and float(value["energy"]) <= 10000.0
		"drink":
			return value.size() == 5 and integer(value.get("water_id"), 1) and int(value["water_id"]) < next_id and number(value.get("hydration")) and float(value["hydration"]) > 0.0 and float(value["hydration"]) <= 100.0
		"death":
			return value.size() == 4 and value.get("reason") is String and value["reason"] in ["starvation", "age", "external"]
		"birth":
			return value.size() == 6 and integer(value.get("parent_id"), 1) and int(value["parent_id"]) < int(value["creature_id"]) and integer(value.get("generation"), 1) and number(value.get("energy")) and float(value["energy"]) > 0.0 and float(value["energy"]) <= 10000.0
		"mutation":
			return value.size() == 6 and integer(value.get("parent_id"), 1) and int(value["parent_id"]) < int(value["creature_id"]) and mutation({"gene": value.get("gene"), "delta": value.get("delta")})
	return false
